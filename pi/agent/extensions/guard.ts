/**
 * guard: lightweight "auto-ish" permission layer for pi (which has none built in).
 *
 *  - Everything routine runs without prompts.
 *  - ASK  : risky bash commands / reads of sensitive paths -> confirm (Yes / Yes for rest of session / No).
 *  - BLOCK: writes to .git internals, ssh keys, credentials, pi auth. Never allowed.
 *  - No UI (print/RPC mode): ASK cases are blocked.
 *
 *  /guard            show status       /guard off|on     toggle for this session
 *  PI_GUARD=off      start disabled
 *
 * Tune the pattern lists below if it is too strict.
 * This is a safety net against accidents, NOT a security boundary (see docs/security.md).
 */
import { homedir } from "node:os";
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const HOME = homedir();

/** Hard-blocked bash (mirrors the personas' rule): never sudo/su/root; hand the human a block instead. */
const BLOCK_BASH: RegExp[] = [/(^|[;&|(]\s*)(sudo|su|doas)\b/, /\bsu\s+-/, /\bsudo\b/, /\bssh\b[^;|&]*\b(root|itsme)@/];
const BLOCK_MSG =
	"guard: privileged commands are not allowed. Hand the human a block (preconditions, Deploy as itsme|root with absolute paths, verify, rollback, then as hampel) and continue after they ran it.";

/** [regex, label] - bash commands that need confirmation. */
const ASK_BASH: [RegExp, string][] = [
	[/\brm\s+(-[a-z]*r|--recursive)/i, "recursive rm"],
	[/\b(chmod|chown)\b.*(777|-R)/, "chmod/chown 777 or -R"],
	[/\bgit\s+push\b.*(--force|-f\b|--delete|\s:\S)/, "git force/delete push"],
	[/\bgit\s+reset\s+--hard/, "git reset --hard"],
	[/\bgit\s+clean\s+-[a-z]*f/, "git clean -f"],
	[/\bgit\s+(branch\s+-D|checkout\s+(--\s+)?\.\s*$|restore\s+\.\s*$)/, "discarding git work"],
	[/\bgit\s+push\b/, "git push"],
	[/\bgit\s+tag\b(?!\s+(-l|--list)\b)\s*\S/, "git tag"],
	[/\b(glab|gh)\s+(mr|pr|issue|release|api)\b.*\b(create|merge|close|reopen|comment|note|edit|delete|approve|rebase|update|-X|--method)\b/, "MR/PR/issue state change"],
	[/\b(scancel|scontrol\s+(shutdown|reconfigure|update))\b/, "slurm cancel/admin"],
	[/\b(mkfs|dd\s+.*of=|shred|wipefs|fdisk|parted)\b/, "disk-destructive command"],
	[/\b(shutdown|reboot|poweroff|halt)\b/, "power command"],
	[/\b(curl|wget)\b[^|;]*\|\s*(sudo\s+)?(ba|z)?sh\b/, "pipe to shell"],
	[/\bfind\b.*\s-delete\b/, "find -delete"],
	[/\b(pip|npm|cargo)\s+(uninstall|publish)\b/, "package uninstall/publish"],
	[/(^|[;&|]\s*)>\s*\/(etc|usr|opt|bin)\b/, "write to system dir"],
	[/obsidian\/[^ ]*private/, "vault private/ folder"],
	[/(\.ssh\/|\.gnupg\/|\.pi\/agent\/auth\.json|\.netrc|id_(rsa|ed25519))/, "credential files"],
];

/**
 * Intent: if YOUR latest message explicitly asks for the action, the matching ASK label is
 * auto-approved for that turn (a note is shown). Labels not listed here (force push, pipe to
 * shell, disk-destructive, credentials, private/) always ask. A negation ("don't push") cancels it.
 */
const INTENT: Record<string, RegExp> = {
	"git push": /\b(push|publish|ship it)\b/i,
	"git force/delete push": /\bforce[- ]?push|push\b.*--force|\bforce\b.*\bpush\b/i,
	"git tag": /\b(tag|release)\b/i,
	"MR/PR/issue state change": /\b(mr|pr|merge request|pull request|merge|issue|comment|release|close)\b/i,
	"slurm cancel/admin": /\b(cancel|scancel|kill)\b/i,
	"recursive rm": /\b(delete|remove|rm|clean ?up|wipe)\b/i,
	"git reset --hard": /\breset\b/i,
	"git clean -f": /\bclean\b/i,
};
const NEGATION = /\b(don'?t|do not|never|without|no need to|not)\b[^.!?\n]{0,40}\b/i;

/** Path fragments that may NEVER be written/edited. */
const BLOCK_WRITE = [
	/(^|\/)\.git\//,
	/(^|\/)\.ssh\//,
	/(^|\/)\.gnupg\//,
	/(^|\/)\.env(\.|$)/,
	/(^|\/)\.netrc$/,
	/\.pi\/agent\/(auth|trust)\.json$/,
	/(^|\/)id_(rsa|ed25519)(\.pub)?$/,
	/\/obsidian\/hampel\/private\//,
];

/** Path fragments where READING needs confirmation (or is blocked for keys). */
const BLOCK_READ = [/(^|\/)\.ssh\/id_/, /\.pi\/agent\/auth\.json$/, /(^|\/)\.gnupg\//];
const ASK_READ = [/\/obsidian\/hampel\/private\//, /(^|\/)\.env(\.|$)/, /(^|\/)\.netrc$/];

function abs(p: string, cwd: string): string {
	const q = p.startsWith("~/") ? HOME + p.slice(1) : p;
	return resolve(cwd, q);
}

export default function (pi: ExtensionAPI) {
	let enabled = process.env.PI_GUARD !== "off";
	const allowed = new Set<string>(); // labels approved for the rest of the session
	let lastUser = ""; // latest message typed by the user

	pi.on("input", async (event: any) => {
		if (event.source !== "extension") lastUser = String(event.text ?? "");
		return { action: "continue" };
	});

	function userAsked(label: string): boolean {
		const re = INTENT[label];
		if (!re || !lastUser) return false;
		const m = re.exec(lastUser);
		if (!m) return false;
		// negation shortly before the matched word cancels the intent
		const before = lastUser.slice(Math.max(0, m.index - 40), m.index);
		return !NEGATION.test(before + " ");
	}

	async function ask(ctx: any, what: string, label: string, detail: string) {
		if (allowed.has(label)) return undefined;
		if (userAsked(label)) {
			if (ctx.hasUI) ctx.ui.notify(`guard: allowed (${label}), you asked for it`, "info");
			return undefined;
		}
		if (!ctx.hasUI) return { block: true, reason: `guard: ${what} (${label}) blocked, no UI to confirm` };
		const yes = "Yes";
		const always = `Yes, and don't ask again this session for: ${label}`;
		const choice = await ctx.ui.select(`⚠️ guard: ${what} (${label})\n\n  ${detail}\n\nAllow?`, [yes, always, "No"]);
		if (choice === always) allowed.add(label);
		if (choice === yes || choice === always) return undefined;
		return { block: true, reason: "guard: blocked by user" };
	}

	pi.registerCommand("guard", {
		description: "guard status | on | off",
		handler: async (args: string, ctx: any) => {
			const a = (args ?? "").trim();
			if (a === "on") enabled = true;
			else if (a === "off") enabled = false;
			ctx.ui.notify(
				`guard ${enabled ? "ON" : "OFF"}${allowed.size ? `; session-allowed: ${[...allowed].join(", ")}` : ""}`,
				"info",
			);
		},
	});

	pi.on("tool_call", async (event: any, ctx: any) => {
		if (!enabled) return undefined;
		const cwd: string = ctx.cwd ?? process.cwd();

		if (event.toolName === "bash") {
			const cmd = String(event.input.command ?? "");
			if (BLOCK_BASH.some((re) => re.test(cmd))) return { block: true, reason: BLOCK_MSG };
			for (const [re, label] of ASK_BASH) {
				if (re.test(cmd)) return ask(ctx, "bash command", label, cmd.slice(0, 500));
			}
			return undefined;
		}

		if (event.toolName === "write" || event.toolName === "edit") {
			const p = abs(String(event.input.path ?? ""), cwd);
			if (BLOCK_WRITE.some((re) => re.test(p))) {
				if (ctx.hasUI) ctx.ui.notify(`guard: blocked write to ${p}`, "warning");
				return { block: true, reason: `guard: "${p}" is a protected path` };
			}
			return undefined;
		}

		if (event.toolName === "read") {
			const p = abs(String(event.input.path ?? ""), cwd);
			if (BLOCK_READ.some((re) => re.test(p))) return { block: true, reason: `guard: reading "${p}" is not allowed` };
			if (ASK_READ.some((re) => re.test(p))) return ask(ctx, "read sensitive file", "sensitive read", p);
		}
		return undefined;
	});
}
