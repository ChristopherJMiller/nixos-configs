/**
 * Ctrl+B sends a running bash command to the background, as in Claude Code.
 *
 * pi-bg-bash binds ctrl+shift+b for this, and pi-subagents already binds
 * ctrl+b for foreground `Agent` calls. This makes ctrl+b do the same for
 * commands, so one key backgrounds whatever is running:
 *
 * - While a foreground `Agent` call runs, the key is left to pi-subagents,
 *   which backgrounds the agent (its own commands keep running inside it).
 * - Otherwise, the key promotes this session's foreground `bash` calls.
 * - With neither running, it falls through to the editor (cursor-left).
 *
 * pi-bg-bash keeps its in-flight foreground calls process-wide, including
 * those of subagents (they run in this process), and records no owner. So
 * this session's own calls are tracked from tool events and matched to the
 * registry by command.
 *
 * The registry is internal to pi-bg-bash:
 * globalThis[Symbol.for("pi-bg-bash.registry")].foreground is a Set of
 * { command, startedAt, promote(by) }. The package is pinned in
 * common/pi.nix; re-check this file when bumping it. If the shape changes,
 * this quietly does nothing and ctrl+shift+b still works.
 *
 * Managed by Nix (common/pi/background-key.ts in the nixos repo).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isKeyRelease, matchesKey } from "@earendil-works/pi-tui";

const REGISTRY = Symbol.for("pi-bg-bash.registry");

interface ForegroundRun {
	command: string;
	promote(by: "shortcut"): void;
}

function foregroundRuns(): ForegroundRun[] {
	const registry = (globalThis as Record<symbol, { foreground?: unknown } | undefined>)[REGISTRY];
	const runs = registry?.foreground;
	if (!(runs instanceof Set)) return [];
	return [...runs].filter(
		(run): run is ForegroundRun => typeof run?.promote === "function" && typeof run?.command === "string",
	);
}

export default function backgroundKey(pi: ExtensionAPI) {
	/** This session's foreground bash calls in flight: toolCallId → command. */
	const bashCalls = new Map<string, string>();
	/** This session's foreground Agent calls in flight. */
	const agentCalls = new Set<string>();
	let unsubscribe: (() => void) | undefined;

	const reset = () => {
		bashCalls.clear();
		agentCalls.clear();
	};

	pi.on("tool_execution_start", (event) => {
		const args = event.args ?? {};
		if (event.toolName === "bash" && args.background !== true && typeof args.command === "string") {
			bashCalls.set(event.toolCallId, args.command);
		} else if (event.toolName === "Agent" && args.run_in_background === false) {
			// pi-subagents runs agents in the background unless told otherwise.
			agentCalls.add(event.toolCallId);
		}
	});
	pi.on("tool_execution_end", (event) => {
		bashCalls.delete(event.toolCallId);
		agentCalls.delete(event.toolCallId);
	});
	// Belt and braces: nothing is in flight once the agent loop has ended.
	pi.on("agent_end", reset);

	pi.on("session_start", (_event, ctx) => {
		unsubscribe?.();
		unsubscribe = undefined;
		reset();
		if (!ctx.hasUI) return;
		unsubscribe = ctx.ui.onTerminalInput((data) => {
			// Kitty reports key releases too; act on the press only.
			if (isKeyRelease(data) || !matchesKey(data, "ctrl+b")) return undefined;
			if (agentCalls.size > 0 || bashCalls.size === 0) return undefined;
			const mine = [...bashCalls.values()];
			const runs = foregroundRuns().filter((run) => mine.some((command) => run.command.includes(command)));
			if (runs.length === 0) return undefined;
			// Parallel tool calls can leave several commands in the foreground at once.
			for (const run of runs) run.promote("shortcut");
			return { consume: true };
		});
	});

	pi.on("session_shutdown", () => {
		unsubscribe?.();
		unsubscribe = undefined;
		reset();
	});
}
