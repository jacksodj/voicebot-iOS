# Tailscale Setup Guide for Voice Agent iOS App

This guide explains how to configure Tailscale networking for secure communication between your iPhone and DGX Spark backend.

## Overview

Tailscale creates a secure, private network (VPN) between your devices without exposing them to the public internet. This is essential for:
- Secure WebSocket connections to DGX Spark
- Low-latency voice communication
- No port forwarding or firewall configuration needed

## Architecture

```
iPhone (Tailscale client)
    ↓ (encrypted VPN tunnel)
    ↓
Tailscale Network
    ↓
DGX Spark (Tailscale node)
    ↓ (local connection)
Pipecat Voice Agent (port 8080)
```

## Prerequisites

1. Tailscale account (free tier is sufficient)
2. DGX Spark with network connectivity
3. iPhone with iOS 15+

## Setup Steps

### 1. Install Tailscale on DGX Spark

```bash
# On DGX Spark (Ubuntu/Linux)
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo tailscale up

# Note the machine's Tailscale IP and hostname
tailscale status
```

You'll see output like:
```
dgx-spark    100.x.x.x    linux   -
```

The hostname will be: `dgx-spark.tail-scale.ts.net`

### 2. Configure DGX Spark to Expose WebSocket

After starting your Pipecat voice agent on port 8080, you have two options:

#### Option A: Direct Connection (Simplest)

No additional configuration needed. The iPhone will connect directly over Tailscale:
```
ws://dgx-spark.tail-scale.ts.net:8080
```

#### Option B: Tailscale Serve (Recommended for SSL)

Use Tailscale's built-in HTTPS proxy:

```bash
# On DGX Spark
tailscale serve --bg wss:443 http://localhost:8080
```

Then connect from iPhone using:
```
wss://dgx-spark.tail-scale.ts.net
```

### 3. Install Tailscale on iPhone

1. Download "Tailscale" from the App Store
2. Open the app and sign in with your Tailscale account
3. Tap "Log In" and authorize the device
4. Enable "On Demand" for automatic connection

### 4. Configure Voice Agent App

#### Update Server URL in Settings

1. Open the Voice Agent app
2. Tap "Settings" (gear icon)
3. Tap "Server URL"
4. Enter your DGX Spark Tailscale URL:
   ```
   ws://dgx-spark.tail-scale.ts.net:8080
   ```
   Or if using Tailscale Serve:
   ```
   wss://dgx-spark.tail-scale.ts.net
   ```
5. Tap "Save"

#### Alternative: Edit Configuration.plist

Before building the app, edit `Configuration.plist`:

```xml
<key>DefaultServerURL</key>
<string>ws://dgx-spark.tail-scale.ts.net:8080</string>
```

Replace `dgx-spark` with your actual Tailscale hostname.

### 5. Verify Connection

#### On DGX Spark:

```bash
# Check Tailscale status
tailscale status

# Verify voice agent is running
curl http://localhost:8080/health

# Monitor connections
sudo tailscale debug watch-connections
```

#### On iPhone:

1. Open Tailscale app
2. Verify you see "dgx-spark" in the device list
3. Tap "Test" to ping the device
4. Open Voice Agent app
5. Tap "Settings" → "Test Connection"

## Troubleshooting

### Cannot Connect to DGX Spark

**Check Tailscale status on both devices:**
```bash
# On DGX Spark
tailscale status
```

In Tailscale iOS app, verify connection status is "Connected"

**Verify the hostname:**
```bash
# On DGX Spark
tailscale status | grep dgx-spark
```

Use the exact hostname shown in the URL.

**Check firewall rules:**
```bash
# On DGX Spark - ensure port 8080 is accessible locally
sudo netstat -tlnp | grep 8080
```

### WebSocket Connection Fails

**Test with curl:**
```bash
# From any machine on the Tailscale network
curl -i -N -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Host: dgx-spark.tail-scale.ts.net:8080" \
  http://dgx-spark.tail-scale.ts.net:8080/
```

**Check Pipecat logs:**
```bash
# On DGX Spark
docker logs <pipecat-container-id>
```

### SSL/TLS Errors with wss://

If using `wss://` and getting SSL errors:

1. Use Tailscale Serve (automatically handles HTTPS)
2. Or fall back to `ws://` (still encrypted via Tailscale VPN)

### High Latency

**Check ping times:**
```bash
# On iPhone (in Tailscale app)
Tap device → Test connectivity
```

**Optimize Tailscale:**
```bash
# On DGX Spark - enable subnet routing if needed
sudo tailscale up --accept-routes
```

## Security Considerations

### Tailscale VPN Encryption

All traffic over Tailscale is encrypted with WireGuard, even if using `ws://` (not `wss://`). The connection security layers are:

1. **WireGuard encryption** (Tailscale VPN layer)
2. **Optional TLS** (if using `wss://`)

Using `ws://` over Tailscale is secure because the VPN encrypts all traffic.

### Access Control

Configure Tailscale ACLs to restrict access:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:iphone"],
      "dst": ["tag:dgx-spark:8080"]
    }
  ]
}
```

Apply in Tailscale admin console: https://login.tailscale.com/admin/acls

### Best Practices

1. **Enable MagicDNS** in Tailscale settings for easier hostname resolution
2. **Use Tailscale Serve** for production deployments (automatic HTTPS)
3. **Set up key expiry notifications** to avoid connection failures
4. **Enable "On Demand"** in iOS Tailscale app for automatic reconnection
5. **Monitor logs** for connection issues

## Alternative: Cloudflare Tunnel

If you prefer not to use Tailscale, you can use Cloudflare Tunnel:

```bash
# On DGX Spark
cloudflared tunnel --url http://localhost:8080
```

Then connect to the provided Cloudflare URL. Note: This adds latency compared to Tailscale's direct peer-to-peer connections.

## Advanced Configuration

### Custom DNS

If your DGX Spark has a custom hostname:

```bash
# On DGX Spark
sudo tailscale set --hostname my-custom-name
```

Use in app: `ws://my-custom-name.tail-scale.ts.net:8080`

### Multiple Environments

Configure different URLs for dev/staging/production in `Configuration.plist`:

```xml
<key>LocalServerURL</key>
<string>ws://localhost:8080</string>

<key>DefaultServerURL</key>
<string>ws://dgx-spark.tail-scale.ts.net:8080</string>

<key>ProductionServerURL</key>
<string>wss://dgx-spark-prod.tail-scale.ts.net</string>
```

## Support

- Tailscale Documentation: https://tailscale.com/kb/
- Tailscale Support: https://tailscale.com/contact/support
- Voice Agent Issues: See README.md

## Next Steps

After Tailscale is configured:

1. ✅ Test WebSocket connection
2. ✅ Start voice conversation
3. ✅ Configure n8n webhooks (see N8N_INTEGRATION.md)
4. ✅ Set up VoIP push notifications (see VOIP_SETUP.md)
