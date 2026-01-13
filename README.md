# Voice Agent iOS App

A native iOS application that connects to NVIDIA DGX Spark running the Pipecat voice agent backend. Enables real-time voice conversations with AI using CallKit, PushKit, and Tailscale networking.

## Features

✅ **Real-time Voice Conversations** - Low-latency audio streaming to DGX Spark
✅ **Quick Action Integration** - Long-press app icon to start conversation
✅ **CallKit Integration** - Native incoming call UI
✅ **VoIP Push Notifications** - Background wake for incoming calls
✅ **Tailscale Connectivity** - Secure VPN connection to DGX Spark
✅ **Background Audio** - Continue conversations with app in background
✅ **Automatic Reconnection** - Handle network interruptions gracefully

## Architecture

```
┌─────────────────┐
│   iPhone App    │
│                 │
│  ┌───────────┐  │
│  │ CallKit   │  │ ← Native call UI
│  │ Provider  │  │
│  └───────────┘  │
│                 │
│  ┌───────────┐  │
│  │ Audio     │  │ ← Voice capture/playback
│  │ Engine    │  │
│  └───────────┘  │
│                 │
│  ┌───────────┐  │
│  │ WebSocket │  │ ← Real-time communication
│  │ Client    │  │
│  └───────────┘  │
└────────┬────────┘
         │ Tailscale VPN (encrypted)
         ↓
┌─────────────────┐
│   DGX Spark     │
│                 │
│  ┌───────────┐  │
│  │ Pipecat   │  │ ← Voice agent orchestration
│  │ Backend   │  │
│  └───────────┘  │
│                 │
│  ┌───────────┐  │
│  │ Nemotron  │  │ ← ASR/LLM/TTS
│  │ Models    │  │
│  └───────────┘  │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Raspberry Pi   │
│  ┌───────────┐  │
│  │   n8n     │  │ ← Workflow automation
│  │ Workflows │  │
│  └───────────┘  │
└─────────────────┘
```

## Prerequisites

### Hardware
- iPhone with iOS 15.0 or later
- DGX Spark (or RTX 5090 system) running NVIDIA Blueprint
- Optional: Raspberry Pi for n8n automation

### Software
- Xcode 14.0 or later
- macOS Ventura or later (for development)
- Tailscale account (free tier)
- Apple Developer account ($99/year for VoIP push certificates)

### Backend
- NVIDIA Pipecat voice agent running on DGX Spark
- Follow the NVIDIA Blueprint: https://github.com/pipecat-ai/nemotron-january-2026

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/voicebot-iOS.git
cd voicebot-iOS
```

### 2. Install Dependencies (Optional)

If using CocoaPods for additional libraries:

```bash
cd voicebot-iOS
pod install
```

### 3. Open in Xcode

```bash
# If using CocoaPods
open VoiceAgentApp.xcworkspace

# Otherwise
open VoiceAgentApp.xcodeproj
```

### 4. Configure Bundle Identifier

1. Select the project in Xcode
2. Select "VoiceAgentApp" target
3. Change Bundle Identifier to your unique identifier:
   ```
   com.yourcompany.voiceagent
   ```

### 5. Update Team and Signing

1. Go to "Signing & Capabilities" tab
2. Select your Apple Developer team
3. Enable "Automatically manage signing"

### 6. Configure Capabilities

Ensure these capabilities are enabled:
- ✅ Background Modes → Audio, Voice over IP
- ✅ Push Notifications
- ✅ Network Extensions (for Tailscale)

### 7. Configure Server URL

Edit `Configuration.plist` and set your DGX Spark Tailscale hostname:

```xml
<key>DefaultServerURL</key>
<string>ws://your-dgx-spark.tail-scale.ts.net:8080</string>
```

Or configure at runtime in Settings screen.

### 8. Set Up Tailscale

Follow the complete guide: [TAILSCALE_SETUP.md](TAILSCALE_SETUP.md)

Quick steps:
```bash
# On DGX Spark
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Note the hostname
tailscale status
```

Install Tailscale on iPhone from App Store.

### 9. Build and Run

1. Connect iPhone to Mac
2. Select iPhone as target device
3. Press ⌘R to build and run

## Usage

### Starting a Conversation

#### Method 1: Quick Action
1. Long-press the Voice Agent app icon
2. Tap "Talk to Assistant"
3. Grant microphone permission if prompted
4. Start speaking

#### Method 2: In-App Button
1. Open Voice Agent app
2. Tap "Start Conversation"
3. Speak naturally

### Receiving Incoming Calls

When n8n triggers a notification:
1. iPhone shows CallKit incoming call UI
2. Swipe to answer
3. Conversation starts automatically

### Settings

Access via gear icon in top-right:
- **Server URL** - Change DGX Spark WebSocket endpoint
- **Test Connection** - Verify connectivity
- **Audio Configuration** - View current settings
- **Documentation** - Quick reference guide

## Project Structure

```
VoiceAgentApp/
├── Info.plist                    # App configuration, Quick Actions
├── AppDelegate.swift             # App lifecycle, PushKit registration
├── SceneDelegate.swift           # Scene management, Quick Action handling
│
├── Manager/
│   └── VoiceAgentManager.swift   # Main coordinator
│
├── Networking/
│   └── WebSocketClient.swift     # WebSocket communication
│
├── Audio/
│   └── AudioEngine.swift         # Voice capture & playback
│
├── CallKit/
│   └── VoiceCallProvider.swift   # CallKit integration
│
└── ViewControllers/
    ├── MainViewController.swift   # Main UI
    └── SettingsViewController.swift  # Settings UI

