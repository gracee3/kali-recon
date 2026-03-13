# Kali Recon Image

A minimal, non-opinionated Kali Linux container for public-information gathering and reconnaissance.

> Scope note: this image is for public/open-source infrastructure and content intelligence workflows. Keep tool use compliant with local law, terms of service, and target authorization.

## Repository hygiene

- Includes a permissive [MIT license](LICENSE) for public distribution.
- Includes a minimal [.gitignore](/home/emmy/git/recon/.gitignore) and [.dockerignore](/home/emmy/git/recon/.dockerignore) for safer repository/image hygiene.
- Small, explicit toolset focused on outbound OSINT/recon tasks.
- No fixed workflow: the container starts as an interactive shell and accepts arbitrary commands.
- Signal-safe execution via `tini`.

## Included tools

Installed tooling:

- `curl`, `wget`
- `git`
- `jq`, `yq`
- `ripgrep`
- `fd-find` (also available as `fd`)
- `less`, `tree`
- `dnsutils`, `whois`
- `python3`, `python3-pip`
- `subfinder`, `amass`, `httpx`, `wpscan`

Optional at build time:

- `wkhtmltopdf` for lightweight webpage screenshotting (`ENABLE_SCREENSHOT_TOOL=1`)

## Workspace layout

`/workspace` is the default working directory and expected bind mount point:

- `/workspace/input` for target lists and local inputs
- `/workspace/output` for scan and recon artifacts
- `/workspace/config` for local config/API key files
- `/workspace/tmp` for temporary scratch data

## Build

```bash
docker build -t kali-recon .
```

To include optional screenshot support:

```bash
docker build --build-arg ENABLE_SCREENSHOT_TOOL=1 -t kali-recon:with-shot .
```

## Run

Interactive shell (recommended for one-off workflows):

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  kali-recon
```

One-off command:

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  kali-recon amass enum -passive -d example.com
```

If your bind mount is owned by your host UID/GID, pass it through explicitly:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$PWD:/workspace" \
  kali-recon recon-env amass enum -passive -d example.com
```

Before first run with a mounted `/workspace`, pre-create writable subdirectories:

```bash
mkdir -p "$PWD"/{input,output,config,tmp}
```

Using mounted config files (`/workspace/config`):

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.config/recon:/workspace/config:ro" \
  kali-recon recon-env amass enum -passive -d example.com
```

If multiple `.env` files exist in `/workspace/config`, `recon-env` will load them all into the environment.

## Helpers

- `recon-env`: small wrapper to load environment variables from `/workspace/config/*.env` before executing a command.

## Safety and legal notes

- Use only domains and targets you are authorized to test.
- Configure API keys via mounted files under `/workspace/config` and avoid embedding secrets in command history.

## Hardening pass applied

- Runtime executes as non-root user (`recon`).
- Workspace and home ownership/permissions are set explicitly in the image build.
- `tini` is installed from distro packages and used as PID 1.
- Build context is filtered via `.dockerignore`.
- `.env` material is never baked into the image; mount only from trusted local paths at runtime.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
