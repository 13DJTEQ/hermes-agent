#!/usr/bin/env bash
#
# bw-unlock.sh — non-interactive Bitwarden vault unlock for Hermes terminal calls.
# Sets BW_SESSION in the current shell so subsequent `bw` commands work.
#
# Usage:
#   source scripts/bw-unlock.sh && bw get password my-service
#
# Env vars (set in ~/.hermes/.env):
#   BW_CLIENTID     - API key client ID (optional, for `bw login --apikey`)
#   BW_CLIENTSECRET - API key client secret (optional)
#   BW_PASSWORD     - master password (required for `bw unlock`)
#
# macOS fallback: if BW_PASSWORD / BW_CLIENTID / BW_CLIENTSECRET are not set,
# the script attempts to retrieve them from Apple Keychain (service names:
# Bitwarden-Master, Bitworder-ClientID, Bitworder-ClientSecret). See
# references/keychain.md for one-time setup.
#
# NOTE: `bw status --raw` is not recognized in CLI v2026.7.0+; it outputs the
# full JSON status instead of a single word. We pipe through `jq -r '.status'`
# for a portable status string.
#
set -euo pipefail

# --- Helper: get vault status as a bare string --------------------------------
_status() {
  bw status 2>/dev/null | jq -r '.status // empty' 2>/dev/null
}

# --- Re-export BW_SESSION if already present and still valid ----------------
if [ -n "${BW_SESSION:-}" ]; then
  if bw --session "$BW_SESSION" status 2>/dev/null | jq -r '.status // empty' 2>/dev/null | grep -q unlocked; then
    echo "bw-unlock: already unlocked"
    return 0 2>/dev/null || true
  fi
  unset BW_SESSION
fi

# --- Ensure we are logged in ------------------------------------------------
cur_status="$(_status)"
if [ "$cur_status" != "locked" ] && [ "$cur_status" != "unlocked" ]; then
  echo "bw-unlock: not logged in — attempting API-key login"
  # Retrieve API credentials from env, or fall back to macOS Keychain
  if [ -z "${BW_CLIENTID:-}" ] && [ -z "${BW_CLIENTSECRET:-}" ]; then
    if [ "$(uname)" = "Darwin" ] && command -v security >/dev/null 2>&1; then
      BW_CLIENTID=$(security find-generic-password -s "Bitworder-ClientID" -w 2>/dev/null) || true
      BW_CLIENTSECRET=$(security find-generic-password -s "Bitworder-ClientSecret" -w 2>/dev/null) || true
    fi
  fi
  if [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ]; then
    bw login --apikey --nointeraction
  else
    echo "bw-unlock: ERROR — set BW_CLIENTID and BW_CLIENTSECRET in .env (or Keychain on macOS), or log in interactively first"
    return 1 2>/dev/null || exit 1
  fi
fi

# --- Unlock the vault -------------------------------------------------------
# Resolve BW_PASSWORD: check env first, then fall back to macOS Keychain
if [ -z "${BW_PASSWORD:-}" ] && [ "$(uname)" = "Darwin" ] && command -v security >/dev/null 2>&1; then
  BW_PASSWORD=$(security find-generic-password -s "Bitwarden-Master" -w 2>/dev/null) || true
fi
if [ -n "${BW_PASSWORD:-}" ]; then
  # bw unlock --passwordenv expects BW_PASSWORD to be an exported env var
  export BW_PASSWORD
  export BW_SESSION="$(bw unlock --passwordenv BW_PASSWORD --raw)"
else
  echo "bw-unlock: ERROR — BW_PASSWORD not set; store it in .env or retrieve from macOS Keychain (see references/keychain.md)"
  return 1 2>/dev/null || exit 1
fi

# --- Verify -----------------------------------------------------------------
if _status | grep -q unlocked; then
  echo "bw-unlock: vault unlocked"
  return 0 2>/dev/null || true
else
  echo "bw-unlock: ERROR — unlock failed"
  return 1 2>/dev/null || exit 1
fi