Configuration Files:
├── Configuration.plist           # App configuration
├── VoiceAgentApp.entitlements    # iOS capabilities
├── Podfile                       # Dependencies (optional)
└── TAILSCALE_SETUP.md           # Tailscale guide
```

## Key Components

### VoiceAgentManager
Central coordinator managing:
- WebSocket connection lifecycle
- Audio capture and playback
- CallKit integration
- Message routing

### WebSocketClient
- URLSession-based WebSocket client
- Automatic reconnection with exponential backoff
- Binary audio data and JSON text message support
- Connection state management

### AudioEngine
- AVAudioEngine-based audio processing
- 16kHz mono PCM capture (optimized for speech)
- Real-time audio streaming
- Playback of TTS audio from server

### VoiceCallProvider
- CXProvider for CallKit integration
- Incoming call reporting
- Call state management
- Native iOS call UI

## Configuration Options

### Server URLs

Configure in `Configuration.plist` or Settings:

```xml
<!-- Default (Tailscale) -->
<key>DefaultServerURL</key>
<string>ws://dgx-spark.tail-scale.ts.net:8080</string>

<!-- Local Development -->
<key>LocalServerURL</key>
<string>ws://localhost:8080</string>

<!-- Production (with SSL) -->
<key>ProductionServerURL</key>
<string>wss://dgx-spark.yourdomain.com:8080</string>
```

### Audio Settings

```xml
<key>SampleRate</key>
<integer>16000</integer>  <!-- 16kHz for speech -->

<key>Channels</key>
<integer>1</integer>  <!-- Mono -->

<key>Format</key>
<string>pcm_s16le</string>  <!-- PCM 16-bit -->
```

## VoIP Push Notifications

For receiving incoming calls when app is in background:

### 1. Create VoIP Certificate

1. Go to Apple Developer Portal → Certificates
2. Create "VoIP Services Certificate"
3. Download and install in Keychain
4. Export as `.p12` file

### 2. Configure Backend

Send VoIP pushes from your n8n workflow or backend:

```python
from apns2.client import APNsClient
from apns2.payload import Payload

client = APNsClient('/path/to/voip.p12', use_sandbox=False)
payload = Payload(custom={'caller': 'Voice Assistant'})
client.send_notification('device-token', payload, 'com.yourcompany.voiceagent.voip')
```

### 3. Handle Device Token

Device token is logged in console and posted to NotificationCenter:

```swift
NotificationCenter.default.addObserver(forName: .voipTokenReceived) { notification in
    let token = notification.object as! String
    // Send to your backend
}
```

## Troubleshooting

### Cannot Connect to DGX Spark

**Check Tailscale connection:**
- Open Tailscale app on iPhone
- Verify "Connected" status
- Check DGX Spark appears in device list

**Verify server URL:**
- Settings → Server URL
- Should be: `ws://hostname.tail-scale.ts.net:8080`
- Test with curl on another machine

**Check DGX Spark:**
```bash
# Verify Pipecat is running
docker ps | grep pipecat

# Check logs
docker logs <container-id>

# Test locally
curl http://localhost:8080/health
```

### Microphone Not Working

**Check permissions:**
- Settings → Privacy → Microphone → Voice Agent (ON)

