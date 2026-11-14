/**
 * A quieter footer.
 *
 *     ~/nixos (main)                                        claude-opus-5.5 • xhigh
 *     12% of 1M · ↑48k ↓9.1k · Copilot 99.9% (−12) · 999.5K/1M · resets Dec 1 · 🧠 nixos
 *                    2 running agents · 1 background command · Authenticating fastmail...
 *
 * Compared with pi's built-in footer it drops what never changes on a Copilot
 * subscription ("$0.000 (sub)", "(auto)"), hides statuses whose healthy state
 * is just noise (MCP "N servers enabled", engram "ready"), and moves anything
 * that is happening right now (subagents, background commands, MCP
 * sign-in/tasks, statuses from extensions it doesn't know) onto a third
 * line that only exists while there is something to show. No status is ever
 * silently dropped except the healthy MCP summary.
 *
 * On narrow terminals line 2 sheds the least useful parts first: the Copilot
 * reset date, then the raw credit count, then the engram project, then token
 * counts. Context usage and the Copilot % always stay.
 *
 * `/footer` toggles back to the built-in footer for the current session.
 *
 * Managed by Nix (common/pi/footer.ts in the nixos repo).
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

/** Parts of the copilot-credits status are joined with this; see copilot-credits.ts. */
const COPILOT_SEPARATOR = " · ";

interface Segment {
	text: string;
	/** Higher numbers are dropped first when the line doesn't fit. */
	drop: number;
}

interface Totals {
	input: number;
	output: number;
}

