/**
 * d3 router: virtual model `router/auto` that lets the local Ollama decision model
 * (d3:9b, served at http://localhost:11434/v1/systemone) pick Sonnet vs Opus and the
 * effort level for every new user turn.
 *
 *   pi --model router/auto        or  /model router/auto
 *
 * - Selected thinking level = effort CEILING. The router never picks above it
 *   (e.g. `router/auto:medium` keeps every turn at <= medium).
 * - Only `user` requests are classified. Tool follow-ups and retries stick to the
 *   model that handled the turn, so prompt caches and thinking signatures stay valid.
 * - Hysteresis: switching Sonnet <-> Opus costs a prompt-cache miss, so the router
 *   only switches when d3 is confident (>= SWITCH_CONFIDENCE).
 * - Tool errors: d3 sees recent failed tool calls; and if Sonnet fails >= 3 tool calls
 *   within one turn, the rest of that turn is escalated to Opus (one cache miss).
 * - If Ollama is down or d3 errors, it falls back to the previous model, else Sonnet/medium.
 * - Compaction summaries and other `direct` requests go to Sonnet.
 *
 * The decision is shown in the footer via setStatus("router", ...).
 */
import type { Message } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, ModelRouteRequest } from "@earendil-works/pi-coding-agent";

const OLLAMA_URL = process.env.PI_D3_URL ?? "http://localhost:11434/v1";
const D3_MODEL = process.env.PI_D3_MODEL ?? "d3:9b";

const SONNET = "claude-sonnet-5-5";
const OPUS = "claude-opus-5-5";
/** Top tier, expensive: only for the hardest tasks. Override with PI_D3_FABLE; set PI_D3_FABLE=off to disable. */
const FABLE = process.env.PI_D3_FABLE ?? "claude-fable-5-2";
const FABLE_ON = FABLE !== "off";
const FABLE_THRESHOLD = 0.6;
const SWITCH_CONFIDENCE = 0.7;
const CLASSIFY_TIMEOUT_MS = 8_000;
/** Persona bias (set by the `pa` wrapper): shifts the Opus decision threshold. */
const PERSONA = process.env.PI_PERSONA;
const BIAS = process.env.PI_ROUTER_BIAS; // "opus" | "sonnet" | other = neutral
const OPUS_THRESHOLD = BIAS === "opus" ? 0.3 : BIAS === "sonnet" ? 0.7 : 0.5;
/** Failed tool calls within one turn after which a Sonnet turn is escalated to Opus. */
const ESCALATE_AFTER_ERRORS = 3;

type Effort = "low" | "medium" | "high";
const EFFORTS: Effort[] = ["low", "medium", "high"];

interface RouterState {
	model: string;
	effort: Effort;
}

function lastUserText(messages: readonly Message[]): string {
	const content = messages.filter((m) => m.role === "user").at(-1)?.content ?? "";
	if (typeof content === "string") return content;
	return content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("\n");
}

/** Short summary of the recent conversation so d3 sees follow-ups like "now do the same for X". */
function recentContext(messages: readonly Message[]): string {
	const out: string[] = [];
	for (const m of messages.slice(-12)) {
		if (m.role === "user" || m.role === "assistant") {
			const c = m.content;
			const text = typeof c === "string" ? c : c.flatMap((b) => (b.type === "text" ? [b.text] : [])).join(" ");
			if (text.trim()) out.push(`${m.role}: ${text.slice(0, 600)}`);
		}
	}
	return out.join("\n").slice(-4_000);
}

/** Failed tool results since the last user message (or in the whole window if `sinceUser` is false). */
function toolErrors(messages: readonly Message[], sinceUser: boolean): string[] {
	const start = sinceUser ? messages.findLastIndex((m) => m.role === "user") + 1 : Math.max(0, messages.length - 40);
	const out: string[] = [];
	for (const m of messages.slice(start)) {
		if (m.role !== "toolResult" || !m.isError) continue;
		const c = m.content;
		const text = typeof c === "string" ? c : c.flatMap((b) => (b.type === "text" ? [b.text] : [])).join(" ");
		out.push(`${m.toolName}: ${text.slice(0, 200)}`);
	}
	return out;
}

