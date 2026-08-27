#!/usr/bin/env bash
set -euo pipefail

base_dir=${1:-/etc/v2ray-agent}
backup_dir=${2:-}
xray_dir="$base_dir/xray/conf"
sing_conf_dir="$base_dir/sing-box/conf"
sing_fragment_dir="$sing_conf_dir/config"
errors=0
warnings=0

if [[ ! -d "$sing_fragment_dir" ]]; then
  sing_fragment_dir="$sing_conf_dir"
fi

fail() {
  printf '%s\n' "$*" >&2
  errors=$((errors + 1))
}

warn() {
  printf 'warning: %s\n' "$*" >&2
  warnings=$((warnings + 1))
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' 'jq is required' >&2
  exit 2
fi

mapfile -d '' xray_files < <(find "$xray_dir" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null || true)
mapfile -d '' sing_files < <(find "$sing_fragment_dir" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null || true)

check_json_files() {
  local file
  for file in "$@"; do
    if ! jq empty "$file" >/dev/null 2>&1; then
      fail "invalid JSON: $file"
    fi
  done
}

check_json_files "${xray_files[@]}"
check_json_files "${sing_files[@]}"

if ((${#xray_files[@]} > 0)); then
  while IFS=$'\t' read -r path port tag; do
    [[ -n "$path" ]] || continue
    if [[ "$path" != /* || "$path" == //* ]]; then
      fail "WS path must have exactly one leading slash: $tag $path"
    fi
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
      fail "WS inbound has invalid port: $tag $port"
    fi
  done < <(jq -r '.inbounds[]? | select(.streamSettings.network? == "ws") | [(.streamSettings.wsSettings.path // ""), (.port // ""), (.tag // "")] | @tsv' "${xray_files[@]}")

  duplicate_paths=$(jq -s -r '[.[] | .inbounds[]? | select(.streamSettings.network? == "ws") | .streamSettings.wsSettings.path] | group_by(.)[] | select(length > 1) | .[0]' "${xray_files[@]}")
  if [[ -n "$duplicate_paths" ]]; then
    fail "duplicate WS path(s): $(printf '%s' "$duplicate_paths" | paste -sd, -)"
  fi

  duplicate_tags=$(jq -s -r '[.[] | .inbounds[]? | .tag // empty] | group_by(.)[] | select(length > 1) | .[0]' "${xray_files[@]}")
  if [[ -n "$duplicate_tags" ]]; then
    fail "duplicate Xray inbound tag(s): $(printf '%s' "$duplicate_tags" | paste -sd, -)"
  fi

  fallback_file="$xray_dir/02_VLESS_TCP_inbounds.json"
  if [[ -f "$fallback_file" ]]; then
    while IFS=$'\t' read -r path dest; do
      [[ -n "$path" ]] || continue
      if ! jq -s -e --arg path "$path" --argjson dest "$dest" \
        '[.[] | .inbounds[]? | select(.streamSettings.wsSettings.path? == $path and .port? == $dest)] | length == 1' \
        "${xray_files[@]}" >/dev/null; then
        fail "fallback has no unique matching WS listener: $path -> $dest"
      fi
    done < <(jq -r '.inbounds[0].settings.fallbacks[]? | select(.path != null) | [.path, .dest] | @tsv' "$fallback_file")

    while IFS=$'\t' read -r path port tag listen; do
      [[ "$listen" == "127.0.0.1" || "$listen" == "::1" ]] || continue
      if ! jq -e --arg path "$path" --argjson port "$port" \
        '.inbounds[0].settings.fallbacks[]? | select(.path == $path and .dest == $port)' \
        "$fallback_file" >/dev/null; then
        fail "loopback WS inbound is absent from 443 fallbacks: $tag $path -> $port"
      fi
    done < <(jq -r '.inbounds[]? | select(.streamSettings.network? == "ws") | [(.streamSettings.wsSettings.path // ""), (.port // ""), (.tag // ""), (.listen // "0.0.0.0")] | @tsv' "${xray_files[@]}")
  fi

  mapfile -t warp_tags < <(jq -s -r '.[] | .outbounds[]? | select(.protocol == "wireguard") | .tag // empty' "${xray_files[@]}" | sort -u)
  for warp_tag in "${warp_tags[@]}"; do
    if ! jq -s -e --arg tag "$warp_tag" \
      '[.[] | .outbounds[]? | select(.tag == $tag and .protocol == "wireguard" and .settings.secretKey and .settings.address[0] and .settings.peers[0].publicKey and .settings.peers[0].endpoint)] | length == 1' \
      "${xray_files[@]}" >/dev/null; then
      fail "WireGuard WARP outbound is incomplete or duplicated: $warp_tag"
    fi
    if ! jq -s -e --arg tag "$warp_tag" \
      '[.[] | .outbounds[]? | select(.tag == $tag) | .settings.noKernelTun == true] | any' \
      "${xray_files[@]}" >/dev/null; then
      fail "WARP outbound does not force Xray gVisor TUN with noKernelTun=true: $warp_tag"
    fi

    mapfile -t routed_inbounds < <(jq -s -r --arg tag "$warp_tag" '.[] | .routing.rules[]? | select(.outboundTag == $tag) | .inboundTag[]?' "${xray_files[@]}" | sort -u)
    if ((${#routed_inbounds[@]} == 0)); then
      fail "WARP outbound has no inbound-tag route: $warp_tag"
      continue
    fi
    if jq -s -e --arg tag "$warp_tag" \
      '.[] | .routing.rules[]? | select(.outboundTag == $tag and ((.inboundTag // []) | length == 0))' \
      "${xray_files[@]}" >/dev/null; then
      fail "WARP route is global/domain-based instead of scoped to cloned inbounds: $warp_tag"
    fi
    for inbound_tag in "${routed_inbounds[@]}"; do
      if ! jq -s -e --arg tag "$inbound_tag" '[.[] | .inbounds[]? | select(.tag == $tag)] | length == 1' "${xray_files[@]}" >/dev/null; then
        fail "WARP route references a missing or duplicated inbound tag: $inbound_tag"
      fi
      if [[ "$inbound_tag" == "VLESSWS" || "$inbound_tag" == "VMessWS" ]]; then
        fail "baseline direct inbound is routed to WARP: $inbound_tag"
      fi
    done
  done

  if [[ -x "$base_dir/xray/xray" ]] && ! "$base_dir/xray/xray" run -test -confdir "$xray_dir" >/dev/null 2>&1; then
    fail 'Xray confdir check failed'
  fi
fi

if [[ -n "$backup_dir" ]]; then
  backup_xray="$backup_dir/xray/conf"
  for baseline in 03_VLESS_WS_inbounds.json 05_VMess_WS_inbounds.json; do
    if [[ -f "$backup_xray/$baseline" && -f "$xray_dir/$baseline" ]] && ! cmp -s "$backup_xray/$baseline" "$xray_dir/$baseline"; then
      fail "baseline fragment changed since backup: $baseline"
    fi
  done
fi

if ((${#sing_files[@]} > 0)); then
  while IFS=$'\t' read -r hostname cert key; do
    [[ -n "$hostname" ]] || continue
    [[ -f "$cert" ]] || fail "Hysteria2 certificate file is missing: $cert"
    [[ -f "$key" ]] || fail "Hysteria2 key file is missing: $key"
    if [[ -f "$cert" ]] && command -v openssl >/dev/null 2>&1 && ! openssl x509 -in "$cert" -noout -checkhost "$hostname" >/dev/null 2>&1; then
      fail "Hysteria2 certificate does not cover SNI: $hostname"
    fi
  done < <(jq -r '.inbounds[]? | select(.type == "hysteria2") | [(.tls.server_name // ""), (.tls.certificate_path // ""), (.tls.key_path // "")] | @tsv' "${sing_files[@]}")

  if grep -Eq '(^|[[:space:]])(100\.100\.100\.100|fd7a:115c:a1e0::53)([[:space:]]|$)' /etc/resolv.conf 2>/dev/null; then
    if ! jq -s -e '[.[] | .dns.servers[]?] | length > 0' "${sing_files[@]}" >/dev/null ||
       ! jq -s -e '[.[] | .route.default_domain_resolver? // empty] | length > 0' "${sing_files[@]}" >/dev/null; then
      warn 'Tailscale DNS is active but sing-box has no explicit DNS/default_domain_resolver'
    fi
  fi

  if [[ -x "$base_dir/sing-box/sing-box" ]] && ! "$base_dir/sing-box/sing-box" check -C "$sing_fragment_dir" -D "$sing_conf_dir" >/dev/null 2>&1; then
    fail 'sing-box fragment-directory check failed'
  fi
fi

if [[ "$errors" -ne 0 ]]; then
  printf 'validation failed: %s issue(s), %s warning(s)\n' "$errors" "$warnings" >&2
  exit 1
fi
printf 'layout validation passed: %s warning(s)\n' "$warnings"
