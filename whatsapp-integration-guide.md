# NemoClaw WhatsApp Integration Guide

Connect your NemoClaw AI agent to WhatsApp so you can chat with it from your phone.

> **Security Warning:** Use a dedicated/burner phone number — not your primary one. OpenClaw will have access to messages on the linked account. A prepaid SIM or eSIM is ideal.

Sources: [OpenClaw WhatsApp Integration](https://thebomb.ca/blog/openclaw-whatsapp-integration/), [C# Corner Guide](https://www.c-sharpcorner.com/article/integrating-whatsapp-with-openclaw-ai-agents-2026-the-correct-method-most-tu/), [Production Setup](https://lumadock.com/tutorials/openclaw-whatsapp-production-setup). Content rephrased for compliance with licensing restrictions.

---

## How It Works

```
Your Phone (WhatsApp)
    ↕  WhatsApp Web Multi-Device Protocol
OpenClaw WhatsApp Bridge (on your Azure VM)
    ↕  Internal API
NemoClaw Sandbox → AI Model → Response back to WhatsApp
```

OpenClaw includes a built-in WhatsApp channel that uses QR-based device linking (same as WhatsApp Web). No third-party APIs, webhooks, or external bridges needed.

---

## Prerequisites

- NemoClaw installed and running on your VM (see `nemoclaw-install-guide.md`)
- Your sandbox is active: `sudo nemoclaw nemoclaw-sandbox status`
- A phone with WhatsApp installed
- A dedicated phone number for the bot (recommended)
- VM must stay running while the bridge is active (consider disabling auto-shutdown)

---

## Step 1 — Disable Auto-Shutdown (Optional but Recommended)

The WhatsApp bridge needs a persistent connection. If your VM shuts down, the bridge disconnects.

From your local Windows CMD:

```cmd
az vm auto-shutdown --resource-group nemoclaw-rg --name nemoclaw-vm --off
```

Or keep auto-shutdown but manually start the VM each morning:

```cmd
az vm start --resource-group nemoclaw-rg --name nemoclaw-vm
```

---

## Step 2 — Connect to Your Sandbox

SSH into your VM:

```cmd
ssh azureuser@<PUBLIC_IP>
```

Then connect to the NemoClaw sandbox:

```bash
sudo nemoclaw nemoclaw-sandbox connect
```

You should see the sandbox shell: `sandbox@nemoclaw-sandbox:~$`

---

## Step 3 — Add the WhatsApp Channel

Inside the sandbox, add WhatsApp as a communication channel:

```bash
openclaw channel add whatsapp
```

This installs the WhatsApp bridge dependencies automatically.

---

## Step 4 — Authenticate with QR Code

Start the WhatsApp authentication:

```bash
openclaw channel auth whatsapp
```

A QR code will appear in your terminal. On your phone:

1. Open WhatsApp
2. Go to **Settings → Linked Devices**
3. Tap **Link a Device**
4. Scan the QR code from your terminal

> The QR code expires after ~60 seconds. If it expires, run the auth command again.

After scanning, you should see:

```
✓ WhatsApp authenticated successfully
✓ Session stored at ~/.openclaw/channels/whatsapp/session/
✓ Bridge connected — listening for messages
```

---

## Step 5 — Configure Access Policy

OpenClaw will ask you to set a DM access policy during setup:

| Policy    | Description                                              |
|-----------|----------------------------------------------------------|
| pairing   | Unknown users must request access; you approve manually  |
| allowlist | Only pre-approved numbers can interact                   |
| open      | Anyone can message the bot (not recommended)             |
| disabled  | WhatsApp channel is off                                  |

**Recommended:** Use `pairing` (default) or `allowlist` for security.

### Configure Allowlist

If you chose allowlist, specify which numbers can interact. Edit the OpenClaw config:

```bash
# Inside the sandbox
cat > ~/.openclaw/channels/whatsapp/config.yaml << 'EOF'
enabled: true
dmPolicy: allowlist
allowFrom:
  - "+60123456789"    # Your phone number (international format)
ignoreGroups: true
autoRead: true
response:
  typingIndicator: true
  typingDelayMs: 1500
  maxMessageLength: 4096
  splitLongMessages: true
EOF
```

Replace `+60123456789` with your actual phone number in international format.

---

## Step 6 — Enter Your Phone Number

OpenClaw will ask which phone number will interact with the agent. Enter your WhatsApp number in international format:

```
+60123456789
```

This whitelists you as the primary user.

---

## Step 7 — Test the Integration

Send a WhatsApp message to the number running OpenClaw:

```
Hi
```

The agent should respond automatically in WhatsApp.

### First-Time Pairing Approval

If using the `pairing` policy, new users will see:

```
OpenClaw: access not configured.
Your WhatsApp phone number: +60123456789
Pairing code: XGSKNQWF
Ask the bot owner to approve with:
openclaw pairing approve whatsapp <code>
```

Approve from the sandbox shell:

```bash
openclaw pairing approve whatsapp XGSKNQWF
```

After approval, the user can chat freely with the agent.

---

## Step 8 — Handle Media (Optional)

OpenClaw can process images, documents, and voice notes sent via WhatsApp:

```yaml
# Add to ~/.openclaw/channels/whatsapp/config.yaml
media:
  images: true
  documents: true
  voiceNotes: true
  downloadPath: "/home/user/whatsapp-media"
  autoDeleteAfter: "24h"
```

Example: Send a screenshot with the caption "What's wrong with this code?" and the agent will analyze it.

---

## Step 9 — Restart the Gateway

After any config changes, restart:

```bash
openclaw gateway restart
```

---

## Session Persistence

WhatsApp sessions persist across gateway restarts. Session data is stored at:

```
~/.openclaw/channels/whatsapp/session/
```

### Back Up Your Session

```bash
cp -r ~/.openclaw/channels/whatsapp/session/ ~/whatsapp-session-backup/
```

### Re-authenticate (if session expires)

```bash
openclaw channel auth whatsapp --force
```

---

## Production Hardening

### Bind Gateway to Localhost

Don't expose the gateway port publicly. Keep it bound to `127.0.0.1`:

```bash
# Check gateway is not exposed
sudo ss -tlnp | grep 18789
```

If you need remote access, use SSH port forwarding from your local machine:

```cmd
ssh -L 18789:127.0.0.1:18789 azureuser@<PUBLIC_IP>
```

### Rate Limiting

WhatsApp has anti-spam protections. Avoid sending too many messages too quickly:

```yaml
# Add to config
rateLimit:
  messagesPerMinute: 10
  cooldownAfterBurst: 30
```

### What Gets You Flagged by WhatsApp

- Messaging lots of new contacts quickly
- Sending repetitive messages at high volume
- Getting reported by users

Personal assistant usage (you talking to your own agent) is low-risk. Outbound bulk messaging is high-risk.

---

## Useful Commands

```bash
# Check WhatsApp bridge logs
openclaw logs --follow --channel whatsapp

# Check gateway status
openclaw gateway status

# List channels
openclaw channel list

# Re-authenticate WhatsApp
openclaw channel auth whatsapp --force

# Remove WhatsApp channel
openclaw channel remove whatsapp
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| QR code expired | Run `openclaw channel auth whatsapp` again (expires after ~60s) |
| Session closed / disconnected | Re-link: `openclaw channel auth whatsapp --force` |
| Messages not received | Check bridge logs: `openclaw logs --follow --channel whatsapp`. Ensure phone has internet |
| "Access not configured" | Approve the user: `openclaw pairing approve whatsapp <code>` |
| Bot responds to group chats | Set `ignoreGroups: true` in config |
| Account restricted by WhatsApp | You're sending too many messages or got reported. Use a dedicated number |
| Bridge dies when VM shuts down | Disable auto-shutdown or restart VM and re-run the bridge |
| Clock drift causes auth failures | Fix VM clock: `sudo timedatectl set-ntp true` |
| Can't scan QR (terminal too small) | Resize terminal window or use `ssh -o "SendEnv=TERM" -t` for better rendering |

---

## References

- [OpenClaw WhatsApp Integration Guide](https://thebomb.ca/blog/openclaw-whatsapp-integration/)
- [Integrating WhatsApp with OpenClaw (2026)](https://www.c-sharpcorner.com/article/integrating-whatsapp-with-openclaw-ai-agents-2026-the-correct-method-most-tu/)
- [WhatsApp Production Setup](https://lumadock.com/tutorials/openclaw-whatsapp-production-setup)
- [NVIDIA NemoClaw Quickstart](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html)
