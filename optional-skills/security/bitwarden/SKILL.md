---
name: bitwarden
description: Manage passwords, TOTPs, and secrets via the bw CLI.
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
prerequisites:
  commands: [bw]
metadata:
  hermes:
    tags: [bitwarden, security, passwords, secrets, vault, totp, cli]
    category: security
    related_skills: [1password]
    homepage: https://bitwarden.com/help/cli/
---

# Bitwarden CLI Skill

The `bw` CLI is Bitwarden's official command-line client — a full vault
manager that covers logins, TOTP, secure notes, Send, password generation,
and export. This skill wraps the most common Hermes workflows: unlock the
vault in a non-interactive terminal, read secrets at runtime, generate
passwords, create items, and share ephemeral secrets.

It does **not** manage the Bitwarden desktop app, browser extension, or web
vault. Authentication (login) requires your Bitwarden account; see
`references/auth-flow.md` for the three login methods.

## When to Use

- Need a password or TOTP from your vault during an automated task
- Generating a strong password or passphrase for a new account
- Creating, editing, or searching vault items programmatically
- Sharing a secret ephemerally via Bitwarden Send
- Exporting a vault backup or importing from another format

## Prerequisites

- BitWarden CLI (`bw`) installed — see [get-started](references/get-started.md)
- A BitWarden account, logged in via `bw login` (email, API key, or SSO)
- For non-interactive unlock: either `BW_PASSWORD` set in
  `${HERMES_HOME:-~/.hermes}/.env` (master password) **or**, on macOS,
  the master password stored in Apple Keychain (service name
  `Bitwarden-Master`). See [keychain](references/keychain.md).

## How to Run

All commands go through the `terminal` tool. The critical invariant is
**session management** — vault-data commands require `BW_SESSION` to be set
in the terminal environment. See `references/auth-flow.md` for the complete
unlock → session → lock lifecycle.

```bash
# 1. Check status
bw status | jq -r '.status'

# 2. Unlock (non-interactive via password env var)
terminal(command="export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)")

# 3. Now vault-data commands work
terminal(command="bw get password github")

# 4. Lock when done
terminal(command="bw lock")
```

For repeated interactive sessions, use the helper script:

```bash
terminal(command="source skills/security/bitwarden/scripts/bw-unlock.sh && bw get password github")
```

## Quick Reference

```bash
# Status / session
bw status                        # JSON: server, lastSync, status
bw unlock --raw                  # print session key (pipe to export)
bw unlock --passwordenv BW_PASSWORD --raw   # non-interactive unlock
bw lock                          # invalidate session, clear BW_SESSION

# Read secrets (require unlocked session)
bw get password <search-or-id>       # raw password only
bw get totp <search-or-id>           # current TOTP code
bw get username <search-or-id>
bw get item <search-or-id> | jq .    # full item as JSON
bw get notes <search-or-id>          # secure note text
bw list items --search <term> | jq -r '.[].name'
bw list items --url <domain> --search <term>

# Generate
bw generate -ulns --length 20        # 20-char password
bw generate -p --words 4 --separator space  # 4-word passphrase

# Create / edit (save template to file first — never nest jq inside jq)
bw get template item > /tmp/bw-item.json
jq --arg pw "$(bw generate -ulns --length 24)" \
   '.name = "My Service" | .login.username = "alice" | .login.password = $pw | .login.uris = [{"uri": "https://my.service.com", "match": 3}]' \
   /tmp/bw-item.json | bw encode | bw create item
bw get item <id> | jq --arg pw "$(bw generate -ulns --length 24)" '.login.password = $pw' | bw encode | bw edit item <id>

# Send / receive
bw send -n "api-key" -d 1 --hidden "s3cr3t" --maxAccessCount 1
bw send list                          # list Sends (NOT `bw list send`)
bw send template text                 # Send JSON template (text or file)
bw send delete <send-id>
bw receive --password env123 <send-url>

# Export / import / sync (json/csv exports are PLAINTEXT — treat the output file as a secret)
bw export --format json --output ~/backup-vault.json
bw import --formats                   # list supported import formats
bw sync
```

## Procedure

### Unlock the vault for the session

1. Run `bw status | jq -r '.status'` — if output is `unlocked`, skip to step 3. If
   `locked`, proceed. If `unauthenticated`, run `bw login` first (see
   `references/auth-flow.md`).
2. Unlock and capture the session key:
   ```bash
   export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
   ```
   If `BW_PASSWORD` is not set, omit `--passwordenv` to be prompted
   interactively. The helper script `scripts/bw-unlock.sh` wraps this for
   repeated `terminal` calls.
3. Verify the session is active:
   ```bash
   bw status | jq -r '.status'   # should print "unlocked"
   ```

### Retrieve a secret at runtime

1. Identify the item — use `bw get item <name>` or `bw list items --search <name>`
   if you don't know the exact name.