function capEffort(e: Effort, cap: string | undefined): Effort {
	const ci = EFFORTS.indexOf(cap as Effort);
	if (ci < 0) return e;
	return EFFORTS.indexOf(e) > ci ? EFFORTS[ci] : e;
}

async function decide(request: ModelRouteRequest<RouterState>, ctx: ExtensionContext) {
	const d3 = ctx.modelRegistry.findOfType("classifier", "ollama-d3", D3_MODEL);
	if (!d3) throw new Error(`classifier ollama-d3/${D3_MODEL} not registered`);
	const signal = AbortSignal.any([request.signal ?? new AbortController().signal, AbortSignal.timeout(CLASSIFY_TIMEOUT_MS)]);
	const result = await ctx.modelRegistry.classify(
		d3,
		{
			state: {
				prompt: lastUserText(request.messages).slice(0, 12_000),
				recent_conversation: recentContext(request.messages),
				recent_tool_errors: toolErrors(request.messages, false).slice(-8),
				persona: PERSONA ? `Session persona: ${PERSONA} (prefers ${BIAS ?? "no"} model)` : "none",
				user_profile: "Computational physicist working on VASP (Fortran/MPI/GPU) and TRIQS (C++/Python).",
			},
			questions: {
				model: {
					type: "choice",
					instructions:
						"Which model should handle `prompt`? Consider `recent_conversation` for short follow-ups. Several `recent_tool_errors` mean the previous model is struggling: prefer opus.",
					criteria: {
						sonnet: "Routine coding, edits, running commands, builds, explanations, simple debugging, Q&A",
						...(FABLE_ON
							? {
									fable:
										"Exceptionally hard, open-ended research-grade problems: deep multi-file design from scratch, elusive heisenbugs after earlier attempts failed, novel algorithm/numerics derivations. Rare; most hard tasks are still opus",
								}
							: {}),
						opus: "Hard reasoning: subtle bugs, numerical/physics correctness, architecture or cross-cutting design, performance analysis, large refactors",
					},
				},
				effort: {
					type: "choice",
					instructions: "How much thinking does `prompt` need?",
					criteria: {
						low: "Trivial: one-liners, lookups, chit-chat, yes/no, running a known command",
						medium: "Normal tasks with a few steps",
						high: "Multi-step work, careful planning, hard debugging, derivations, tricky numerics",
					},
				},
			},
		},
		{ signal },
	);
	if (result.stopReason !== "stop") throw new Error(result.errorMessage ?? `stopReason=${result.stopReason}`);
	const m = result.answers.model;
	const e = result.answers.effort;
	if (m?.type !== "choice" || e?.type !== "choice") throw new Error(`unexpected answers ${JSON.stringify(result.answers)}`);
	return {
		opusProb: m.probabilities.opus ?? 0,
		fableProb: FABLE_ON ? (m.probabilities.fable ?? 0) : 0,
		effort: (EFFORTS.includes(e.choice as Effort) ? e.choice : "medium") as Effort,
	};
}

