# ipis — OpenCode on GitHub Codespaces

Runs the OpenCode server inside a Codespace and opens its web UI in a browser.
No local Node.js, terminal, or WSL required.

The environment lives on **this branch only**. Create the Codespace from the
branch you intend to use; a Codespace built from another branch uses that
branch's `.devcontainer`, not this one.

## Setup

1. Add a Codespaces secret named `DEEPSEEK_API_KEY` under
   **Settings → Codespaces → Secrets**, and grant it access to this repository.
2. Add a second secret, `OPENCODE_SERVER_PASSWORD`, to require a password on
   the server itself. Grant it access to this repository as well.
3. From this branch choose **Code → Codespaces → Create codespace**.
4. Wait for the container to finish building. `postStartCommand` starts
   OpenCode and only reports success once the port actually answers.
5. Open the **Ports** panel and click the globe icon next to **OpenCode Web**
   (port `4097`). Sign in with username `opencode` and the password stored in
   `OPENCODE_SERVER_PASSWORD`.

## Reading the forwarded URL correctly

The forwarded address looks like
`https://<codespace-name>-4097.app.github.dev`, and three rules govern it:

- **It exists only while the Codespace is running.** Codespaces stop after
  about 30 minutes idle. Opening a saved URL does not wake one; it returns a
  bare `404`. Start the Codespace first, then use the Ports panel.
- **The `<codespace-name>` part changes with every new Codespace.** A URL from
  a previous Codespace never comes back. Do not bookmark it.
- **The `-4097` suffix must match a port that is actually forwarded.** A
  forwarded port only appears once something is listening on it.

A `404` on that address means the route does not exist, which is always one of
the three causes above. It does not mean OpenCode returned an error; if
OpenCode were running and reachable it would answer with its own page.

## Changing the port or the container

`devcontainer.json` is read when the container is **built**. Editing it in git
does not change a Codespace that already exists. After changing `forwardPorts`,
the image, or the lifecycle commands, run
**Codespaces: Rebuild Container** from the command palette, or create a new
Codespace. Otherwise the old port stays forwarded and the new one 404s.

## Security

`start-opencode.sh` binds the server to `0.0.0.0` so the Codespaces port
forwarder can reach it. OpenCode grants shell access to this repository, so:

- Keep port `4097` set to **Private** in the Ports panel. Private is the
  default; a private port still opens normally in a browser that is signed in
  to GitHub.
- Keep `OPENCODE_SERVER_PASSWORD` configured. Without it OpenCode logs
  `server is unsecured`; if the port is ever made Public, anyone holding the
  URL would otherwise have full access.
- Never commit `DEEPSEEK_API_KEY`. The config reads it from the environment.

## Models

`opencode.json` requests `deepseek/deepseek-v4-pro` and
`deepseek/deepseek-v4-flash`. Confirm those identifiers exist for your account
before relying on them:

```bash
opencode models | grep deepseek
```

If they are absent, replace them in `opencode.json` with an identifier from
that list. A wrong model identifier breaks chat responses only; it does not
affect whether the page loads.

## Troubleshooting

Run these in the Codespace terminal:

```bash
pm2 list                  # opencode-web should be "online" with 0 restarts
pm2 logs opencode-web     # server output
curl -i localhost:4097/   # expect HTTP 200 and OpenCode's HTML
```

A rising restart count means OpenCode is exiting on startup; the logs give the
reason. `ServeError` means something else already holds the port.

## Local state

`.opencode-state/` holds OpenCode's sessions and provider credentials. It is
kept in the workspace so it survives container rebuilds, and it is gitignored.
Never commit it.
