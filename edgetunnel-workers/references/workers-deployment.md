# Workers deployment reference

## Inputs and authentication

Required: target account, active same-account zone, intended hostname, scoped API authorization and explicit mutation approval. Prefer a dedicated account. Workers Custom Domain is not equivalent to Pages cross-provider CNAME setup.

Store shell-style CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN in a private file outside Git. Parse without executing arbitrary shell contents and never display it. Suggested permissions, restricted to the target resources:

- Account / Workers Scripts / Edit
- Account / Workers KV Storage / Edit
- Zone / Zone / Read
- Zone / Workers Routes / Edit
- Zone / DNS / Read for safe record collision checks

Actual endpoint requirements must be confirmed during preflight. Request additional rights only when necessary; never use Global API Key. DNS Write is not automatically needed for read-only collision checks.

A first deployment preflight found Zone Read was sufficient to confirm zone/account matching, but DNS record listing returned HTTP 403 code 10000 without DNS Read. Stop before creating resources and ask for that scoped permission. Account-token verification can return 401 for a user API token; select the corresponding verification API and test resource permissions separately.

## Reproducible deployment

1. Resolve upstream commit, retrieve source and wrangler.toml at that commit and record hashes. Current reviewed commit: 448a83ced00a43c1d892d5ecbed86a26ea9eeaff. Reviewed compatibility_date: 2025-11-04. Recheck before upgrades.
2. Generate neutral unique public names, independent UUIDv4 and random ADMIN/KEY; write private deployment state, mode 600.
3. Check both existing scripts and hostname records. Resume only resources explicitly identified in saved state; no silent overwrite.
4. Create a dedicated KV namespace and immediately persist its ID.
5. Upload ES module _worker.js with main_module and compatibility_date, KV namespace binding and secret_text credentials. Keep DEBUG and BEST_SUB false initially.
6. Bind custom domain via Workers domain API or dashboard. Record resource IDs and completion flags after each successful mutation.
7. Verify domain activation, certificate, /admin authentication and configuration persistence. A camouflage homepage is not an acceptance test.
8. Start with VLESS WS TLS, 0-RTT/ECH/extra dialing optimization off. Confirm live configuration rather than assuming all defaults.

PROXYIP is an outbound/fallback facility, not ingress optimization or guaranteed fixed egress. Public proxy services introduce authorization, privacy and reliability questions; evaluate separately. Inspect actual default outbound behavior before stating that deployment has no third-party dependencies.

## Recovery and operations

Back up deployed source, version/hash, metadata and KV configuration/list data securely. Do not replace all KV contents or reset UUID on upgrade. Secret rotation may affect subscriptions; verify after changes. Re-read state and current API resources following timeouts rather than assuming mutations failed or succeeded.

Do not put deployment credentials or a broadly privileged metrics token in the panel. If enabling usage metrics, use a separate minimal read-only token. Check current free-plan limits; Pages static asset rules do not apply to Workers tunnels, and extra accounts are not a recommended quota workaround.
