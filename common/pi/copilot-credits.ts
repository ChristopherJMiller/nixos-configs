/**
 * Copilot credits in the footer.
 *
 * Shows the GitHub Copilot premium-request quota (what the enterprise plan
 * calls AI credits) next to the other footer statuses, e.g.
 *
 *     Copilot 99.9% (−12) · 999.8K/1M · resets Dec 1
 *
 * where (−12) is what this session has spent. Parts are joined with a plain,
 * uncoloured " · " so footer.ts can split them and drop the least useful ones
 * on narrow terminals; keep that contract if you change the format.
 *
 * The number comes from api.github.com/copilot_internal/user, read with the
 * GitHub OAuth token Pi already stored for its `github-copilot` login, so
 * there is nothing extra to sign in to. It refreshes when a session starts
 * and after each agent run (at most every 30s), never while idle.
 * `/copilot-credits` forces a refresh and prints the full breakdown.
 *
 * Managed by Nix (common/pi/copilot-credits.ts in the nixos repo).
 */

import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "copilot-credits";
const MIN_REFRESH_MS = 30_000;
const QUOTA_URL = "https://api.github.com/copilot_internal/user";

interface Quota {
	entitlement: number;
	remaining: number;
	percent_remaining: number;
	unlimited: boolean;
	overage_permitted?: boolean;
	overage_count?: number;
}

interface CopilotUser {
	copilot_plan?: string;
	quota_reset_date?: string;
	quota_snapshots?: { premium_interactions?: Quota };
}

const compact = new Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 });
const full = new Intl.NumberFormat("en");

/** The GitHub OAuth token. (`access` is the short-lived Copilot API token, which this endpoint rejects.) */
async function githubToken(): Promise<string | undefined> {
	try {
		const auth = JSON.parse(await readFile(join(getAgentDir(), "auth.json"), "utf8"));
		const token = auth?.["github-copilot"]?.refresh;
		return typeof token === "string" && token.length > 0 ? token : undefined;
	} catch {
		return undefined;
	}
}

function resetLabel(date: string | undefined): string | undefined {
	if (!date) return undefined;
	const parsed = new Date(`${date}T00:00:00Z`);
	if (Number.isNaN(parsed.getTime())) return undefined;
	return parsed.toLocaleDateString("en", { month: "short", day: "numeric", timeZone: "UTC" });
}

export default function copilotCredits(pi: ExtensionAPI) {
	let baseline: number | undefined; // credits remaining when this session started
	let latest: CopilotUser | undefined;
	let lastFetch = 0;
	let inflight: Promise<void> | undefined;

	async function fetchQuota(): Promise<CopilotUser | string> {
		const token = await githubToken();
		if (!token) return "not signed in (/login)";
		try {
			const res = await fetch(QUOTA_URL, {
				headers: { Authorization: `token ${token}`, Accept: "application/json" },
				signal: AbortSignal.timeout(10_000),
			});
			if (!res.ok) return `quota API ${res.status}`;
			return (await res.json()) as CopilotUser;
		} catch {
			return "quota unavailable";
		}
	}

	function render(ctx: ExtensionContext, data: CopilotUser | string): void {
		const { theme } = ctx.ui;
		if (typeof data === "string") {
			ctx.ui.setStatus(STATUS_KEY, theme.fg("dim", `Copilot ${data}`));
			return;
		}
		const quota = data.quota_snapshots?.premium_interactions;
		if (!quota) {
			ctx.ui.setStatus(STATUS_KEY, theme.fg("dim", "Copilot no quota data"));
			return;
		}
		if (quota.unlimited) {
			ctx.ui.setStatus(STATUS_KEY, theme.fg("dim", "Copilot unlimited"));
			return;
		}

		baseline ??= quota.remaining;
		const used = Math.max(0, baseline - quota.remaining);
		const pct = quota.percent_remaining;
		const color = pct <= 10 ? "error" : pct <= 25 ? "warning" : "dim";

		let headline = theme.fg(color, `Copilot ${pct.toFixed(1)}%`);
		if (used > 0) headline += theme.fg("dim", ` (−${full.format(used)})`);
		const parts = [headline, theme.fg("dim", `${compact.format(quota.remaining)}/${compact.format(quota.entitlement)}`)];
		if (quota.overage_count) parts.push(theme.fg("warning", `+${full.format(quota.overage_count)} overage`));
		const reset = resetLabel(data.quota_reset_date);
		if (reset) parts.push(theme.fg("dim", `resets ${reset}`));
		ctx.ui.setStatus(STATUS_KEY, parts.join(" · "));
	}

	function refresh(ctx: ExtensionContext, force = false): Promise<void> {
		if (!ctx.hasUI) return Promise.resolve();
		if (inflight) return inflight;
		if (!force && Date.now() - lastFetch < MIN_REFRESH_MS) return Promise.resolve();
		lastFetch = Date.now();
		inflight = fetchQuota()
			.then((data) => {
				if (typeof data !== "string") latest = data;
				render(ctx, data);
			})
			.finally(() => {
				inflight = undefined;
			});
		return inflight;
	}

	pi.on("session_start", (_event, ctx) => {
		baseline = undefined;
		// Don't hold up startup on the network.
		void refresh(ctx, true);
	});

	pi.on("agent_end", (_event, ctx) => {
		void refresh(ctx);
	});

	pi.registerCommand("copilot-credits", {
		description: "Refresh and show GitHub Copilot credit usage",
		handler: async (_args, ctx) => {
			await refresh(ctx, true);
			const quota = latest?.quota_snapshots?.premium_interactions;
			if (!latest || !quota) {
				ctx.ui.notify("Copilot quota unavailable", "warning");
				return;
			}
			const lines = [
				`Plan: ${latest.copilot_plan ?? "unknown"}`,
				quota.unlimited
					? "Premium requests: unlimited"
					: `Remaining: ${full.format(quota.remaining)} of ${full.format(quota.entitlement)} (${quota.percent_remaining.toFixed(1)}%)`,
				`Used this session: ${full.format(Math.max(0, (baseline ?? quota.remaining) - quota.remaining))}`,
				`Overage: ${quota.overage_permitted ? "permitted" : "not permitted"}${quota.overage_count ? `, ${full.format(quota.overage_count)} used` : ""}`,
				`Resets: ${resetLabel(latest.quota_reset_date) ?? "unknown"}`,
			];
			ctx.ui.notify(lines.join("\n"), "info");
		},
	});
}
