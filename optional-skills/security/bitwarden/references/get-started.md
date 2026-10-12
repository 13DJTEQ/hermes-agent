# BitWarden CLI — Get Started

## Install the `bw` CLI

| Platform | Command |
|---|---|
| macOS (Homebrew) | `brew install bitwarden-cli` |
| Linux (Snap) | `sudo snap install bw` |
| Linux (native binary) | `curl -Lso bw.zip "https://bitwarden.com/download/?app=cli&platform=linux" && unzip bw-linux.zip && sudo install -m 755 bw /usr/local/bin/bw` |
| Linux (npm) | `npm install -g @bitwarden/cli` |
| Windows (winget) | `winget install -e --id Bitwarden.CLI` |
| Windows (Chocolatey) | `choco install bitwarden-cli` |

Verify:

```bash
bw --version
```

## Log in

Three methods — see [auth-flow.md](auth-flow.md) for full details.

**Email + password (interactive):**

```bash
bw login
```

**API key (recommended for automation):**

```bash
export BW_CLIENTID="your-client-id"
export BW_CLIENTSECRET="your-client-secret"
bw login --apikey --nointeraction
```

**SSO:**

```bash
bw login --sso
```

## Unlock the vault

After logging in, the vault is locked. Unlock it to get a session key:

```bash
export BW_SESSION=$(bw unlock --raw)
```

For non-interactive use (set in `.env`):

```bash
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
```

## First read

```bash
bw get item github | jq '.name, .login.username'
```

## Lock when done

```bash
bw lock
```
