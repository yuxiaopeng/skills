# Ingress selection and subscription validation

## Baseline and measurement

Keep one default-domain baseline and approximately 3–5 verified candidates. Measure from the actual user ISP, with browser/system proxy and TUN disabled for ingress selection. Home broadband and cellular results are separate; never claim three-ISP testing from one network. Obtain client name/version before protocol acceptance tests.

Use: modest candidate sample → TCP/TLS screening → actual Worker WS authentication → controlled proxy throughput tests → repeat during peak hours. Record origin, timestamp, client/version, IP/port, domain, success rate, throughput and observed egress. Browser region labels and ping do not guarantee fixed egress or real proxy performance.

### Interpret client tests correctly

- **Tcping** measures TCP reachability/connection time from the client to the candidate address and port. It does not test TLS, WebSocket, authentication or Worker egress.
- **True connection latency** (for example v2rayN's real-connection test) is an application request made through the complete node. Its measured interval normally includes client network → candidate edge IP → Cloudflare/Worker processing → Worker outbound connection → test target response → return path. It is therefore the most relevant first comparison for a candidate, but it is not a pure RTT and varies with the test URL, connection reuse, DNS and target load.
- **Speed tests** measure throughput through the selected node to that test object; use after true-connection screening and compare equal conditions.
- **UDP latency** is not a validity test for this VLESS-over-WS Worker baseline. Do not reject a web/HTTPS node solely because UDP testing fails.

For a fair comparison, keep Worker hostname, SNI, WS Host, path, UUID, port, client/core, test URL and test time conditions constant; change only the server address. Repeat results and retain stable candidates rather than the single lowest sample. A low true-connection value proves good end-to-end performance to that test target, not that every website or the final egress country will be faster.

Client server address may be a selected IP/domain; TLS SNI and WS Host remain the deployment domain. Preserve the exact configured path and certificate verification. IPv6 requires real IPv6 reachability.

## IP versus domain selection

An optimized IP pins the client server address to one tested ingress candidate. An optimized domain resolves to one or more candidates maintained by its operator. Domains do not accelerate traffic by themselves and multiple DNS answers do not imply fastest-IP selection or reliable failover. Cloudflare Anycast means a fixed IP does not guarantee a fixed edge location.

Keep the Worker Custom Domain binding and DNS unchanged when selecting client ingress addresses. An optional self-maintained selector hostname can use DNS-only A/AAAA records pointing to verified ingress candidates while client TLS SNI and WS Host remain the Worker hostname. Creating it requires separate DNS-change approval. Do not orange-cloud that selector expecting its chosen addresses to remain visible, or treat it as another Worker Custom Domain by default.

### Third-party bulk lists

Examples raised by the user: `https://zip.cm.edu.kg`, `/all.txt`, `/all.json`. Treat these as untrusted candidate sources, not certified Worker ingress or PROXYIP pools. Re-fetch and inspect current content types and schemas; the root download was previously an archive rather than a plain-text feed. Parse JSON into the panel's supported address format rather than adding arbitrary JSON directly as a text API. Deduplicate, cap the sample and separate official Cloudflare addresses from third-party forwarders. Public presence is not authorization to use a forwarder. Country tags and successful probes against a Cloudflare test site do not establish access to this Worker's hostname.

Prefer importing a verified snapshot first; only retain a live API dependency after checking ownership, stability, request privacy and fallback behavior. Never disable certificate verification to make a candidate pass.

## Three selection modes from the author's tutorial

### Random selection

The project uses ISP-related candidate logic based on subscription request origin. Direct subscription updates on the intended network help correct identification; proxy updates may select the proxy network or broader fallback candidates. Random selection is not user-specific throughput measurement. Keep count modest, start with port 443. Other documented TLS ports: 2053, 2083, 2087, 2096, 8443; verify full-path support individually. Random ports are not a guaranteed fix for response -1.

### Custom selection (recommended)

- Manual records: `IP-or-domain:port#remark`, one per line. IPv6 must be bracketed. Missing port defaults to 443, missing label displays address. Prefer official or personally tested candidates; third-party domains/forwarders need separate review.
- Online selection: author's UI requires direct CN access. Choose official or author-maintained candidate library, start with 4–8 threads, port 443. Select results, append/save, then save parent configuration and re-open to confirm persistence. This tool's geography restrictions do not imply measurements elsewhere are universally meaningless.
- Text API / CloudflareSpeedTest CSV / iptest CSV: use panel format validation and check parsed addresses/ports. "Append results" saves a snapshot. "Append API" retains a remote source to fetch during subsequent generation; it does not schedule measurements on the user's network. A successful API parse is not a proxy test.

For automation, measure on the real network, filter a bounded list, publish only non-secret candidate data on a controlled HTTPS endpoint and refresh client subscriptions. Implement last-known-good fallback in the feed/automation; do not assume upstream automatically provides it. Avoid large scans, excessive downloads and continual candidate churn.

### External generator

Optional third-party dependency, not the baseline. Review request parameters, privacy and provenance. Consuming an external generator is distinct from enabling BEST_SUB on one's own Worker. Never send credentials or private subscription URLs to untrusted converters or test services.

## Client delivery

Begin with VLESS WS TLS; derive all parameters from live validated profiles. The project's protocol switch is not proof of simultaneous independent VLESS/Trojan/SS services. Do not invent VMess/REALITY/Hysteria2 links or apply the SG seven-node template.

Decode/parse delivered links and verify UUID, server, port, transport, SNI, Host, literal runtime path, TLS verification and label. Percent-encode URI fields exactly once. Save generated bytes privately and output verbatim when requested; never hand-transcribe encoded credentials. Check requested count, order and duplicates. Determine subscription format from the actual client/version; prefer original links or trusted local conversion. External converters may receive retrievable credential-bearing subscriptions.

Maintenance: retain baseline, check selected candidates at low frequency, remeasure periodically and under peak load, retire after repeated failure, preserve last good list on source failure. No fixed-country claims without independent exit checks.
