# NVIDIA Voice Agent Blueprint: What It Provides vs What You Need

## TL;DR: Use the Blueprint as Your DGX Spark Backend

**The blueprint IS excellent and you SHOULD use it**—but it's only the server-side half. It provides the DGX Spark voice processing stack (ASR/LLM/TTS) achieving 465ms latency. You still need to build:
1. iOS app with Quick Action + CallKit integration
2. n8n/MCP integration for workflow automation  
3. Tailscale networking configuration
4. Notification/calling infrastructure

---

## What the Blueprint Provides (✓ Use This)

### Core Voice Processing Stack
- **Nemotron Speech ASR**: <24ms transcription latency via WebSocket
- **Nemotron 3 Nano 30B**: LLM optimized for DGX Spark (Q8 quantization)
- **Magpie TTS Preview**: Zero-shot multilingual synthesis
- **Pipecat orchestration**: Frame-based pipeline with SmartTurn detection
- **465ms voice-to-voice TTFB**: Measured and verified on DGX Spark/RTX 5090

### Deployment Options
- **Local Docker container**: 2-3 hour build, runs on DGX Spark/RTX 5090
- **Modal cloud deployment**: One-click deploy for ASR/TTS/LLM microservices
- **Pipecat Cloud**: Managed bot hosting with auto-scaling

### WebRTC Transport
- **Native WebRTC**: Browser-based client at localhost:7860
- **Daily.co integration**: For production telephony
- **Twilio connector**: For PSTN/SIP calling

### Developer Experience
- Pre-built Docker images with Blackwell (sm_121) CUDA support
- Management scripts (`./scripts/nemotron.sh start/stop/logs`)
- Automatic model downloads (ASR/TTS)
- Health check endpoints for all services
- Comprehensive logging and metrics (V2VMetricsProcessor)

---

## What the Blueprint Does NOT Provide (✗ You Must Build)