**Verify audio session:**
- Check console logs for audio session errors
- Restart app after granting permission

### No Incoming Calls

**VoIP certificate required:**
- Create VoIP Services certificate in Apple Developer Portal
- Configure APNs in backend

**Check PushKit registration:**
- Console should show: "VoIP device token: ..."
- Send token to backend for push notifications

### Poor Audio Quality

**Check network latency:**
```bash
# Ping DGX Spark from iPhone (via Tailscale app)
Test Connectivity → your-dgx-spark
```

**Optimize Tailscale:**
- Enable "On Demand" in Tailscale app
- Use direct connection (not relay)
- Check Tailscale status shows "direct" connection

### High Latency

**Expected latency breakdown:**
- Network (Tailscale): 10-50ms
- Audio processing (DGX): 465ms (validated by NVIDIA)
- Total: ~500-550ms

**If higher:**
- Check Tailscale using direct connection (not relay)
- Verify DGX Spark not overloaded
- Test with local network first

## Development

### Building for Development

```bash
# Debug build
xcodebuild -project VoiceAgentApp.xcodeproj \
  -scheme VoiceAgentApp \
  -configuration Debug \
  -destination 'platform=iOS,name=Your iPhone' \
  build
```

### Running Tests

```bash
# Unit tests
xcodebuild test -project VoiceAgentApp.xcodeproj \
  -scheme VoiceAgentApp \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Logging

Enable debug logging in `Configuration.plist`:

```xml
<key>DebugLogging</key>
<true/>
```

View console in Xcode while app is running.

## Deployment

### TestFlight (Beta Testing)

1. Archive the app: Product → Archive
2. Upload to App Store Connect
3. Add to TestFlight
4. Invite testers via email

### App Store

Follow standard iOS app submission process. Note:
- VoIP push notifications require review justification
- Background audio must have clear user benefit
- Microphone usage description must be specific

## Security Considerations

### Network Security
- All traffic encrypted via Tailscale VPN (WireGuard)
- Even `ws://` is secure over Tailscale
- Optional TLS with `wss://` for defense-in-depth

### Data Privacy
- Audio data streamed only to your DGX Spark
- No data sent to third-party services
- VoIP pushes contain minimal metadata

### Access Control
- Configure Tailscale ACLs to restrict access
- Limit DGX Spark access to specific devices
- Use device authorization in Tailscale admin

## Performance

### Measured Latency
- **Network**: 10-50ms (Tailscale direct connection)
- **DGX Spark**: 465ms (ASR + LLM + TTS, per NVIDIA Blueprint)
- **Total**: ~500-550ms voice-to-voice

### Optimization Tips
1. Use direct Tailscale connections (not relay)
2. Keep DGX Spark on same LAN as Raspberry Pi
3. Use Q8 quantization (not Q4) for better quality
4. Enable audio preprocessing in AVAudioSession

## Integration with n8n

For workflow automation triggered by voice:

See planned n8n integration guide. Backend needs to:
1. Parse LLM function calls
2. Trigger n8n webhooks
3. Return results to voice agent

Example backend code needed:
```python
async def handle_tool_call(function_name: str, args: dict):
    response = await httpx.post(
        "http://pi.local:5678/webhook/voice-assistant",
        json={"function": function_name, "args": args}
    )
    return response.json()
```

## Roadmap

- [ ] Conversation history persistence
- [ ] Multi-user support
- [ ] Advanced audio preprocessing
- [ ] n8n workflow examples
- [ ] Widget for quick access
- [ ] Apple Watch companion app
- [ ] Siri Shortcuts integration

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly on physical device
4. Submit pull request with description

## License

[Your License Here]

## Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Documentation**: See `/docs` folder

## Credits

Built on top of:
- **NVIDIA Pipecat**: Voice agent orchestration
- **NVIDIA Nemotron**: ASR/LLM/TTS models
- **Tailscale**: Secure networking
- **Apple CallKit**: Native call integration

## References

- NVIDIA Blueprint: https://github.com/pipecat-ai/nemotron-january-2026
- Pipecat Documentation: https://docs.pipecat.ai
- Tailscale Documentation: https://tailscale.com/kb/
- Apple CallKit: https://developer.apple.com/documentation/callkit
- Apple PushKit: https://developer.apple.com/documentation/pushkit

---

**Built with ❤️ for real-time voice AI on iOS**
