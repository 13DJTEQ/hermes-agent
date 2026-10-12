# BitWarden CLI — Command & Option Reference

> Extracted from `bw --help`, `bw <command> --help`, and the official docs
> (https://bitwarden.com/help/cli/). Version: 2026.7.0.

## Global options

| Option | Description |
|---|---|
| `--pretty` | Format output as indented JSON (2-space) |
| `--raw` | Return raw output instead of a descriptive message |
| `--response` | Return JSON formatted version of response output |
| `--quiet` | Suppress stdout |
| `--nointeraction` | Do not prompt for interactive user input |
| `--session <key>` | Pass session key instead of reading `BW_SESSION` env var |
| `-v, --version` | Print version |
| `-h, --help` | Help for command |

## Authentication

### `bw login [options] [email] [password]`

Log into a user account.

**Options:**
- `--method <n>` — 2FA method: `0` (Authenticator), `1` (Email), `3` (YubiKey)
- `--code <code>` — 2FA code
- `--sso [identifier]` — SSO login (opens browser; optional org identifier)
- `--apikey` — login with API key (reads `BW_CLIENTID` / `BW_CLIENTSECRET`)
- `--passwordenv <var>` — read password from env var
- `--passwordfile <path>` — read password from file (first line)
- `--check` — check login status without logging in (prints "You are logged in!")

```bash
bw login
bw login john@example.com "myPassword123" --raw
bw login --apikey --nointeraction
bw login --check
```

### `bw logout`

Clears all local vault data and session information.

### `bw unlock [password]`

Unlock the vault and return a new session key.

**Options:**
- `--passwordenv <var>` — read password from env var
- `--passwordfile <path>` — read password from file (first line)
- `--check` — check lock status without unlocking (prints "Vault is locked." /
  "Vault is unlocked!")

```bash
bw unlock
bw unlock --passwordenv BW_PASSWORD --raw
bw unlock --check
export BW_SESSION=$(bw unlock --raw)
```

### `bw lock`

Lock the vault and destroy active session keys.

### `bw status`

Show server URL, last sync, user email/ID, and vault status as JSON.

```bash
bw status
bw status | jq -r '.status'  # prints just the status string: unauthenticated | locked | unlocked
```

## Vault synchronization

### `bw sync`

Pull the latest vault data from the server.

**Options:**
- `-f, --force` — force a full sync (not incremental)
- `--last` — return only the timestamp of the last sync

```bash
bw sync
bw sync -f
bw sync --last
```

## Vault operations

### `bw list <object>`

List an array of objects from the vault.

**object:** `items`, `folders`, `collections`, `org-collections`,
`org-members`, `organizations`

**Options:**
- `--search <term>` — search filter (AND with other filters)
- `--url <url>` — filter login items by URL (URL-match search)
- `--folderid <id>` — filter by folder ID (null = items without folder)
- `--collectionid <id>` — filter by collection ID
- `--organizationid <id>` — filter by organization ID (notnull = any org)
- `--trash` — show only items in trash
- `--archived` — show only archived items

```bash
bw list items --search github
bw list items --url https://google.com
bw list items --folderid null --collectionid null
bw list items --organizationid notnull
```

### `bw get <object> <id>`

Get a single object from the vault.

**object:** `item`, `username`, `password`, `uri`, `totp`, `notes`,
`exposed`, `attachment`, `folder`, `collection`, `org-collection`,
`organization`, `template`, `fingerprint`, `send`

**Options:**
- `--itemid <id>` — item ID for attachment operations
- `--output <path>` — output directory or filename for attachments
- `--organizationid <id>` — organization ID for org objects
- `--raw` — for attachments, write to stdout instead of file

```bash
bw get password github              # raw password
bw get totp github                  # current TOTP code
bw get username github
bw get item 99ee88d2-6046-4ea7-92c2-acac464b1412 | jq .
bw get notes google.com
bw get exposed yahoo.com            # breach check
bw get attachment photo.jpg --itemid <id> --output ./photo.jpg
bw get template folder              # JSON template for create/edit
```

### `bw create <object> [encodedJson]`

Create an object in the vault.

**object:** `item`, `folder`, `org-collection`

For `attachment`, use `--file <path> --itemid <id>` instead.

```bash
echo '{"name":"My Folder"}' | bw encode | bw create folder
bw create folder eyJuYW...In0K
```

### `bw edit <object> <id> [encodedJson]`

Edit an object in the vault.

**object:** `item`, `item-collections`, `folder`, `org-collection`

```bash
bw get item <id> | jq '.login.password="newpass"' | bw encode | bw edit item <id>
```

### `bw delete <object> <id>`

Delete an object from the vault (soft-delete to trash by default).

**Options:**
- `-p, --permanent` — permanently delete (irreversible)
- `--organizationid <id>` — for org objects

```bash
bw delete item <id>
bw delete item <id> --permanent
```

### `bw restore <object> <id>`

Restore an item from the trash.

### `bw archive <object> <id>`

Archive an object from the vault.

### `bw move <id> <organizationId> [encodedJson]`

Move an item to an organization.

### `bw confirm <object> <id>`

Confirm an invited organization member.

**Options:** `--organizationid <id>`

## Utility commands

### `bw config <setting> [value]`

Configure CLI settings.

```bash
bw config server https://vault.bitwarden.eu     # EU cloud
bw config server https://your.bw.domain.com      # self-hosted
bw config server --web-vault <url> --api <url> --identity <url>  # individual services
```

### `bw encode`

Base64-encode stdin. Used to create the `encodedJson` argument for
`create` and `edit`.

```bash
echo '{"name":"test"}' | bw encode
```

### `bw generate [options]`

Generate a password or passphrase.

**Options:**
- `-u, --uppercase` — include uppercase
- `-l, --lowercase` — include lowercase
- `-n, --number` — include numbers
- `-s, --special` — include special characters
- `-p, --passphrase` — generate a passphrase
- `--length <n>` — password length (min 5, default 14)
- `--words <n>` — number of words (min 3, default 3)
- `--minNumber <n>` — minimum numeric characters
- `--minSpecial <n>` — minimum special characters
- `--separator <sep>` — word separator (use `empty` for none)
- `-c, --capitalize` — title-case passphrase
- `--includeNumber` — include a number in passphrase
- `--ambiguous` — avoid ambiguous characters

```bash
bw generate                           # -uln --length 14
bw generate -ulns --length 24
bw generate -p --words 5 --separator " "
bw generate -p -c --words 4
```

## Removed in v2026.7.0 — commands that DO NOT exist

| Command | Status |
|---|---|
| `bw report password-health` | **Not in v2026.7.0.** Use `bw export --format json` + jq for password-strength analysis. |
| `bw device-approval` | **Not in v2026.7.0.** Enterprise SSO device approval is only in the desktop/browser clients. |
| `bw list send` | **Invalid object.** `list` accepts only: items, folders, collections, org-collections, org-members, organizations. Use `bw send list`. |

### `bw export [options]`

Export vault data as CSV, JSON, encrypted_json, or ZIP.

**Options:**
- `--format <csv|json|encrypted_json|zip>` — output format
- `--output <path>` — output file/directory
- `--password [pwd]` — encrypt `encrypted_json` exports with a custom password
  (instead of your account encryption key; **only applies to `encrypted_json`**)
- `--organizationid <id>` — export an org vault

> **WARNING — plaintext exports:** `--format json` and `--format csv` write
> **unencrypted** files. The JSON export header contains `"encrypted": false`.
> Only `encrypted_json` (and zip, which wraps it) is password-protected.
> Treat any export file as a plaintext secret: `chmod 600`, delete after use.

```bash
bw export --format json --output ~/backup.json          # PLAINTEXT
bw export --format csv --output ~/backup.csv            # PLAINTEXT
bw export --format encrypted_json --password "pw" --output ~/backup.json  # encrypted
```

### `bw import <format> <path>`

Import data from a file.

```bash
bw import lastpasscsv ./data.csv
bw import --formats   # list supported formats
```

### `bw update`

Check for CLI updates (does not auto-update).

### `bw completion [options]`

Generate shell completions.

```bash
bw completion --shell zsh | sudo tee /usr/share/zsh/vendor-completions/_bw
```

### `bw serve [options]`

Start a local REST API server wrapping all CLI commands.

**Options:**
- `--port <port>` — port (default 8087)
- `--hostname <host>` — bind address (default `localhost`; `all` = no bind)
- `--disable-origin-protection` — allow cross-origin requests (not recommended)

```bash
bw serve --port 8087
```

## Send / Receive

### `bw send [options] <data>`

Create a Bitwarden Send (ephemeral secret sharing).

**Options:**
- `-f, --file` — treat `<data>` as a filepath
- `-d, --deleteInDays <n>` — auto-delete after N days (default 7)
- `--password <pwd>` — access password
- `--emails <emails>` — allowed email addresses
- `-a, --maxAccessCount <n>` — max number of accesses
- `--hidden` — hide content in web UI
- `-n, --name <name>` — Send name
- `--notes <notes>` — notes
- `--fullObject` — return full Send object

```bash
bw send -n "api-key" -d 1 --hidden "s3cr3t" --maxAccessCount 1
bw send -f ./file.ext -d 14 --password "accesscode"
echo "text to send" | bw send -n "meeting-notes"
```

**Subcommands** (use these instead of `bw list send`):

| Subcommand | Purpose |
|---|---|
| `bw send list` | List all your Sends |
| `bw send template <text\|file>` | JSON template for the Send create/edit flow |
| `bw send get <id>` | Get a Send by ID |
| `bw send create <encodedJson>` | Create a Send from a template |
| `bw send edit <id> <encodedJson>` | Edit a Send |
| `bw send delete <id>` | Delete a Send |
| `bw send remove-password <id>` | Remove the access password from a Send |
| `bw receive <url>` | Access a Send (also available as a `bw send` subcommand) |

> **`bw send create` requires a valid `deletionDate`** — set
> `.deletionDate` to a future ISO-8601 timestamp in the template, or use the
> quick flag form (`-d <days>`) which computes it for you. `null` fails with
> "Must specify a valid deletion date after the current time".

### `bw receive [options] <url>`

Access a Bitwarden Send.

```bash
bw receive --password env123 "https://vault.bitwarden.com/#/send/..."
```

## Item types

| Name | Value (for `.type` in item JSON) |
|---|---|
| Login | 1 |
| Secure Note | 2 |
| Card | 3 |
| Identity | 4 |
| SSH Key | 5 |

## Secure note types

| Name | Value (for `.secureNote.type`) |
|---|---|
| Generic | 0 |
| FIPS | 1 |
| GPG | 2 |
| Pre-shared Key | 3 |
| Recovery Code | 4 |
| Webhook | 5 |
|| Other | 6 |

## URI match types

Used in item JSON `.login.uris[].match` when creating/editing login items.

| Name | Value |
|---|---|
| Domain | 0 |
| Host | 1 |
| StartsWith | 2 |
| Exact | 3 |
| Regex | 4 |
| None | 5 |

## 2FA method values

Used with `bw login --method <n>` for inline 2FA code submission.

| Method | Value |
|---|---|
| Authenticator (TOTP) | 0 |
| Email (Yubico) | 1 |
| YubiKey | 3 |

## Login item field reference

Commonly used fields in `item.login` JSON when constructing items via
`jq` + `bw encode` pipelines:

| Field | Type |
|---|---|
| `login.uris` | array of `{uri: string, match: int}` — **NOT a string**; `.login.uri` is silently dropped |
| `login.username` | string |
| `login.password` | string |
| `login.totp` | TOTP secret string (seed, not code) |
| `login.fido2Credentials` | array (populated by passkey registrations; do not set manually) |
| `login.passwordHistory` | array of `{value, lastUsed}` |
| `favorite` | boolean (top-level, not under `login`) |
| `reprompt` | int (top-level; 0 = no reprompt, 1 = reprompt before reveal) |
| `fields` | array of `{name, value, type}` (top-level; type 0=Text, 1=Hidden, 2=Boolean) |
| `type` | int (top-level; 1=Login, 2=SecureNote, 3=Card, 4=Identity, 5=SSHKey) |

## Export formats

| Format | Description |
|---|---|
| `csv` | Comma-separated values — **PLAINTEXT** |
| `json` | Plaintext JSON (`"encrypted": false` in header) — **PLAINTEXT** |
| `encrypted_json` | Password-protected export (use `--password`) |
| `zip` | Wraps encrypted_json + attachments |

See `bw export --formats` for the authoritative list (varies by vault type).
