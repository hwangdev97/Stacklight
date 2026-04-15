#!/usr/bin/env bash
# validate.sh — verify a StackLight provider's credentials are live.
# Usage:  validate.sh <provider-key> <config.json>
#
# config.json is expected to contain { "<field-key>": "<value>", ... } for the
# provider being tested — typically a slice of .stacklight-config.json.
# Exits 0 on success, non-zero with a one-line error on failure.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: validate.sh <provider-key> <config.json>" >&2
  exit 2
fi

provider="$1"
config="$2"

if ! command -v jq >/dev/null; then
  echo "jq is required (brew install jq)" >&2
  exit 2
fi
if ! command -v curl >/dev/null; then
  echo "curl is required" >&2
  exit 2
fi
if [[ ! -f "$config" ]]; then
  echo "config file not found: $config" >&2
  exit 2
fi

get() { jq -r --arg k "$1" '.[$k] // ""' "$config"; }

# Returns HTTP status code; prints body to stderr on non-2xx.
http_check() {
  local url="$1" auth="$2" method="${3:-GET}" body="${4:-}"
  local tmp status
  tmp="$(mktemp)"
  if [[ -n "$body" ]]; then
    status=$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" \
      -H "Authorization: $auth" -H "Content-Type: application/json" \
      --data "$body" "$url") || true
  else
    status=$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" \
      -H "Authorization: $auth" "$url") || true
  fi
  if [[ "$status" =~ ^2 ]]; then
    rm -f "$tmp"
    return 0
  fi
  echo "HTTP $status from $url:" >&2
  head -c 400 "$tmp" >&2 || true
  echo >&2
  rm -f "$tmp"
  return 1
}

case "$provider" in
  vercel)
    token=$(get "vercel.token")
    [[ -z "$token" ]] && { echo "missing vercel.token" >&2; exit 1; }
    http_check "https://api.vercel.com/v2/user" "Bearer $token"
    ;;

  cloudflare)
    token=$(get "cloudflare.token")
    account=$(get "cloudflare.accountId")
    [[ -z "$token" || -z "$account" ]] && { echo "missing cloudflare.token or cloudflare.accountId" >&2; exit 1; }
    http_check "https://api.cloudflare.com/client/v4/accounts/$account/pages/projects" "Bearer $token"
    ;;

  githubActions|githubPR)
    token=$(get "github.token")
    [[ -z "$token" ]] && { echo "missing github.token" >&2; exit 1; }
    http_check "https://api.github.com/user" "Bearer $token"
    # Also verify each repo is reachable
    if [[ "$provider" == "githubActions" ]]; then
      repos=$(get "github.repos")
    else
      repos=$(jq -r '."github.pr.repos" | if type=="array" then join(",") else . end' "$config")
    fi
    IFS=',' read -ra list <<<"$repos"
    for r in "${list[@]}"; do
      r="$(echo "$r" | xargs)"  # trim
      [[ -z "$r" ]] && continue
      http_check "https://api.github.com/repos/$r" "Bearer $token" || {
        echo "repo not reachable: $r" >&2; exit 1;
      }
    done
    ;;

  netlify)
    token=$(get "netlify.token")
    [[ -z "$token" ]] && { echo "missing netlify.token" >&2; exit 1; }
    http_check "https://api.netlify.com/api/v1/sites?per_page=1" "Bearer $token"
    ;;

  railway)
    token=$(get "railway.token")
    [[ -z "$token" ]] && { echo "missing railway.token" >&2; exit 1; }
    http_check "https://backboard.railway.app/graphql/v2" "Bearer $token" \
      POST '{"query":"{ me { id } }"}'
    ;;

  flyio)
    token=$(get "flyio.token")
    [[ -z "$token" ]] && { echo "missing flyio.token" >&2; exit 1; }
    http_check "https://api.machines.dev/v1/apps" "Bearer $token"
    ;;

  xcodeCloud|testFlight)
    # App Store Connect requires a signed JWT that this shell script cannot
    # easily produce. Verify only that the fields are present and well-shaped.
    issuer=$(get "asc.issuerID")
    keyID=$(get "asc.privateKeyID")
    key=$(get "asc.privateKey")
    [[ -z "$issuer" || -z "$keyID" || -z "$key" ]] && {
      echo "missing one of asc.issuerID / asc.privateKeyID / asc.privateKey" >&2; exit 1;
    }
    [[ ${#issuer} -ne 36 ]] && {
      echo "asc.issuerID should be a 36-char UUID (got ${#issuer})" >&2; exit 1;
    }
    [[ "$key" != *"PRIVATE KEY"* && ${#key} -lt 200 ]] && {
      echo "asc.privateKey looks too short — paste the full .p8 file contents" >&2; exit 1;
    }
    if [[ "$provider" == "testFlight" ]]; then
      appId=$(get "testflight.appId")
      [[ -z "$appId" ]] && { echo "missing testflight.appId" >&2; exit 1; }
      [[ ! "$appId" =~ ^[0-9]+$ ]] && { echo "testflight.appId must be numeric" >&2; exit 1; }
    fi
    echo "shape check passed (live JWT test requires the StackLight app itself)" >&2
    ;;

  *)
    echo "unknown provider: $provider" >&2
    exit 2
    ;;
esac

echo "ok: $provider"
