# Client acceptance and troubleshooting

## macOS v2rayN

The user identified macOS ARM64 v2rayN V7.24.9. This is client context, not proof that a successful authenticated test has occurred. Record the selected core and its version as well as the application version when debugging.

1. Authenticate to the panel and copy its generated VLESS WS TLS link, without sharing it with an external converter.
2. Import from clipboard. For a default baseline, duplicate a generated candidate and change only the connection address to the Worker Custom Domain.
3. Confirm port 443, TLS enabled, skip certificate verification false, WS transport, correct domain for SNI/Host, exact generated path and no Vision flow.
4. For manual browser acceptance, select the node and enable the client's system proxy; start without TUN. Verify HTTPS access and, separately, observed exit IP. Browser traffic must actually use that proxy.
5. For v2rayN's built-in tests, the client normally creates a test path through each selected node; it need not make each node the active system proxy. Inspect logs/core behavior if uncertain. Disable TUN and other proxy applications to prevent unintended nested routing.
6. For panel online ingress selection, disable system proxy and TUN so the browser measures the real user ISP. These conditions differ from manual browser proxy acceptance.

Reported UI actions in this version:

- Tcping: Control + Shift + 0
- True connection latency: Control + Shift + R
- Speed test: Control + Shift + T
- UDP latency: not a baseline acceptance requirement

Use the actual UI bindings if they differ. First confirm the default node, then screen small candidate batches, repeat true-connection tests and speed-test 3–5 finalists sequentially or with low concurrency. Parallel downloads compete for the same local link and distort ranking.

## Failure evidence

Collect sanitized logs, attempt timestamp/timezone, user network/ISP, test URL, application/core version and settings with credentials removed. A -1 response means that attempt failed, not a diagnosis of SNI blocking or unusable IP. If every candidate fails, test the default domain and another appropriate test URL before replacing the entire list.

Useful layers:

| Observation | Next check |
|---|---|
| TCP fails | DNS/address, port, local path and reachability |
| TCP passes, true connection fails | TLS/SNI, WS Host/path, UUID, Worker exception, outbound path and test target |
| True connection passes, speed low | Test object, concurrent local traffic, peak-time routing, Worker/outbound constraints |
| Panel loads, proxy fails | Separate UI fetch path from authenticated protocol handling |
| Config GET succeeds | Does not yet prove settings PUT and KV persistence |
| UDP fails, HTTPS works | Verify intended UDP support rather than declaring TCP failure |

## Deployment acceptance report

Report each item independently: source pinned, resources created, domain/certificate active, authenticated login, config read, config save/re-read, subscription round-trip, actual proxy access, throughput, and user-network IP selection. Never mark unfinished items as passed. Code rollback and KV/config restoration are distinct operations.

When handing credentials to the user, name the private artifact path and field to read locally rather than dumping secrets into routine output. Treat screenshots, clipboard contents, exported configs and full subscription URLs as sensitive. If image parsing is unavailable, ask for sanitized text instead of inferring screenshot contents.