const ANSI = /\x1b\[[0-9;]*m/g;
const plain = (text: string) => text.replace(ANSI, "");
const oneLine = (text: string) => text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();

/** 1.0M → 1M, 2.5k stays 2.5k. */
const trim = (n: number, digits: number) => n.toFixed(digits).replace(/\.0+$/, "");

function formatTokens(n: number): string {
	if (n < 1000) return `${n}`;
	if (n < 10_000) return `${trim(n / 1000, 1)}k`;
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
	if (n < 10_000_000) return `${trim(n / 1_000_000, 1)}M`;
	return `${Math.round(n / 1_000_000)}M`;
}

function formatCwd(cwd: string): string {
	const home = process.env.HOME;
	if (home && (cwd === home || cwd.startsWith(`${home}/`))) return `~${cwd.slice(home.length)}`;
	return cwd;
}

/** `left` and `right` on one line, giving up the end of `left` before any of `right`. */
function spread(left: string, right: string, width: number): string {
	const rightWidth = visibleWidth(right);
	if (rightWidth + 2 > width) return truncateToWidth(left, width, "…");
	const l = truncateToWidth(left, width - rightWidth - 2, "…");
	return l + " ".repeat(Math.max(2, width - visibleWidth(l) - rightWidth)) + right;
}

/** Join segments, dropping the most expendable ones until the line fits. */
function fit(segments: Segment[], separator: string, width: number): string {
	const live = [...segments];
	const joined = () => live.map((s) => s.text).join(separator);
	while (live.length > 1 && visibleWidth(joined()) > width) {
		let worst = 0;
		for (let i = 1; i < live.length; i++) if (live[i].drop >= live[worst].drop) worst = i;
		live.splice(worst, 1);
	}
	return truncateToWidth(joined(), width, "…");
}

/** "🧠 nixos · ready" → "🧠 nixos"; problems are highlighted, work in progress shown as-is. */
function engramSegment(status: string, theme: Theme): string {
	const text = oneLine(plain(status));
	const match = /^(🧠 .+?) · (.+)$/.exec(text);
	if (!match) return theme.fg("dim", text);
	const [, label, state] = match;
	if (state === "ready") return theme.fg("dim", label);
	if (/offline|error|ambiguous|disabled/i.test(state)) return theme.fg("warning", text);
	return theme.fg("dim", text);
}

/** The MCP summary is noise while healthy; keep only what needs attention. */
function mcpAttention(status: string): string | undefined {
	const text = oneLine(plain(status)).replace(/^🔌 /, "");
	const blocked = /\((\d+) blocked by project trust\)/.exec(text);
	if (blocked) return `MCP: ${blocked[1]} blocked by project trust`;
	const tasks = /(\d+ MCP tasks?)/.exec(text);
	return tasks ? tasks[1] : undefined;
}

function usageTotals(ctx: ExtensionContext): Totals {
	const totals = { input: 0, output: 0 };
	// biome-ignore lint/suspicious/noExplicitAny: session entries are a wide union; only usage matters here.
	for (const entry of ctx.sessionManager.getEntries() as any[]) {
		const usage =
			entry.type === "usage"
				? entry.usage
				: entry.type === "message" && (entry.message.role === "assistant" || entry.message.role === "toolResult")
					? entry.message.usage
					: entry.type === "branch_summary" || entry.type === "compaction"
						? entry.usage
						: undefined;
		if (usage) {
			// Cached prompt tokens are still prompt tokens; pi's `input` excludes them, which
			// on a heavily cached Copilot session shows a few hundred instead of millions.
			totals.input += (usage.input ?? 0) + (usage.cacheRead ?? 0) + (usage.cacheWrite ?? 0);
			totals.output += usage.output ?? 0;
		}
	}
	return totals;
}

export default function footer(pi: ExtensionAPI) {
	let enabled = true;

	function install(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		if (!enabled) {
			ctx.ui.setFooter(undefined);
			return;
		}

		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

			// The footer renders every frame; only rescan the session when it changed.
			let cacheKey = "";
			let totals: Totals = { input: 0, output: 0 };
			const cachedTotals = (): Totals => {
				const key = `${ctx.sessionManager.getEntries().length}:${ctx.sessionManager.getLeafId()}`;
				if (key !== cacheKey) {
					totals = usageTotals(ctx);
					cacheKey = key;
				}
				return totals;
			};

			return {
				dispose: unsubscribe,
				invalidate() {},
				render(width: number): string[] {
					const dim = (text: string) => theme.fg("dim", text);
					const statuses = footerData.getExtensionStatuses();

					// Line 1: where, and with what.
					let where = formatCwd(ctx.sessionManager.getCwd());
					const branch = footerData.getGitBranch();
					if (branch) where += ` (${branch})`;
					const name = pi.getSessionName();
					if (name) where += ` • ${name}`;
					const model = ctx.model;
					let what = model?.id ?? "no model";
					if (model?.reasoning) {
						const level = pi.getThinkingLevel();
						what += level === "off" ? " • thinking off" : ` • ${level}`;
					}
					const line1 = spread(dim(where), dim(what), width);

					// Line 2: what this session has used.
					const segments: Segment[] = [];
					const usage = ctx.getContextUsage();
					const window = usage?.contextWindow ?? model?.contextWindow ?? 0;
					const pct = usage?.percent;
					const pctText = pct == null ? "?" : trim(pct, pct < 10 ? 1 : 0);
					const pctColor = pct != null && pct > 90 ? "error" : pct != null && pct > 70 ? "warning" : "dim";
					segments.push({ text: theme.fg(pctColor, `${pctText}% of ${formatTokens(window)}`), drop: 0 });

					const { input, output } = cachedTotals();
					if (input || output) segments.push({ text: dim(`↑${formatTokens(input)} ↓${formatTokens(output)}`), drop: 2 });

					const copilot = statuses.get("copilot-credits");
					if (copilot) {
						oneLine(copilot)
							.split(COPILOT_SEPARATOR)
							.forEach((part, i) => {
								// Headline % and any overage warning stay; the rest goes first.
								const keep = i === 0 || plain(part).includes("overage");
								segments.push({ text: part, drop: keep ? 1 : 4 + i });
							});
					}

					const engram = statuses.get("engram");
					if (engram) segments.push({ text: engramSegment(engram, theme), drop: 3 });

					const line2 = fit(segments, dim(" · "), width);

					// Line 3: only while something is happening or needs attention.
					const active: string[] = [];
					const first = ["subagents", "bg"]; // running work before everything else
					const order = (key: string) => (first.includes(key) ? `${first.indexOf(key)}` : key);
					for (const [key, value] of [...statuses].sort(([a], [b]) => order(a).localeCompare(order(b)))) {
						if (key === "copilot-credits" || key === "engram") continue;
						if (key === "mcp") {
							const attention = mcpAttention(value);
							if (attention) active.push(theme.fg("warning", attention));
						} else if (key === "subagents") {
							active.push(theme.fg("accent", oneLine(value)));
						} else if (key === "bg") {
							// pi-bg-bash: "bg: 2" while background commands run.
							const n = Number(/\d+/.exec(plain(value))?.[0]);
							const text = Number.isFinite(n) ? `${n} background command${n === 1 ? "" : "s"}` : oneLine(value);
							active.push(theme.fg("accent", text));
						} else {
							active.push(oneLine(value));
						}
					}
					if (active.length === 0) return [line1, line2];
					const line3 = truncateToWidth(active.join(dim(" · ")), width, "…");
					return [line1, line2, " ".repeat(Math.max(0, width - visibleWidth(line3))) + line3];
				},
			};
		});
	}

	pi.on("session_start", (_event, ctx) => install(ctx));

	pi.registerCommand("footer", {
		description: "Toggle between the quiet footer and pi's built-in one",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			install(ctx);
			ctx.ui.notify(enabled ? "Quiet footer on" : "Built-in footer restored", "info");
		},
	});
}
