# NemoClaw Telegram Integration Guide

Connect your NemoClaw AI agent to Telegram so you can chat with it from anywhere.

Telegram is the easiest channel to set up with NemoClaw — it has an official Bot API, no QR scanning, and works reliably on any device.

Sources: [NVIDIA NemoClaw Telegram Bridge](https://docs.nvidia.com/nemoclaw/latest/deployment/set-up-telegram-bridge.html), [OpenClaw Telegram Setup](https://thebomb.ca/blog/openclaw-telegram-bot-setup/), [BotFather Guide](https://lumadock.com/tutorials/connect-openclaw-to-telegram-botfather). Content rephrased for compliance with licensing restrictions.

---

## How It Works

```
Your Phone/Desktop (Telegram)
    ↕  Telegram Bot API
NemoClaw Telegram Bridge (on your Azure VM)
    ↕  Internal API
NemoClaw Sandbox → AI Model → Response back to Telegram
```

NemoClaw includes a built-in Telegram bridge as an auxiliary service. You create a bot via Telegram's @BotFather, give NemoClaw the token, and it handles the rest.

---

## Prerequisites

- NemoClaw installed and running on your VM (see `nemoclaw-install-guide.md`)
- Your sandbox is active: `sudo nemoclaw nemoclaw-sandbox status`
- A Telegram account
- VM must stay running while the bridge is active

---

## Step 1 — Create a Telegram Bot via @BotFather

Open Telegram on your phone or desktop and search for `@BotFather`.

1. Start a chat with @BotFather
2. Send `/newbot`
3. BotFather asks for a **bot name** (display name, e.g. "NemoClaw Assistant")
4. BotFather asks for a **username** (must end in `bot`, e.g. `nemoclaw_assistant_bot`)
5. BotFather gives you a **Bot Token** — copy it

The token looks like:
```
7123456789:AAH_your_secret_bot_token_here
```

> **Security:** Do not share this token publicly or commit it to Git. Anyone with it can control your bot. If leaked, revoke it immediately via @BotFather with `/revoke`.

---

## Step 2 — Get Your Telegram User ID

You need your numeric user ID to restrict who can talk to the bot.

Try one of these bots (some may be unresponsive):
1. `@raw_data_bot` — send any message, it returns your user info
2. `@getmyid_bot` — send `/start`, it replies with your ID
3. `@userinfobot` — send any message

Or the manual way — after creating your bot (Step 1), open this URL in a browser:
```
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```
Send a message to your bot in Telegram, refresh the URL, and look for `"from":{"id":123456789}` in the JSON. That number is your user ID.

Save this number — you'll use it to whitelist yourself.

---

## Step 3 — Set Environment Variables on Your VM

SSH into your VM:

```cmd
ssh azureuser@<PUBLIC_IP>
```

Export the required environment variables:

```bash
export TELEGRAM_BOT_TOKEN=7123456789:AAH_your_secret_bot_token_here
export NVIDIA_API_KEY=your-nvidia-api-key-here
export SANDBOX_NAME=nemoclaw-sandbox
```

> **Critical:** `SANDBOX_NAME` must match your actual sandbox name. Check with `sudo nemoclaw list`. The bridge defaults to `nemoclaw` but your sandbox may be named `nemoclaw-sandbox`. If this doesn't match, the bridge will fail with "sandbox not found".

To make it persistent across reboots:

```bash
echo 'export TELEGRAM_BOT_TOKEN=7123456789:AAH_your_secret_bot_token_here' >> ~/.bashrc
echo 'export NVIDIA_API_KEY=your-nvidia-api-key-here' >> ~/.bashrc
echo 'export SANDBOX_NAME=nemoclaw-sandbox' >> ~/.bashrc
source ~/.bashrc
```

Replace the values with your actual token and API key.

> **Warning:** Only run the `echo >> ~/.bashrc` commands once. Running them multiple times will append duplicate entries. If that happens, edit `~/.bashrc` with `nano ~/.bashrc` and remove the duplicates.

---

## Step 4 — Restrict Access (Optional but Recommended)

To restrict which Telegram users can interact with the bot, set allowed chat IDs:

```bash
export ALLOWED_CHAT_IDS="987654321"
```

For multiple users, comma-separate:

```bash
export ALLOWED_CHAT_IDS="987654321,123456789"
```

Make it persistent:

```bash
echo 'export ALLOWED_CHAT_IDS="987654321"' >> ~/.bashrc
source ~/.bashrc
```

Without this, anyone who finds your bot username can talk to it.

---

## Step 5 — Select the Gateway and Start the Bridge

First, ensure the gateway is selected:

```bash
sudo openshell gateway select nemoclaw
```

Then start NemoClaw's auxiliary services:

```bash
sudo -E nemoclaw start
```

> The `-E` flag preserves your environment variables (TELEGRAM_BOT_TOKEN, NVIDIA_API_KEY, SANDBOX_NAME, ALLOWED_CHAT_IDS) when running with sudo. Without it, the bridge won't have the credentials it needs.

The `start` command launches:
- The Telegram bridge (forwards messages between Telegram and the agent)
- A cloudflared tunnel (provides external access to the sandbox)

The Telegram bridge only starts when `TELEGRAM_BOT_TOKEN` is set.

### If the bridge shows "No sandbox in Ready state"

The sandbox might not be running. Check and fix:

```bash
sudo nemoclaw list
sudo nemoclaw nemoclaw-sandbox status
```

If no sandbox exists, re-onboard:

```bash
sudo nemoclaw stop
sudo openshell gateway stop --name nemoclaw
sudo -E nemoclaw onboard
sudo -E nemoclaw start
```

---

## Step 6 — Verify the Bridge is Running

Check the status of auxiliary services:

```bash
sudo nemoclaw status
```

You should see the Telegram bridge listed as running.

---

## Step 7 — Test Your Bot

1. Open Telegram
2. Search for your bot username (e.g. `@nemoclaw_assistant_bot`)
3. Send `/start`
4. Send a message: `Hello`

The bot should respond with an AI-generated reply within a few seconds.

### First-Time Pairing (if using pairing policy)

If access control is set to pairing mode, the bot will reply with a pairing code. Approve it from your VM:

```bash
sudo nemoclaw nemoclaw-sandbox connect
# Inside the sandbox:
openclaw pairing approve telegram YOUR_CODE_HERE
```

---

## Step 8 — Set Up Bot Commands (Optional)

Add custom commands to your bot via @BotFather:

1. Open @BotFather
2. Send `/setcommands`
3. Select your bot
4. Paste:

```
status - Check agent status
help - Show available commands
clear - Clear conversation history
```

These commands will appear as suggestions when users type `/` in the chat.

---

## Step 9 — Auto-Start on Boot (Optional)

Create a systemd service so the bridge starts automatically when the VM boots:

```bash
sudo tee /etc/systemd/system/nemoclaw-telegram.service << 'EOF'
[Unit]
Description=NemoClaw Telegram Bridge
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
Environment=TELEGRAM_BOT_TOKEN=7123456789:AAH_your_secret_bot_token_here
Environment=NVIDIA_API_KEY=your-nvidia-api-key-here
Environment=SANDBOX_NAME=nemoclaw-sandbox
Environment=ALLOWED_CHAT_IDS=987654321
ExecStart=/usr/local/bin/nemoclaw start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nemoclaw-telegram
sudo systemctl start nemoclaw-telegram
```

Replace the token, API key, sandbox name, and chat IDs with your actual values.

Check status:

```bash
sudo systemctl status nemoclaw-telegram
```

---

## Step 10 — Disable Auto-Shutdown (Optional)

If you want the bot available 24/7, disable VM auto-shutdown from your local Windows CMD:

```cmd
az vm auto-shutdown --resource-group nemoclaw-rg --name nemoclaw-vm --off
```

Or keep auto-shutdown and accept the bot goes offline at midnight.

---

## Useful Commands

```bash
# Select the gateway (needed after reboot or gateway restart)
sudo openshell gateway select nemoclaw

# Start the bridge
sudo -E nemoclaw start

# Stop the bridge
sudo nemoclaw stop

# Check bridge status
sudo nemoclaw status

# View logs
sudo nemoclaw nemoclaw-sandbox logs

# Check sandbox status
sudo nemoclaw nemoclaw-sandbox status

# List sandboxes
sudo nemoclaw list

# Restart after config changes
sudo nemoclaw stop
sudo -E nemoclaw start

# Run bridge manually for debugging (shows errors in real-time)
sudo TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN NVIDIA_API_KEY=$NVIDIA_API_KEY SANDBOX_NAME=nemoclaw-sandbox node /root/.nemoclaw/source/scripts/telegram-bridge.js
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "sandbox not found" error in Telegram | Set `SANDBOX_NAME` env var to match your actual sandbox name. Check with `sudo nemoclaw list` |
| Bot doesn't reply to /start | Check bridge is running: `sudo nemoclaw status`. Verify token is correct |
| "No active gateway" error | Run `sudo openshell gateway select nemoclaw` |
| "No sandbox in Ready state" | Sandbox may need re-onboarding: `sudo -E nemoclaw onboard` |
| "NVIDIA_API_KEY required" | Export the key: `export NVIDIA_API_KEY=your-key` and use `sudo -E` |
| "Unauthorized" or token invalid | Copy token again from @BotFather. If leaked, revoke with `/revoke` and create a new bot |
| Bridge not starting | Ensure all env vars are set: `echo $TELEGRAM_BOT_TOKEN $NVIDIA_API_KEY $SANDBOX_NAME`. Use `sudo -E` to preserve them |
| Duplicate API keys in credentials.json | Edit with `sudo nano /root/.nemoclaw/credentials.json` and remove duplicate entries. Only append env vars to `~/.bashrc` once |
| @userinfobot not responding | Try `@raw_data_bot` or `@getmyid_bot` instead, or use the `getUpdates` API method |
| Pairing code expired | Send `/start` again to get a new code |
| Random people messaging the bot | Set `ALLOWED_CHAT_IDS` to restrict access |
| Bot replies slowly | Check your inference provider's latency. Local Ollama is faster than cloud APIs for simple queries |
| Bridge dies when VM shuts down | Set up systemd service (Step 9) or disable auto-shutdown (Step 10) |
| Port 8080 conflict during onboard | The gateway is already running. Run `sudo openshell gateway stop --name nemoclaw` first, then onboard |
| BadSignature / invalid peer certificate | Corrupted TLS certs from repeated stop/start cycles. See "Full Nuclear Reset" in `nemoclaw-install-guide.md` |
| Bridge shows stale PID / "already running" | Kill the old process: `sudo kill <PID>`, then `sudo -E nemoclaw start` |
| SSH gateway banner in responses ("Running as non-root") | Edit `/root/.nemoclaw/source/scripts/telegram-bridge.js`, add `!l.includes("privilege separation") &&` and `!l.includes("Running as non-root") &&` to the response filter, and add `-o LogLevel=ERROR` to the SSH spawn args |
| Agent returns raw XML tool calls | Agent is still initializing (reading SOUL.md etc.). Send a few more messages — it stabilizes after initial setup |

---

---

## Stability Tips

- **Don't destroy sandboxes unnecessarily.** Running `nemoclaw <name> destroy` or killing bridge processes frequently causes TLS certificate corruption and state desync. Only destroy as a last resort.
- **Don't kill the bridge PID manually** unless it's truly stuck. Use `sudo nemoclaw stop` instead.
- **After a VM reboot**, you only need to run:
  ```bash
  sudo openshell gateway select nemoclaw
  sudo -E nemoclaw start
  ```
  You do NOT need to re-onboard after a normal reboot. The sandbox and gateway state persist in Docker volumes.
- **If `openshell sandbox list` shows BadSignature**, the cached TLS certs are corrupted. Remove them:
  ```bash
  sudo rm -rf /root/.openshell ~/.openshell
  ```
  Then restart the gateway and re-onboard.

---

## Filtering SSH Banner from Responses

The SSH gateway prints `"gateway Running as non-root (uid=998) — privilege separation disabled"` which leaks into Telegram messages. To remove it, edit the bridge script:

```bash
sudo nano /root/.nemoclaw/source/scripts/telegram-bridge.js
```

Find the `responseLines` filter block and add these lines before `l.trim() !== ""`:

```javascript
  !l.includes("privilege separation") &&
  !l.includes("Running as non-root") &&
```

Also add `-o LogLevel=ERROR` to the SSH spawn args to suppress SSH informational messages. Find:

```javascript
const proc = spawn("ssh", ["-T", "-F", confPath, `openshell-${SANDBOX}`, cmd], {
```

Change to:

```javascript
const proc = spawn("ssh", ["-T", "-o", "LogLevel=ERROR", "-F", confPath, `openshell-${SANDBOX}`, cmd], {
```

Restart the bridge after editing:

```bash
sudo nemoclaw stop
sudo -E nemoclaw start
```

---

## Telegram vs WhatsApp Comparison

| Feature | Telegram | WhatsApp |
|---------|----------|----------|
| Setup complexity | Easy (token-based) | Harder (QR scan, session management) |
| Official Bot API | Yes | No (uses Web protocol) |
| Session persistence | Token never expires | Can disconnect, needs re-linking |
| Multi-device | Works everywhere | Bridge tied to one phone |
| Rate limits | Generous | Strict anti-spam |
| Group support | Yes | Possible but risky |
| Recommended for | Primary use | Secondary / mobile-only use |

---

## References

- [NVIDIA NemoClaw Telegram Bridge (Official)](https://docs.nvidia.com/nemoclaw/latest/deployment/set-up-telegram-bridge.html)
- [OpenClaw Telegram Bot Setup](https://thebomb.ca/blog/openclaw-telegram-bot-setup/)
- [BotFather Guide](https://lumadock.com/tutorials/connect-openclaw-to-telegram-botfather)
- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
