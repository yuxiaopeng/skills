---
name: v2ray-agent-warp-edge
description: "Deploy and maintain a v2ray-agent edge node with VLESS/VMess WebSocket, REALITY, Hysteria2, Cloudflare DNS proxying, and per-inbound Cloudflare WARP egress. Use when a user wants a staged VPS proxy deployment while preserving existing nodes."
---

# v2ray-agent WARP edge

Use this skill for a VPS that is managed by the latest upstream `mack-a/v2ray-agent` and needs four staged protocol layers:

1. baseline `VLESS_WS` and `VMess_WS` direct-egress nodes;
2. a `VLESS REALITY` node;
3. a TLS/QUIC `Hysteria2` node;
4. cloned `VLESS_WS` and `VMess_WS` nodes whose traffic exits through Cloudflare WARP.

The deployment is additive. Existing working nodes, UUIDs, certificates, ports, and subscription salts remain unchanged unless the user explicitly authorizes a replacement.

Read [references/architecture.md](references/architecture.md) for the current route map and use cases. Read [references/deployment.md](references/deployment.md) before changing a VPS. Read [references/client-profiles.md](references/client-profiles.md) when producing client links or troubleshooting a node.

The optional `scripts/inspect-vps.sh` helper performs a redacted read-only inventory on the VPS. Run `scripts/validate-layout.sh` after source fragments are changed and before restarting a core; pass the v2ray-agent root as its first argument when it is not `/etc/v2ray-agent`, and optionally pass the pre-change backup root as the second argument to prove the baseline WS fragments are unchanged.

## Required workflow

Follow these phases in order and report a checkpoint after each phase:

1. Discover the VPS OS, installed `v2ray-agent` version, Xray/sing-box core, active ports, DNS records, certificates, and current subscriptions.
2. Fetch and inspect the current upstream `install.sh` from `https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh` before relying on menu numbers, function names, file names, or JSON schemas. Never copy line numbers from an older release.
3. Create timestamped backups of `/etc/v2ray-agent/xray`, `/etc/v2ray-agent/sing-box`, `/etc/v2ray-agent/tls`, and subscription files before mutation.
4. Configure or verify direct `VLESS_WS` and `VMess_WS` first. Keep their original paths and tags as the direct baseline.
5. Configure or verify `VLESS REALITY` on a DNS-only hostname. It does not use the WSS certificate.
6. Configure or verify `Hysteria2` on a DNS-only hostname. It requires a certificate whose SAN covers that hostname; a wildcard certificate may be reused only after checking its SAN and file permissions.
7. Provision or reuse a third-party WARP registration supported by the current agent. Add an Xray WireGuard/gVisor WARP outbound with the installed Xray schema's explicit userspace-TUN setting, then clone the two WS inbounds with distinct paths/tags. Route only those cloned inbound tags to WARP.
8. Rebuild generated configs using the core's supported merge/check command, restart only the affected service, and verify service health.
9. Test every path separately: direct VLESS, direct VMess, REALITY, Hysteria2, WARP VLESS, and WARP VMess. Compare direct and WARP egress with a trace endpoint and record `warp=on` for the latter.
10. Regenerate subscriptions only through the current agent's supported flow. If custom WARP nodes are not represented by the upstream subscription generator, provide explicit client profiles instead of silently changing existing subscription contents.

## DNS and Cloudflare invariants

- The WSS hostname may use the orange cloud because standard Cloudflare proxy supports WebSocket over an allowed HTTPS port.
- REALITY and Hysteria2 hostnames must be DNS-only unless the user has Cloudflare Spectrum or another product that explicitly supports the required transport.
- Standard Cloudflare proxy does not forward Hysteria2 UDP. A proxied Hysteria2 hostname will resolve to Cloudflare addresses but will not reach the VPS UDP listener.
- WARP is an egress path, not an inbound CDN. The WARP IP is Cloudflare-assigned and shared; it cannot be selected or guaranteed to remain fixed.

## Safety and compatibility

- Treat a user's explicit request to deploy or repair the VPS as authorization for ordinary in-scope registration, configuration validation, and service restarts. Do not repeatedly ask for the same authorization. Ask again only before changing external DNS/provider state, replacing an existing node or certificate, broad firewall changes, or another material scope expansion the user did not already request.
- Do not print UUIDs, passwords, private keys, WARP tokens, licenses, or full subscription URLs in routine logs or status responses. If the user explicitly requests import links, include only the client credentials needed by those links; never expose server-side REALITY private keys or WARP registration secrets.
- Never dump the WARP registration file while troubleshooting. Validate required fields by presence and redact account IDs, client IDs, licenses, tokens, private keys, public keys, and reserved bytes from captured output.
- On RHEL/Alma/Rocky systems, do not assume `dpkg` exists. Check `firewalld`, `nftables`, and `iptables` explicitly; an upstream `dpkg` error is a script compatibility issue, not proof that a UDP port is blocked.
- Do not mix `warp-svc` proxy mode and Xray WireGuard/gVisor routing unless the user explicitly asks for that topology. Verify which WARP implementation is active before adding another.
- Preserve the user's WSS certificate and existing direct nodes. For Hysteria2, changing only `server_name` is insufficient; the certificate and key paths must match and the certificate must cover the hostname.
- Derive the actual WSS hostname from the live 443 TLS entry, nginx configuration, certificate paths, and working client profile. A requested node label or newly resolved hostname is not evidence that it is the active WSS hostname; WARP clones must retain the working WSS Host/SNI unless the user explicitly asks to migrate it.
- Prefer upstream menu/functions for baseline installation, then use small, backed-up fragments for custom per-inbound WARP routing. Never edit an opaque merged `config.json` without updating its source fragment.

## Completion criteria

The task is complete only when all requested phases pass configuration validation and the following behavior is demonstrated:

| Path | Expected egress |
|---|---|
| Direct VLESS WS | VPS public IPv4 or IPv6, `warp=off` |
| Direct VMess WS | VPS public IPv4 or IPv6, `warp=off` |
| REALITY | VPS public IP unless separately routed |
| Hysteria2 | VPS public IP unless separately routed |
| WARP VLESS WS | Cloudflare WARP IP, `warp=on` |
| WARP VMess WS | Cloudflare WARP IP, `warp=on` |

If a phase fails, leave the previous phase running, restore only the failed phase from its backup when needed, and report the exact failing layer.
