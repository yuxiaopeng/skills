# Staged deployment runbook

## Phase 0: discover and freeze

Collect the public IPv4/IPv6, OS family, active services, core versions, current domain names, DNS proxy states, current TLS SANs, and all listening ports. Identify whether the host uses Xray fragments, sing-box fragments, or both. Record the current `v2ray-agent` version and the upstream commit or download timestamp.

Resolve hostname conflicts from live evidence. The active WSS hostname is the Host/SNI used by the working client and the 443 TLS entry, not necessarily the hostname implied by the VPS alias or requested node label. Preserve that hostname for WS clones.

Before changing anything, back up:

```text
/etc/v2ray-agent/xray/
/etc/v2ray-agent/sing-box/
/etc/v2ray-agent/tls/
/etc/v2ray-agent/subscribe_local/
/etc/v2ray-agent/subscribe/
```

Do not expose the backup archive if it contains private keys or credentials.

## Phase 1: VLESS_WS and VMess_WS baseline

Use the latest upstream `v2ray-agent` installation flow to create or verify the direct nodes. Let the script generate valid UUIDs and subscription records. Preserve any existing working entries; if a second entry is needed, use a new UUID/email or explicitly link an existing client only when the schema supports it.

Capture the generated facts:

- hostname and whether it is orange-clouded;
- TLS certificate/key paths;
- 443 fallback paths and local destinations;
- VLESS and VMess client IDs;
- WebSocket path, Host, SNI, and port;
- direct outbound tag.

Test each node independently through the hostname. A raw HTTP request to a WS path is not a protocol test; a successful test must authenticate the proxy client and reach a trace endpoint.

Record hashes of the direct VLESS and VMess source fragments before mutation. Compare them after deployment; matching runtime behavior alone does not prove that their UUIDs, paths, or tags were preserved.

## Phase 2: REALITY

Use the current agent's REALITY management flow. Do not install a certificate for REALITY unless another service independently needs one. Use a DNS-only hostname that resolves to the VPS. Record the generated private/public key pair, short ID, server name, flow, transport, and port in the user's secret store; never put private keys in this skill.

If the current agent uses XHTTP, keep its generated XHTTP host/path/mode. If it uses TCP Vision, keep the generated flow and fingerprint. Do not copy parameters between those transports.

Validate the runtime config and test the exact client profile. A REALITY `serverName` is normally a configured camouflage target, while the connection address is the DNS-only node hostname or VPS address according to the generated profile.

When 443 is already the protected WSS front door, an additive REALITY deployment normally needs a separate TCP port. Xray warns that REALITY on a non-443 port can be easier to identify or block; record this tradeoff instead of replacing the working 443 entry.

## Phase 3: Hysteria2

Create a DNS-only hostname, allow the selected UDP port at the provider and host firewall, and verify that the certificate SAN covers the Hysteria2 SNI. The certificate can be:

- a dedicated certificate for the Hysteria2 hostname; or
- an existing wildcard certificate whose SAN and file permissions have been checked.

Point the Hysteria2 fragment at the hostname-specific certificate alias if the agent requires per-name paths. Keep the original WSS certificate and paths unchanged. Use the agent-generated password/UUID and bandwidth values, then test a real Hysteria2 client with certificate verification enabled.

On sing-box 1.12 and later, do not rely blindly on the host resolver. Tailscale or another resolver manager may install an unreachable DNS server even while `getent` appears to work intermittently. If sing-box must resolve outbound domains, define explicit DNS servers and set `route.default_domain_resolver`; validate the installed sing-box schema before restarting. Keep the DNS source fragment separate from the merged `config.json`.

Do not use an orange-cloud hostname for standard Hysteria2. Cloudflare's normal proxy does not carry arbitrary UDP/QUIC to the origin.

## Phase 4: WARP clones for WS

Determine whether the host already has a WARP implementation. For this topology, prefer the agent-supported third-party WARP registration plus Xray WireGuard/gVisor outbound. Back up the registration file before rotating it.

Clone the baseline VLESS and VMess WS inbounds rather than changing them:

- assign distinct local ports and tags;
- assign distinct paths, such as a VLESS-specific path and a VMess-specific path;
- keep the same TLS hostname and 443 front door;
- add both paths to the 443 fallback list;
- add one WireGuard WARP outbound using the current registration's private key, peer key, reserved bytes, and IPv4 address;
- add one inbound-tag routing rule covering only the two WARP clone tags.

For current Xray WireGuard, force the userspace gVisor/netstack implementation with `settings.noKernelTun: true`. `kernelMode: false` is not the Xray field and may be silently ignored. Confirm the runtime log says `Using gVisor TUN`; a valid JSON/config check does not prove that the desired implementation was selected. For an IPv4-only WARP outbound, also use the installed schema's IPv4 domain strategy and test an IPv4 destination explicitly.

The direct nodes must continue to route to the direct outbound. The WARP route must not be a global default unless the user explicitly requests global WARP.

After a WARP registration rotation, the public WARP IPv4 may remain the same. Verify the new tunnel with `warp=on`; do not promise a different or residential IP. Test the WireGuard outbound through a temporary local SOCKS inbound before testing the WS clones. This isolates registration/UDP/TUN failures from fallback/path/authentication failures.

## Phase 5: merge, restart, and test

Use the currently installed core's supported config check and merge commands. Validate source fragments first, then the merged runtime config. Restart only the affected core and check its systemd status, listening sockets, and recent logs.

Run these tests separately:

1. VLESS WS direct: expect a VPS IPv4 or IPv6 and `warp=off`.
2. VMess WS direct: expect a VPS IPv4 or IPv6 and `warp=off`.
3. REALITY: expect the configured direct route.
4. Hysteria2: expect successful TLS/QUIC and the configured direct route.
5. VLESS WS WARP: for an IPv4 WARP outbound, force the test request to IPv4; expect a Cloudflare IP and `warp=on`.
6. VMess WS WARP: use the same address family as the configured WARP outbound; expect a Cloudflare IP and `warp=on`.

Run the client with its normal DNS path first. If Hysteria2 fails before QUIC starts, inspect the client log for DNS errors. Retest with the resolved server IP as the connection address while retaining the original hostname as TLS SNI; success proves UDP/TLS is healthy and isolates resolver failure. Do not disable certificate verification for the final hostname test.

For a failure, correlate the client attempt timestamp with Xray and nginx logs. Typical signatures:

| Log symptom | Likely cause |
|---|---|
| nginx `GET //path` and 404 | client sent a double slash; fallback path did not match |
| nginx serves a WS path as a file | wrong path or wrong protocol fallback |
| Xray `invalid request version` | VLESS request reached a non-VLESS path or malformed client profile |
| Xray `invalid user` | wrong UUID/password or VMess/VLESS mix-up |
| no server log at all | DNS, Cloudflare mode, port, firewall, or client transport problem |
| Hysteria2 timeout with correct local listener | orange cloud or UDP firewall/provider block |
| Hysteria2 client log shows DNS timeout | broken local/Tailscale resolver; test by IP + original SNI, then configure an explicit sing-box resolver |
| WARP route log appears but trace times out | WireGuard registration, endpoint UDP reachability, or unintended kernel TUN mode; isolate the outbound and confirm `Using gVisor TUN` |