2. Fetch the specific field:
   ```bash
   bw get password github        # just the password
   bw get totp github            # current TOTP code (6-8 digits)
   bw get username github
   ```
3. Pipe directly into another tool (e.g., set an env var for a script):
   ```bash
   export GITHUB_TOKEN=$(bw get password gh-cli-token)
   ```

### Create a login item

**Reliable pattern** — save the template to a file, then jq the file.
Nested `jq` inside `jq` (command substitution inside a jq program) fails with
a syntax error — never chain them.

1. Get the item template:
   ```bash
   bw get template item > /tmp/bw-item.json
   ```
2. Modify with `jq` — set name, username, password (optionally via
   `bw generate`), and **`uris` as an array** (a `.login.uri` string is
   silently dropped by the server):
   ```bash
   jq --arg pw "$(bw generate -ulns --length 24)" \
      '.name = "My Service"
       | .login.username = "alice"
       | .login.password = $pw
       | .login.uris = [{"uri": "https://my.service.com", "match": 3}]' \
      /tmp/bw-item.json | bw encode | bw create item
   ```
   `match` values: 0=Domain, 1=Host, 2=StartsWith, 3=Exact, 4=Regex, 5=None.
3. Create the item (already piped above). Verify with:
   ```bash
   bw get item <name> | jq '{name, username: .login.username, uris: .login.uris}'
   ```

### Generate a password without storing it

```bash
bw generate -ulns --length 20
```
This outputs a password to stdout without creating a vault item. Use it when
setting up accounts in other systems and you'll add the item to Bitwarden
afterwards.

## Pitfalls

- **Non-interactive terminals**: `bw unlock` and `bw login` without
  `--passwordenv` / `--passwordfile` will prompt and hang in Hermes'
  non-interactive `terminal` calls. Always use `--passwordenv` or the
  helper script `scripts/bw-unlock.sh`.
- **macOS Keychain fallback**: the helper script automatically retrieves
  `BW_PASSWORD` from Keychain (service `Bitwarden-Master`) when the env
  var is unset. This is macOS-only; on Linux/Windows, set `BW_PASSWORD`
  or use `--passwordfile` with a `chmod 600` file. See
  [keychain](references/keychain.md).
- **Session keys don't persist across terminal calls** unless you `export
  BW_SESSION=...` in the same `terminal` invocation. Each new `terminal`
  call starts a fresh shell — use `source scripts/bw-unlock.sh && <command>`
  to chain unlock + operation.
- **`bw get` returns only one result** — if multiple items match the search
  string, it errors. Use `bw list items --search <term> | jq` to find the
  exact `id`, then `bw get item <id>`.
- **`.login.uri` string is silently dropped** on create — the server expects
  `.login.uris` as an array of `{"uri": ..., "match": N}` objects. A
  `.login.uri = "https://..."` assignment creates an item with no URI at all
  (verified: `bw get uri` returns "Not found").
- **Never nest `jq` inside `jq`** — command substitution like
  `jq '... | .login = ($(bw get template item.login | jq "...") ...)'` fails
  with a jq syntax error and can crash the CLI with EPIPE. Save the template
  to a file first (`bw get template item > /tmp/tpl.json`), then jq the file.
- **`bw list send` is invalid** — `list` only accepts items, folders,
  collections, org-collections, org-members, organizations. Use
  `bw send list` (the subcommand) instead.
- **`bw report` does not exist** in CLI v2026.7.0 — use
  `bw export --format json` + `jq` for password-strength analysis.
- **Plaintext exports** — `bw export --format json` and `--format csv`
  produce **unencrypted** files (`"encrypted": false` in the JSON header).
  Only `--format encrypted_json` is password-protected. Treat any export
  file as a plaintext secret (chmod 600, delete after use).
- **Passwords are not logged**: the CLI never echoes passwords in JSON output
  unless you explicitly request them, so `bw get password` is safe to pipe but
  `bw get item` will include the password in the full JSON.
- **Homebrew on Linux**: the `bitwarden-cli` Homebrew formula ships without
  device-approval subcommands (Enterprise SSO). Use the native binary from
  [bitwarden.com/download](https://bitwarden.com/download/) for full
  feature coverage.

## References

- [Get started](references/get-started.md) — install, login, and first unlock
- [Auth flow](references/auth-flow.md) — login methods, session lifecycle, env vars
- [CLI commands](references/cli-commands.md) — full command and option reference
- [Keychain integration](references/keychain.md) — macOS Apple Keychain credential retrieval (Bitwarden-Master service)

## Verification

```bash
# 1. CLI is installed and reports version
bw --version

# 2. Auth status
bw status | jq -r '.status'   # "unauthenticated" | "locked" | "unlocked"

# 3. After unlock, session key is set
bw --session "$BW_SESSION" status | jq -r '.status'  # "unlocked"

# 4. Read a known item
bw get item <name> | jq '.name'   # echo back the item name
```