export default function (pi: ExtensionAPI) {
	pi.registerProvider("ollama-d3", {
		name: "Ollama decision models",
		baseUrl: OLLAMA_URL,
		apiKey: "ollama",
		// Ollama's /v1/systemone already speaks the System One wire format, so answers pass
		// through unchanged; only the envelope is adapted to pi's ClassifierResult.
		classifiers: {
			"typesafe-system-one": {
				async classify(model, context, options) {
					const base = { api: model.api, provider: model.provider, model: model.id, answers: {}, timestamp: Date.now() };
					try {
						const res = await fetch(`${model.baseUrl.replace(/\/+$/, "")}/systemone`, {
							method: "POST",
							headers: { "content-type": "application/json" },
							body: JSON.stringify({ model: model.id, state: context.state, questions: context.questions }),
							signal: options?.signal,
						});
						if (!res.ok) return { ...base, stopReason: "error", errorMessage: `HTTP ${res.status}: ${await res.text()}` };
						const body = (await res.json()) as { answers: Record<string, never> };
						return { ...base, answers: body.answers, stopReason: "stop" };
					} catch (err) {
						const aborted = options?.signal?.aborted;
						return { ...base, stopReason: aborted ? "aborted" : "error", errorMessage: String(err) };
					}
				},
			},
		},
		models: [
			{
				type: "classifier",
				id: D3_MODEL,
				name: `d3 (${D3_MODEL}, local)`,
				api: "typesafe-system-one",
				input: ["text"],
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
				contextWindow: 32_000,
			},
		],
	});

	pi.registerVirtualModel<RouterState>({
		provider: "router",
		id: "auto",
		name: "d3",
		thinkingLevels: ["low", "medium", "high"],
		contextWindow: 1_000_000,
		maxTokens: 128_000,
		async route(request, ctx) {
			const find = (id: string) => {
				const model = ctx.modelRegistry.find("anthropic", id);
				if (!model) throw new Error(`anthropic/${id} is not in the catalog`);
				return model;
			};

			if (request.reason === "direct") return { model: find(SONNET), thinkingLevel: "medium" };

			const sticky = request.failed ?? request.previous;
			// Mid-turn escalation: Sonnet keeps failing tool calls -> hand the rest of the turn to Opus.
			// Costs one prompt-cache miss; afterwards the session stays on Opus until d3 says otherwise.
			if (
				request.reason === "continuation" &&
				request.state?.model === SONNET &&
				toolErrors(request.messages, true).length >= ESCALATE_AFTER_ERRORS
			) {
				const next: RouterState = { model: OPUS, effort: capEffort("high", request.thinkingLevel) };
				if (process.env.PI_D3_DEBUG) console.error(`[d3-router] escalate -> ${next.model}:${next.effort}`);
				if (ctx.hasUI) ctx.ui.setStatus("router", `escalated → opus:${next.effort} (repeated tool errors)`);
				return { model: find(OPUS), thinkingLevel: next.effort, state: next };
			}

			if (request.reason !== "user" && sticky) {
				return { model: sticky.model, thinkingLevel: sticky.thinkingLevel ?? "medium" };
			}

			const prev = request.state;
			let next: RouterState;
			let note = "";
			try {
				const d = await decide(request, ctx);
				if (!d) throw new Error("no decision");
				// Persona bias is applied to "opus or better" vs sonnet; fable needs its own high bar.
				const upProb = d.opusProb + d.fableProb;
				let model = d.fableProb >= FABLE_THRESHOLD ? FABLE : upProb >= OPUS_THRESHOLD ? OPUS : SONNET;
				// Hysteresis: only leave the current model when d3 is confident.
				if (prev && model !== prev.model) {
					const conf = model === SONNET ? 1 - upProb - (0.5 - OPUS_THRESHOLD) : model === FABLE ? d.fableProb : upProb + (0.5 - OPUS_THRESHOLD);
					if (conf < SWITCH_CONFIDENCE) model = prev.model;
				}
				next = { model, effort: capEffort(d.effort, request.thinkingLevel) };
				note = `p(opus)=${d.opusProb.toFixed(2)}${FABLE_ON ? ` p(fable)=${d.fableProb.toFixed(2)}` : ""}${PERSONA ? `, ${PERSONA}` : ""}`;
			} catch (err) {
				next = prev ?? { model: SONNET, effort: capEffort("medium", request.thinkingLevel) };
				note = `d3 unavailable: ${err instanceof Error ? err.message : String(err)}`;
			}

			if (process.env.PI_D3_DEBUG) console.error(`[d3-router] ${next.model}:${next.effort} (${note})`);
			if (ctx.hasUI) {
				const short = next.model === FABLE ? "fable" : next.model === OPUS ? "opus" : "sonnet";
				ctx.ui.setStatus("router", `d3 → ${short}:${next.effort} (${note})`);
			}
			const changed = !prev || prev.model !== next.model || prev.effort !== next.effort;
			return { model: find(next.model), thinkingLevel: next.effort, state: changed ? next : undefined };
		},
	});
}
