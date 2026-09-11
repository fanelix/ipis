# ipis — OpenCode on GitHub Codespaces

Runs the OpenCode server inside a Codespace and opens its web UI in a browser.
No local Node.js, terminal, or WSL required.

The environment lives on **this branch only**. Create the Codespace from the
branch you intend to use; a Codespace built from another branch uses that
branch's `.devcontainer`, not this one.

## Setup

1. Add a Codespaces secret named `DEEPSEEK_API_KEY` under
   **Settings → Codespaces → Secrets**, and grant it access to this repository.
2. From this branch choose **Code → Codespaces → Create codespace**.
3. Wait for the container to finish building. `postStartCommand` starts
   OpenCode and only reports success once the port actually answers.
4. Open the **Ports** panel and click the globe icon next to **OpenCode Web**
   (port `4097`). No sign-in is required.

The server runs without a password. See [Security](#security) for what that
means and why the port must stay Private.

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

Server authentication is **disabled**. `start-opencode.sh` clears
`OPENCODE_SERVER_PASSWORD` before launching, so OpenCode accepts every request
and logs `server is unsecured`. That is intentional: it removes the password
prompt. It also means Codespaces port visibility is the only thing protecting
the server, and OpenCode grants shell access to this repository.

- **Keep port `4097` set to Private.** Private is the default, and a private
  port still opens normally in a browser signed in to GitHub. Setting it to
  Public hands anyone with the URL full shell access to this repo with no
  password in the way.
- Do not paste the forwarded URL anywhere public. Treat it as a credential for
  as long as the Codespace is running.
- To re-enable the password later, delete the `unset OPENCODE_SERVER_PASSWORD`
  line from `start-opencode.sh` and add `OPENCODE_SERVER_PASSWORD` as a
  Codespaces secret. The readiness check already authenticates itself whenever
  that variable is set, so nothing else needs changing. Sign in with username
  `opencode`, or override it with `OPENCODE_SERVER_USERNAME`.
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
