# Keychain Integration (macOS)

> **macOS only.** These patterns retrieve the Bitwarden master password from
> Apple Keychain instead of storing `BW_PASSWORD` in a plaintext `.env` file.
> The `apple-keychain` Hermes skill documents the `security` CLI conventions;
> this file is the BitWarden-specific companion.

## Why use Keychain?

Storing `BW_PASSWORD` in `~/.hermes/.env` keeps the master password on disk in
plaintext (the `.env` file is read by the Hermes runtime). For macOS users who
already keep passwords in Apple Keychain, retrieving the credential at runtime
is both safer and integrates with existing MFA / biometric unlock policies.

## Service naming convention

| Keychain service name | What it stores                        |
|---|---|
| `Bitwarden-Master`     | Master password (for `bw unlock`)     |
| `Bitworder-ClientID`   | API key client ID (for `bw login --apikey`) |
| `Bitworder-ClientSecret` | API key client secret               |
| `Bitworder-BW_SESSION`  | Cached session key (optional, see below) |

> **Note:** The entries above are what an existing user may already have stored.
> New setups can use any service name — just keep it consistent across the
> `security` commands and the `bw-unlock.sh` helper script.

## One-time setup

Store the master password (or API credentials) in Keychain:

```bash
# Master password
security add-generic-password -s "Bitwarden-Master" -w "your-master-password" login.keychain-db

# API key (optional, automates bw login)
security add-generic-password -s "Bitworder-ClientID" -w "your-client-id" login.keychain-db
security add-generic-password -s "Bitworder-ClientSecret" -w "your-client-secret" login.keychain-db
```

## Runtime retrieval

Retrieve the master password non-interactively into a shell variable:

```bash
MASTER_PW=$(security find-generic-password -s "Bitwarden-Master" -w)
```

Retrieve the API key credentials for automated login:

```bash
export BW_CLIENTID=$(security find-generic-password -s "Bitworder-ClientID" -w)
export BW_CLIENTSECRET=$(security find-generic-password -s "Bitworder-ClientSecret" -w)
```

## Combined unlock pattern

The `scripts/bw-unlock.sh` helper script already implements this fallback: if
`BW_PASSWORD` is not set in the environment, it attempts to retrieve the master
password from Keychain (macOS only) before erroring.

```bash
# In bw-unlock.sh (simplified)
if [ -z "${BW_PASSWORD:-}" ]; then
  if [ "$(uname)" = "Darwin" ] && command -v security >/dev/null 2>&1; then
    BW_PASSWORD=$(security find-generic-password -s "Bitwarden-Master" -w 2>/dev/null) || true
  fi
fi
```

## Cached session keys

Optionally store the `BW_SESSION` key in Keychain under `Bitworder-BW_SESSION`
to avoid unlocking on every terminal call. The helper script checks whether a
cached session is still valid before falling back to a full unlock.

> **Warning:** session keys are short-lived (typically 30 min). A cached key
> in Keychain may already be expired. Always call `bw status | jq -r '.status'` to verify
> before relying on a cached session.

## Linux / Windows alternative

Keychain retrieval is macOS-specific. On Linux, write the password to a file
with restrictive permissions (`chmod 600`) and use `--passwordfile`:

```bash
bw unlock --passwordfile ~/.bitwarden/master-pw.txt --raw
```

On Windows, store the credential in Credential Manager and retrieve it via
`cmdkey /list` or PowerShell `Get-StoredCredential`.
