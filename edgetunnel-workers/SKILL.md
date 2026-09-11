---
name: edgetunnel-workers
description: Deploy and maintain an independent cmliu/edgetunnel Cloudflare Worker with KV, custom domain, private credentials, tested ingress selection and validated subscriptions. Use for Workers deployment, IP selection, updates and troubleshooting; never reuse the sg VPS deployment.
---

# Independent Workers deployment

## Scope and safeguards

- Use Workers, not Pages. Keep account, credentials, KV, domains and artifacts independent of VPS skills.
- Use neutral public resource names such as `edge-<random suffix>` and matching `<name>.<zone>`; do not include `edgetunnel` in Worker, KV or hostname names. Naming does not ensure avoidance of platform enforcement. Observe current Cloudflare terms and limits.
- Obtain authorization before creating resources or changing DNS. Never migrate a zone or overwrite an existing record implicitly.
- Read [references/workers-deployment.md](references/workers-deployment.md) before deployment, [references/ip-selection.md](references/ip-selection.md) before generating candidates or subscriptions, and [references/client-testing.md](references/client-testing.md) for v2rayN acceptance tests and failure diagnosis.
- Pin an upstream commit and record SHA-256; review upstream README, source and wrangler configuration. Do not auto-deploy moving main.
- Secrets belong outside the repository, directory mode 700 and files 600. Never print tokens, ADMIN, UUID, KEY or full subscriptions in routine logs.

## Workflow

1. Confirm target account ID, active same-account zone, client/version, real test networks, budget and authorization.
2. Validate credentials using the appropriate account-token or user-token endpoint. A mismatch of verification endpoint does not prove all API access invalid; check required resource endpoints individually.
3. Preflight scripts, KV, custom domains and DNS record inspection. Stop on missing permissions; do not bypass collision checks.
4. Generate unique resource name and independent ADMIN, UUIDv4 and KEY; persist private state before mutations.
5. Create KV and deploy the ES module using the pinned compatibility date. Bind uppercase `KV`; use secret_text for credentials. Keep DEBUG/BEST_SUB off initially.
6. Bind Worker Custom Domain after collision checking, then verify DNS/TLS, authenticated panel and persistent KV settings.
7. Establish VLESS WS TLS domain-address baseline, certificate verification enabled and optional optimizations off. Obtain an actual authenticated client test.
8. Select ingress candidates on the user's real network, save a small validated list and verify subscription round trips.
9. Back up code, binding metadata, private settings and relevant KV data before upgrades. Code rollback does not roll back KV. Delete only resources created by this deployment when explicitly authorized.

## Evidence boundaries

Panel HTML, a successful HTTP GET, TCP latency and a valid candidate API response do not establish proxy connectivity. Distinguish local browser, remote VPS and real user-network test origins. Report partial deployment and unavailable evidence precisely. Do not infer fixed country egress from ingress country labels. Never carry over the SG seven-node naming or protocol set.

## Sources

- https://github.com/cmliu/edgetunnel
- https://blog.cmliussss.com/p/edt2/
- https://developers.cloudflare.com/workers/configuration/routing/custom-domains/
- https://developers.cloudflare.com/workers/platform/limits/

The blog describes a 2.0 Pages workflow; adapt concepts to Workers and verify against the pinned 2.1 source rather than copying Pages upload steps.
