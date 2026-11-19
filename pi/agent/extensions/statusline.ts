/**
 * Pi footer mirroring claude/statusline-command.sh:
 *   repo (branch) | 5h:NN%(r:HH:MM) 7d:NN%(r:Ddd HH:MM) | ⚡ ctx:NN% | 🤖 model
 * plus a second line with any extension statuses.
 *
 * Rate limits come from Anthropic's `anthropic-ratelimit-unified-*` response
 * headers (only sent for subscription/OAuth auth), so they show "--" until the
 * first response of the session.
 */
import { execFileSync } from "node:child_process";
import { basename } from "node:path";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const C = {
	cyan: "\x1b[36m",
	green: "\x1b[32m",
	yellow: "\x1b[33m",
	red: "\x1b[31m",
	magenta: "\x1b[35m",
	dim: "\x1b[2m",
	bold: "\x1b[1m",
	reset: "\x1b[0m",
};

type Limit = { pct?: number; reset?: number };
const limits: { five: Limit; week: Limit } = { five: {}, week: {} };

function num(v: unknown): number | undefined {
	const n = typeof v === "string" ? Number.parseFloat(v) : typeof v === "number" ? v : Number.NaN;
	return Number.isFinite(n) ? n : undefined;
}

function repoName(cwd: string): string | undefined {
	try {
		const top = execFileSync("git", ["-C", cwd, "--no-optional-locks", "rev-parse", "--show-toplevel"], {
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
		return top ? basename(top) : undefined;
	} catch {
		return undefined;
	}
}

function fmtReset(epoch: number | undefined, withDay: boolean): string {
	if (epoch == null) return "";
	const d = new Date(epoch * 1000);
	const hm = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
	return withDay ? `${d.toLocaleDateString("en-US", { weekday: "short" })} ${hm}` : hm;
}

function fmtTok(n: number): string {
	if (n < 1000) return `${n}`;
	if (n < 1_000_000) return `${(n / 1000).toFixed(n < 10_000 ? 1 : 0)}k`;
	return `${(n / 1_000_000).toFixed(1)}M`;
}

function limitPart(label: string, l: Limit, withDay: boolean): string {
	if (l.pct == null) return `${C.dim}${label}:--%${C.reset}`;
	const p = Math.round(l.pct);
	const col = p >= 80 ? C.red : p >= 50 ? C.yellow : C.green;
	const r = fmtReset(l.reset, withDay);
	return `${col}${label}:${p}%${C.reset}${r ? ` ${C.dim}${r}${C.reset}` : ""}`;
}

export default function (pi: ExtensionAPI) {
	pi.on("after_provider_response", (event) => {
		const h = event.headers as Record<string, string | undefined>;
		const get = (k: string) => h[k] ?? h[k.toLowerCase()];
		const f = num(get("anthropic-ratelimit-unified-5h-utilization"));
		const w = num(get("anthropic-ratelimit-unified-7d-utilization"));
		// Utilization is a 0..1 fraction.
		if (f != null) limits.five = { pct: f * 100, reset: num(get("anthropic-ratelimit-unified-5h-reset")) };
		if (w != null) limits.week = { pct: w * 100, reset: num(get("anthropic-ratelimit-unified-7d-reset")) };
	});

	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI) return;
		const repo = repoName(ctx.cwd);

		ctx.ui.setFooter((tui, _theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());
			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					const sep = ` ${C.dim}|${C.reset} `;
					const parts: string[] = [];

					let head = repo ? `${C.bold}${C.yellow}${repo}${C.reset}` : "";
					const branch = footerData.getGitBranch();
					if (branch) head += `${head ? " " : ""}${C.bold}${C.cyan}(${branch})${C.reset}`;
					if (head) parts.push(head);

					parts.push(`${limitPart("5h", limits.five, false)} ${limitPart("7d", limits.week, true)}`);

					// Session totals + the physical model of the latest response (differs from the
					// selection when a virtual/router model is active).
					let input = 0, output = 0, cacheRead = 0, cost = 0;
					let last: { model?: string; thinkingLevel?: string } | undefined;
					for (const e of ctx.sessionManager.getBranch()) {
						if (e.type !== "message" || e.message.role !== "assistant") continue;
						const m = e.message as AssistantMessage & { thinkingLevel?: string };
						input += m.usage?.input ?? 0;
						output += m.usage?.output ?? 0;
						cacheRead += m.usage?.cacheRead ?? 0;
						cost += m.usage?.cost?.total ?? 0;
						last = { model: m.model, thinkingLevel: m.thinkingLevel };
					}

					const usage = ctx.getContextUsage();
					const used = usage?.percent ?? (usage?.tokens != null && usage.contextWindow ? (100 * usage.tokens) / usage.contextWindow : undefined);
					if (used != null) {
						const u = Math.round(used);
						const [emoji, col] = u >= 90 ? ["🚨", C.red] : u >= 70 ? ["🔥", C.yellow] : u >= 20 ? ["⚡", C.green] : ["🟢", C.green];
						const tok = "";
						parts.push(`${emoji} ctx:${col}${u}%${C.reset}${tok}`);
					} else {
						parts.push(`🟢 ctx:${C.dim}--%${C.reset}`);
					}

					if (input + output > 0) {
						const hit = input + cacheRead > 0 ? Math.round((100 * cacheRead) / (input + cacheRead)) : 0;
						parts.push(`${C.dim}↑${fmtTok(input + cacheRead)} ↓${fmtTok(output)} cache:${hit}% $${cost.toFixed(2)}${C.reset}`);
					}

					const model = ctx.model ? (ctx.model.name ?? ctx.model.id) : "no-model";
					const think = pi.getThinkingLevel();
					let modelStr = `${C.magenta}🤖 ${model}${think && think !== "off" ? ` ${C.dim}(${think})` : ""}${C.reset}`;
					// The router already reports the physical model on the status line below.
					const routed = footerData.getExtensionStatuses().has("router");
					if (!routed && last?.model && ctx.model && last.model !== ctx.model.id) {
						const lvl = last.thinkingLevel && last.thinkingLevel !== "off" ? `:${last.thinkingLevel}` : "";
						modelStr += ` ${C.dim}→${C.reset} ${C.magenta}${last.model.replace(/^claude-/, "")}${lvl}${C.reset}`;
					}
					parts.push(modelStr);

					const lines = [truncateToWidth(parts.join(sep), width)];
					const statuses = [...footerData.getExtensionStatuses().values()].filter(Boolean);
					if (statuses.length) lines.push(truncateToWidth(`${C.dim}${statuses.join(" · ")}${C.reset}`, width));
					return lines;
				},
			};
		});
	});
}
