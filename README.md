# OpenCode Cloud with DeepSeek

This branch is configured to run OpenCode entirely in GitHub Codespaces and access it from a browser.

## One-time setup

1. In GitHub, open **Settings → Codespaces → Secrets → New secret**.
2. Create a secret named `DEEPSEEK_API_KEY` and paste your DeepSeek API key as its value.
3. Give the secret access to this repository.
4. Open this repository and switch to the `opencode-cloud` branch.
5. Click **Code → Codespaces → Create codespace on opencode-cloud**.
6. The Codespace installs OpenCode automatically and starts OpenCode Web on port `4096`.
7. If it does not open automatically, open the **Ports** panel and click the browser/open icon for port `4096`.

## Security

- Keep port `4096` **Private** in Codespaces.
- Never commit your DeepSeek API key to this repository.
- The OpenCode configuration reads the key from the `DEEPSEEK_API_KEY` environment variable.

## Default models

- Main: `deepseek/deepseek-v4-pro`
- Small/lightweight: `deepseek/deepseek-v4-flash`

## Laptop requirements

No local OpenCode, Node.js, WSL, PowerShell, CMD, or terminal use is required. The runtime is inside GitHub Codespaces.
