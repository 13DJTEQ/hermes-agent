# BitWarden CLI — Authentication & Session Flow

## Overview

The `bw` CLI has two phases:

1. **Login** (`bw login`) — authenticates your identity with the Bitwarden
   server. After login, your vault data is downloaded but still encrypted
   (vault state = "locked").

2. **Unlock** (`bw unlock`) — decrypts your vault locally using your master
   password. Returns a **session key** that must be passed to all subsequent
   vault-data commands (via `BW_SESSION` env var or `--session` flag).

> **Standard:** the master password comes from Apple Keychain (service
> `Bitworden-Master`) via `bw-unlock.sh` — never `.env`. See
> [keychain](keychain.md).

The session key is ephemeral — it lives only in the current process/shell.
When the session ends, the vault is still "locked" and you must unlock again.

## The `bw status` output

```json
{
  "serverUrl": null,
  "lastSync": "2026-10-11T23:01:22.904Z",
  "userEmail": "user@example.com",
  "userId": "00000000-0000-0000-0000-000000000000",
  "status": "unlocked"
}
```

`status` can be:
- `unauthenticated` — not logged in
- `locked` — logged in, vault encrypted locally
- `unlocked` — logged in, vault decrypted (BW_SESSION active)

## Login methods

### 1. Email + master password (interactive)

```bash
bw login
# prompts for email, password, and 2FA if enabled
```

With inline 2FA:

```bash
bw login john@example.com "myPassword123" --method 0 --code 249213
```

`<method>` values: `0` = Authenticator, `1` = Email, `3` = YubiKey.

### 2. API key (recommended for automation)

Generate a personal API key from the web vault:
**Settings → Security → Keys → View API Key**.

```bash
export BW_CLIENTID="user.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export BW_CLIENTSECRET="your_client_secret"
bw login --apikey --nointeraction
```

### 3. SSO

```bash
bw login --sso
# opens browser for SSO authentication
# then: bw unlock
```

## Unlock (generate session key)

### Standard (macOS) — master password from Apple Keychain

**BW Master Pass comes from Apple Keychain — this is the standing standard
for the BW integration.** The helper script resolves it on every unlock;
no `.env` entry and no password file is involved:

```bash
source scripts/bw-unlock.sh          # env -> Keychain(Bitwarden-Master) -> error
```

Under the hood:

```bash
export BW_PASSWORD="$(security find-generic-password -s "Bitwarden-Master" -w)"
export BW_SESSION="$(bw unlock --passwordenv BW_PASSWORD --raw)"
```

### Interactive

```bash
bw unlock
# prompts for master password
```

### Non-interactive fallback (no Keychain — Linux/Windows)

```bash
# Via env var (last resort — never use on macOS, where Keychain is standard)
bw unlock --passwordenv BW_PASSWORD --raw

# Via password file (protect the file! chmod 600)
bw unlock --passwordfile ~/.bitwarden/mp.txt --raw
```

## Session key lifecycle

| Action | Effect |
|---|---|
| `bw unlock` | Generates new session key; invalidates any previous key |
| `bw lock` | Destroys session key; vault returns to "locked" |
| `bw logout` | Destroys session key + clears all local vault data |
| Close terminal | Session key is lost (but vault stays "locked", not "unauthenticated") |

## Env vars reference

| Variable | Purpose | Required for |
|---|---|---|
| `BW_SESSION` | Active session key | All vault-data commands (`get`, `list`, `create`, ...) |
| `BW_CLIENTID` | API key client ID | `bw login --apikey` (resolved from Keychain `Bitworder-ClientID` by the helper) |
| `BW_CLIENTSECRET` | API key client secret | `bw login --apikey` (resolved from Keychain `Bitworder-ClientSecret` by the helper) |
| `BW_PASSWORD` | Master password | `bw unlock --passwordenv` — **fallback only on macOS**; the standard is Keychain `Bitworden-Master` |
| `BITWARDENCLI_APPDATA_DIR` | Alternate config dir | Multi-account login |
| `BITWARDEN_DESKTOP_PROXY_PATH` | Custom desktop app path | Biometric unlock via desktop app |
| `BITWARDENCLI_DEBUG` | Enable debug output | Troubleshooting |
| `BW_NOINTERACTION` | Skip interactive prompts | Automation (set to `true`) |

## Hermes pattern

In Hermes' `terminal` tool, each call starts a fresh shell — `BW_SESSION`
from a previous call is lost. **The standard pattern is the helper script** —
it resolves the master password from Apple Keychain (`Bitwarden-Master`), so
no `.env` entry is needed:

```bash
source skills/security/bitwarden/scripts/bw-unlock.sh && bw get password github
```

The helper script (`bw-unlock.sh`) checks if an existing session is still
valid, logs in if needed (API key from Keychain), unlocks with the master
password from Keychain, and sets `BW_SESSION` — all in one `source` call.

**Fallback one-liner** (no Keychain — Linux/Windows only):

```bash
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw) && bw get password github
```
