#!/usr/bin/env bash
set -euo pipefail

base_dir=${1:-/etc/v2ray-agent}
xray_dir="$base_dir/xray/conf"
sing_conf_dir="$base_dir/sing-box/conf"
sing_dir="$sing_conf_dir/config"
tls_dir="$base_dir/tls"

if [[ ! -d "$sing_dir" ]]; then
  sing_dir="$sing_conf_dir"
fi

printf '%s\n' "== system =="
if [[ -r /etc/os-release ]]; then
  sed -n '1,8p' /etc/os-release
fi
printf 'xray: '; systemctl is-active xray 2>/dev/null || true
printf 'sing-box: '; systemctl is-active sing-box 2>/dev/null || true
printf 'nginx: '; systemctl is-active nginx 2>/dev/null || true
printf '%s\n' "== versions =="
if [[ -x "$base_dir/xray/xray" ]]; then "$base_dir/xray/xray" version 2>/dev/null | head -1; fi
if [[ -x "$base_dir/sing-box/sing-box" ]]; then "$base_dir/sing-box/sing-box" version 2>/dev/null | head -1; fi
printf '%s\n' "== listeners =="
ss -lntup 2>/dev/null | grep -E 'xray|sing-box|:443([[:space:]]|$)|:80([[:space:]]|$)' |
  sed -E 's/users:.*/users:(redacted)/' || true
printf '%s\n' "== resolver/firewall =="
sed -n '1,20p' /etc/resolv.conf 2>/dev/null || true
printf 'firewalld: '; systemctl is-active firewalld 2>/dev/null || true
if command -v firewall-cmd >/dev/null 2>&1; then firewall-cmd --list-all 2>/dev/null || true; fi
printf '%s\n' "== xray inbounds =="
if command -v jq >/dev/null 2>&1 && [[ -d "$xray_dir" ]]; then
  find "$xray_dir" -maxdepth 1 -type f -name '*.json' -print0 |
    while IFS= read -r -d '' file; do
      jq -r --arg file "${file##*/}" '.inbounds[]? | [$file, .tag, .protocol, (.listen // "0.0.0.0"), (.port // ""), (.streamSettings.network // ""), (.streamSettings.security // ""), (.streamSettings.wsSettings.path // .streamSettings.xhttpSettings.path // "")] | @tsv' "$file" 2>/dev/null || true
    done
fi
printf '%s\n' "== xray routes/outbounds =="
if command -v jq >/dev/null 2>&1 && [[ -d "$xray_dir" ]]; then
  find "$xray_dir" -maxdepth 1 -type f -name '*.json' -print0 |
    while IFS= read -r -d '' file; do
      jq -r --arg file "${file##*/}" '.outbounds[]? | [$file, .tag, .protocol, (if .protocol == "wireguard" then (if .settings.noKernelTun == true then "gvisor" else "kernel-or-default" end) else "" end)] | @tsv' "$file" 2>/dev/null || true
      jq -r --arg file "${file##*/}" '.routing.rules[]? | [$file, (.inboundTag // [] | join(",")), (.domain // [] | join(",")), (.outboundTag // "")] | @tsv' "$file" 2>/dev/null || true
    done
fi
printf '%s\n' "== sing-box hysteria2 =="
if command -v jq >/dev/null 2>&1 && [[ -d "$sing_dir" ]]; then
  find "$sing_dir" -maxdepth 2 -type f -name '*.json' -print0 |
    while IFS= read -r -d '' file; do
      jq -r --arg file "${file##*/}" '.inbounds[]? | select(.type == "hysteria2") | [$file, (.listen // ""), (.listen_port // ""), (.tls.server_name // ""), (.tls.certificate_path // "")] | @tsv' "$file" 2>/dev/null || true
    done
fi
printf '%s\n' "== tls SANs =="
for cert in "$tls_dir"/*.crt; do
  [[ -f "$cert" ]] || continue
  printf '%s: ' "${cert##*/}"
  openssl x509 -in "$cert" -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tr '\n' ' '
  printf '\n'
done
printf '%s\n' "== WARP registration =="
if [[ -s "$base_dir/warp/config" ]]; then
  awk '
    tolower($0) ~ /private_key|public_key|license|token|account_id|client_id|device_id|reserved/ {next}
    NF {print}
  ' "$base_dir/warp/config" 2>/dev/null || true
  for field in private_key public_key reserved; do
    if grep -q "^${field}" "$base_dir/warp/config"; then
      printf '%s: present\n' "$field"
    else
      printf '%s: missing\n' "$field"
    fi
  done
else
  printf '%s\n' 'not installed'
fi