### 1. iOS Application
**What's missing:**
- No iOS app implementation (mentions Pipecat iOS SDK exists, doesn't provide one)
- No Quick Action button integration code
- No AVAudioEngine setup for voice capture
- No PushKit/CallKit integration for incoming calls
- No VoIP push notification handling
- No background audio session management
- No Tailscale connectivity code

**What you need to build:**
```swift
// iOS app using Pipecat iOS SDK (doesn't exist yet in blueprint)
import PipecatClientiOS  // This library exists but no example code
import AVFoundation
import PushKit
import CallKit

class VoiceAgentApp {
    // Connect to DGX Spark over Tailscale
    let wsURL = "wss://dgx-spark.tail-scale.ts.net:8080"
    
    // Set up Quick Action
    // Set up CallKit provider
    // Set up PushKit registration
    // Implement audio capture/playback
}
```

### 2. n8n Workflow Integration
**What's missing:**
- No n8n webhook integration
- No MCP server connectivity
- No function calling examples for automation
- No conversation state persistence to SQLite/Redis
- No example of LLM tool use triggering n8n workflows

**What you need to build:**
```python
# In your bot code - missing from blueprint
async def handle_tool_call(function_name: str, args: dict):
    if function_name == "trigger_automation":
        response = await httpx.post(
            "http://pi.local:5678/webhook/voice-agent",
            json=args
        )
        return response.json()

# Add to LLM tools
tools = [{
    "type": "function",
    "function": {
        "name": "trigger_automation",
        "description": "Execute n8n workflow",
        "parameters": {...}
    }
}]
```

### 3. Networking & Security
**What's missing:**
- No Tailscale configuration
- No authentication/authorization
- No rate limiting
- No TLS certificate management
- iOS app must connect to unsecured ws:// endpoints (no wss://)

**What you need to build:**
```bash
# Tailscale setup (not in blueprint)
tailscale up --authkey=xxx
tailscale serve --bg wss:8080 http://localhost:8080

# Or use Cloudflare Tunnel / Let's Encrypt
certbot certonly --standalone -d dgx-spark.yourdomain.com
```

### 4. Notification & Calling Infrastructure
**What's missing:**
- No APNs integration for push notifications
- No server-side logic to initiate "calls" to iPhone
- No CallKit reporting code
- No VoIP push payload handling
- No n8n → iPhone notification bridge

**What you need to build:**
```python
# Server-side APNs integration (missing)
import apns2
async def notify_user(device_token: str, context: str):
    payload = {
        "aps": {"content-available": 1},
        "context": context
    }
    await apns_client.send(device_token, payload)

# Triggered by n8n workflow
@app.post("/notify_user")
async def notify_endpoint(request):
    await notify_user(request.device_token, request.message)
```

### 5. Production Features
**What's missing:**
- Conversation history persistence
- User authentication
- Multi-user support (blueprint is "single-user, local development")
- Session management across app restarts
- Error recovery and reconnection logic
- Monitoring and alerting
- Cost tracking for cloud deployments

---

## Recommended Implementation Strategy

### Phase 1: Adopt Blueprint Backend (Week 1-2)
Use the `pipecat-ai/nemotron-january-2026` repo **exactly as-is** for your DGX Spark:

```bash
# On DGX Spark
git clone https://github.com/pipecat-ai/nemotron-january-2026
cd nemotron-january-2026

# Build unified container (2-3 hours)
docker build -f Dockerfile.unified -t nemotron-unified:cuda13 .

# Download LLM model
huggingface-cli download unsloth/Nemotron-3-Nano-30B-A3B-GGUF

# Start services
./scripts/nemotron.sh start --mode llamacpp-q8

# Test with browser client
# Visit http://localhost:7860
```

**Validate 465ms latency** with the included Pipecat Playground client.

### Phase 2: Build iOS App (Week 3-4)
Create custom iOS app since blueprint doesn't provide one:

**Option A: Use Pipecat iOS SDK** (if you can find documentation)
- Search for `pipecat-client-ios` on GitHub
- Connect to `ws://dgx-spark-ip:8080` over Tailscale

**Option B: Custom WebSocket client**
```swift
import Starscream

class VoiceAgentClient {
    var socket: WebSocket!
    
    func connect(to url: String) {
        var request = URLRequest(url: URL(string: url)!)
        socket = WebSocket(request: request)
        socket.connect()
    }
    
    func sendAudio(_ data: Data) {
        socket.write(data: data)
    }
}
```

**Add Quick Action in Info.plist**:
```xml
<key>UIApplicationShortcutItems</key>
<array>
    <dict>
        <key>UIApplicationShortcutItemType</key>
        <string>StartVoiceAgent</string>
        <key>UIApplicationShortcutItemTitle</key>
        <string>Talk to Assistant</string>
    </dict>
</array>
```

### Phase 3: n8n Integration (Week 5-6)
Extend the blueprint's bot code to add n8n webhooks:

```python
# Add to pipecat_bots/bot_interleaved_streaming.py
import httpx

async def create_n8n_tools():
    """Create LLM tools that call n8n webhooks"""
    return [{
        "type": "function",
        "function": {
            "name": "check_calendar",
            "description": "Check calendar for upcoming events",
            "parameters": {
                "type": "object",
                "properties": {
                    "date": {"type": "string"}
                }
            }
        }
    }]

async def handle_function_call(name: str, args: dict):
    # Call n8n via Tailscale
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "http://pi.local:5678/webhook/voice-assistant",
            json={"function": name, "args": args}
        )
        return response.json()
```

### Phase 4: Notifications (Week 7-8)
Build APNs integration outside blueprint:

```python
# New file: notification_service.py (not in blueprint)
from apns2.client import APNsClient
from apns2.payload import Payload

apns_client = APNsClient('/path/to/cert.pem')

async def trigger_voice_call(device_token: str):
    payload = Payload(
        custom={'caller': 'Voice Assistant'},
        content_available=True
    )
    apns_client.send_notification(device_token, payload, topic='com.yourapp.voip')
```

**Connect to n8n**: Add HTTP Request node calling your APNs service when workflows need user interaction.

---

## Why Not "Just Follow the Blueprint"?

### The Blueprint IS Your Foundation
The blueprint provides:
- ✓ Optimized inference stack (465ms validated)
- ✓ Correct CUDA versions for Blackwell
- ✓ Working WebRTC transport
- ✓ Production-tested Pipecat integration
- ✓ Model quantization choices (Q8 vs Q4 vs BF16)

**You should absolutely use this** for your DGX Spark backend.

### The Blueprint Stops at the Server Edge
The blueprint assumes:
- Client connects via web browser (Pipecat Playground UI)
- Single-user development environment
- WebSocket transport over localhost
- No authentication or workflow integration

For your requirements, you need:
- Native iOS app (not web browser)
- VPN-secured connection over Tailscale (not localhost)
- PushKit/CallKit for "incoming calls"
- n8n workflow triggers from voice
- Multi-device coordination (iPhone → DGX Spark → Raspberry Pi n8n)

---

## Cost Comparison

### Using Blueprint as-is
- **Hardware**: DGX Spark (already owned)
- **Development**: 0 hours (just run it)
- **Testing**: 1-2 hours
- **Operational**: $0/month (fully local)

### Building Complete System
- **Hardware**: DGX Spark + iOS device (already owned)
- **Development**: 6-8 weeks for iOS app + integrations
- **Operational**: $0/month (still fully local)
- **Apple Developer**: $99/year (for APNs certificates)

---

## Final Recommendation

**YES, follow the NVIDIA Blueprint exactly—for the DGX Spark backend.**

The blueprint is the definitive reference for:
1. Running Nemotron models on DGX Spark at optimal latency
2. Configuring Pipecat for real-time voice
3. Managing the Docker container lifecycle
4. Deploying to Modal if you need cloud scale

But recognize it's **50% of your system**. The iOS app, n8n integration, and notification infrastructure are **outside the blueprint's scope** and require custom development.

### Implementation Roadmap

| Phase | Use Blueprint | Custom Development |
|-------|---------------|-------------------|
| **Backend** | ✓ Use as-is | Extend with n8n webhook handlers |
| **iOS App** | - | Build from scratch using Pipecat iOS SDK or WebSocket |
| **Notifications** | - | Build APNs service + n8n integration |
| **Networking** | - | Configure Tailscale + certificates |

The blueprint gives you the hardest part (optimized voice processing on Blackwell GPUs). The integration work—while significant—is standard iOS/webhook development that doesn't require ML expertise.
