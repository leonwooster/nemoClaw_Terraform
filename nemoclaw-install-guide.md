# NemoClaw Installation Guide

A comprehensive guide to installing NVIDIA NemoClaw on your Azure VM (or any Ubuntu 22.04+ machine).

> NemoClaw is in alpha (early preview since March 16, 2026). APIs and behavior may change between releases. Do not use in production.

Sources: [NVIDIA NemoClaw Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html), [Inference Profiles](https://docs.nvidia.com/nemoclaw/latest/reference/inference-profiles.html), [Troubleshooting](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html)

---

## What is NemoClaw?

NemoClaw is an open-source stack from NVIDIA that simplifies running OpenClaw AI agents in sandboxed environments. It installs the NVIDIA OpenShell runtime (a secure environment for autonomous agents) and supports models like NVIDIA Nemotron. Content rephrased for compliance with licensing restrictions.

---

## Prerequisites

### Hardware

- Minimum 8 GB RAM (the sandbox image is ~2.4 GB compressed; Docker, k3s, and the OpenShell gateway run alongside it)
- If you have less than 8 GB RAM, configure at least 8 GB of swap to avoid OOM kills
- The onboarding wizard will offer to create a 4 GB swap file if low memory is detected — say yes

### Software

| Dependency | Version              |
|------------|----------------------|
| Linux      | Ubuntu 22.04 LTS+   |
| Node.js    | 20 or later          |
| npm        | 10 or later          |
| Docker     | Installed and running|
| OpenShell  | Installed            |

### API Key (for cloud inference)

You need an API key from one of the supported providers:
- NVIDIA API key (from [NVIDIA NGC](https://build.nvidia.com/))
- OpenAI API key
- Anthropic API key
- Or use local Ollama (no key needed)

---

## Step 1 — Prepare the VM

SSH into your VM:

```cmd
ssh azureuser@<PUBLIC_IP>
```

Update packages and set timezone:

```bash
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Kuala_Lumpur
```

---

## Step 2 — Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add your user to the docker group (avoids needing sudo)
sudo usermod -aG docker $USER

# Apply group change (or log out and back in)
newgrp docker

# Verify Docker is running
docker --version
docker run hello-world
```

---

## Step 3 — Install Node.js 22

The NemoClaw installer can install Node.js automatically, but if you want to do it manually:

```bash
# Install Node.js 22 via NodeSource
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Verify
node --version   # Should be v22.x
npm --version    # Should be 10.x+
```

If you use nvm:

```bash
nvm install 22
nvm use 22
```

---

## Step 4 — Install NemoClaw

> **Important:** The installer requires sudo to create global npm symlinks. Without sudo, you'll get EACCES permission errors.

### Interactive Install (with sudo)

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | sudo bash
```

### Non-Interactive Install (with sudo)

For automated/scripted installs:

```bash
export NVIDIA_API_KEY="your-api-key-here"
curl -fsSL https://www.nvidia.com/nemoclaw.sh | sudo bash -s -- --non-interactive
```

### Alternative: Install Without sudo

If you prefer not to use sudo, fix npm's global prefix first:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
```

Then run without sudo:

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash -s -- --non-interactive
```

### Post-Install: Verify

If installed with sudo, nemoclaw lives in root's path. You may need to use `sudo` for all nemoclaw commands, or create a symlink:

```bash
# Check where it was installed
sudo which nemoclaw

# Create a symlink so your user can access it
sudo ln -s $(sudo which nemoclaw) /usr/local/bin/nemoclaw
```

If `nemoclaw` is still not found (common with nvm/fnm):

```bash
source ~/.bashrc
```

Verify:

```bash
nemoclaw --version
# or if installed with sudo:
sudo nemoclaw --version
```

### Post-Install: Set Environment Variables

After installation, set these environment variables for the Telegram bridge and other services:

```bash
export NVIDIA_API_KEY=your-nvidia-api-key-here
export SANDBOX_NAME=nemoclaw-sandbox
```

Make them persistent:

```bash
echo 'export NVIDIA_API_KEY=your-nvidia-api-key-here' >> ~/.bashrc
echo 'export SANDBOX_NAME=nemoclaw-sandbox' >> ~/.bashrc
source ~/.bashrc
```

> **Warning:** Only run the `echo >> ~/.bashrc` commands once. Running them multiple times appends duplicate entries which can cause issues (e.g. duplicate API keys in credentials.json). If that happens, clean up with `nano ~/.bashrc` and remove duplicates.

> **Warning:** The `SANDBOX_NAME` must match your actual sandbox name. The bridge defaults to `nemoclaw` but onboarding may create a sandbox named `nemoclaw-sandbox`. Check with `sudo nemoclaw list` after onboarding.

---

## Step 5 — Onboard Your First Agent

The installer runs the onboard wizard automatically. If you need to run it again:

```bash
sudo -E nemoclaw onboard
```

> **Important:** If onboarding says "Port 8080 is not available", the gateway is already running. Stop it first:
> ```bash
> sudo nemoclaw stop
> sudo openshell gateway stop --name nemoclaw
> sudo -E nemoclaw onboard
> ```

> **Swap prompt:** If the wizard asks to create a swap file due to low memory, say `y`. This prevents OOM kills during sandbox creation.

The wizard will:
1. Create a sandbox (isolated environment with Landlock + seccomp + netns)
2. Ask you to choose an inference provider (NVIDIA Endpoints, OpenAI, Anthropic, or local Ollama)
3. Ask for your API key
4. Validate the provider and model
5. Apply security policies

### Supported Inference Providers

| Provider          | Key Required | Notes                                    |
|-------------------|--------------|------------------------------------------|
| NVIDIA Endpoints  | Yes          | Uses Nemotron models via NVIDIA API      |
| OpenAI            | Yes          | OpenAI-compatible API                    |
| Anthropic         | Yes          | Uses /v1/messages endpoint               |
| Local Ollama      | No           | Runs locally, installer helps pull models|

When onboarding completes, you'll see something like:

```
──────────────────────────────────────────────────
Sandbox      nemoclaw-sandbox (Landlock + seccomp + netns)
Model        nvidia/nemotron-3-super-120b-a12b (NVIDIA Endpoints)
──────────────────────────────────────────────────
```

> **Note:** The sandbox name is assigned during onboarding (e.g. `nemoclaw-sandbox`). It may not be `my-assistant`. Check the actual name with:
> ```bash
> sudo nemoclaw help
> ```
> The output will list registered sandboxes.

---

## Step 6 — Connect and Chat

### Find Your Sandbox Name

```bash
sudo nemoclaw help
# Look for "Registered sandboxes: <name>"
```

### Connect to the Sandbox

Replace `<sandbox-name>` with your actual sandbox name (e.g. `nemoclaw-sandbox`):

```bash
sudo nemoclaw <sandbox-name> connect
```

This drops you into the sandbox shell: `sandbox@<sandbox-name>:~$`

### Chat via TUI (Interactive)

Inside the sandbox, launch the interactive chat:

```bash
openclaw
```

Type a message and verify you get a response. The TUI is best for interactive conversations.

### Chat via CLI (Single Message)

For scripted or long-output use:

```bash
openclaw agent --agent main --local -m "hello" --session-id test
```

This prints the full response directly in the terminal.

---

## Step 7 — Useful Commands

Replace `<sandbox-name>` with your actual sandbox name (check with `sudo nemoclaw list`).

```bash
# Check sandbox status
sudo nemoclaw <sandbox-name> status

# View logs
sudo nemoclaw <sandbox-name> logs

# List all sandboxes
sudo nemoclaw list

# List sandboxes via OpenShell (run from host, not inside sandbox)
sudo openshell sandbox list

# Select the gateway (needed after reboot or if bridge shows "No active gateway")
sudo openshell gateway select nemoclaw

# View network policy
sudo openshell policy get <sandbox-name> --full

# Destroy and recreate sandbox (if broken)
sudo nemoclaw <sandbox-name> destroy --yes
sudo -E nemoclaw onboard

# Re-run onboarding (stop gateway first if port 8080 is in use)
sudo nemoclaw stop
sudo openshell gateway stop --name nemoclaw
sudo -E nemoclaw onboard
```

---

## Step 8 — Network Policy

OpenShell blocks outbound connections to hosts not in the network policy by default. If the agent needs to reach external hosts:

1. Open the TUI to see blocked requests and approve them
2. Or add trusted domains to the network policy permanently

Refer to [Customize the Network Policy](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html) in the official docs.

---

## Uninstall

To completely remove NemoClaw and all resources:

```bash
curl -fsSL https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh | sudo bash
```

Skip confirmation prompt:

```bash
curl -fsSL https://raw.githubusercontent.com/NVIDIA/NemoClaw/refs/heads/main/uninstall.sh | sudo bash -s -- --yes
```

This removes sandboxes, the gateway, providers, Docker images/containers, local state, and the npm package. It does not remove Docker, Node.js, npm, or Ollama.

### Full Nuclear Reset (if certificates are corrupted)

If you see `BadSignature` or `invalid peer certificate` errors that won't go away:

```bash
sudo nemoclaw stop
sudo nemoclaw uninstall --yes
sudo docker stop $(sudo docker ps -q --filter name=openshell) 2>/dev/null
sudo docker rm $(sudo docker ps -aq --filter name=openshell) 2>/dev/null
sudo rm -rf /root/.openshell /home/azureuser/.openshell /root/.nemoclaw ~/.nemoclaw
```

Then reinstall:

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | sudo bash -s -- --non-interactive
```

The key is removing `.openshell` from both `/root/` and your user home — cached TLS certificates live there and can become corrupted from repeated stop/start cycles.

> **Avoid destroying sandboxes unnecessarily.** Running `nemoclaw <name> destroy` or killing bridge processes frequently is the main cause of certificate corruption and state desync. Only destroy as a last resort.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `nemoclaw` not found after install | Installed with sudo? Use `sudo nemoclaw` or symlink: `sudo ln -s $(sudo which nemoclaw) /usr/local/bin/nemoclaw` |
| EACCES permission error during install | Use `sudo` with the installer: `curl ... \| sudo bash` |
| `nemoclaw` not found (nvm/fnm) | Run `source ~/.bashrc` or open a new terminal |
| Unknown command: my-assistant | Your sandbox has a different name. Run `sudo nemoclaw list` to see registered sandboxes |
| "sandbox not found" from Telegram bridge | Set `export SANDBOX_NAME=nemoclaw-sandbox` (must match actual sandbox name from `sudo nemoclaw list`) |
| "NVIDIA_API_KEY required" | Export the key: `export NVIDIA_API_KEY=your-key` and use `sudo -E` to preserve it |
| "No active gateway" | Run `sudo openshell gateway select nemoclaw` |
| "No sandbox in Ready state" | Sandbox needs re-onboarding: stop gateway first, then `sudo -E nemoclaw onboard` |
| Port 8080 conflict during onboard | Gateway already running. `sudo openshell gateway stop --name nemoclaw` first |
| Duplicate API keys in credentials.json | Edit with `sudo nano /root/.nemoclaw/credentials.json` and remove duplicates. Only append to `~/.bashrc` once |
| BadSignature / invalid peer certificate | Corrupted TLS certs. See "Full Nuclear Reset" in the Uninstall section |
| `nemoclaw list` shows nothing after onboard | NemoClaw registry out of sync. Check `sudo openshell sandbox list` — sandbox may exist in OpenShell but not NemoClaw's registry. Re-onboard to fix |
| `openshell sandbox list` shows BadSignature | Remove cached certs: `sudo rm -rf /root/.openshell ~/.openshell`, then restart gateway |
| Node.js version too old | `nvm install 22 && nvm use 22`, then re-run installer |
| Docker not running | `sudo systemctl start docker` |
| Port 18789 in use | `lsof -i :18789` then `kill <PID>` |
| Cgroup v2 errors | `sudo nemoclaw setup-spark` then `sudo nemoclaw onboard` |
| Sandbox shows stopped | Run `sudo nemoclaw onboard` to recreate |
| Inference requests timeout | Check provider endpoint is reachable, verify API key |
| Agent can't reach external host | Approve the host in the TUI or add to network policy |
| OOM during sandbox creation | Add swap: `sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile` |

---

## References

- [NVIDIA NemoClaw Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html)
- [Inference Profiles](https://docs.nvidia.com/nemoclaw/latest/reference/inference-profiles.html)
- [Troubleshooting](https://docs.nvidia.com/nemoclaw/latest/reference/troubleshooting.html)
- [NVIDIA NemoClaw GitHub](https://github.com/NVIDIA/NemoClaw)
- [OpenShell Documentation](https://docs.nvidia.com/openshell/)
