# VoIP Push Notifications Setup Guide

This guide explains how to configure VoIP push notifications for the Voice Agent iOS app, enabling incoming call functionality when the app is in the background.

## Overview

VoIP push notifications allow your iOS app to:
- Wake from background when receiving an incoming call
- Display native CallKit call UI
- Start voice agent conversation immediately

## Architecture

```
n8n Workflow (Raspberry Pi)
    ↓ (trigger)
APNs Service (your backend)
    ↓ (VoIP push)
Apple Push Notification Service (APNs)
    ↓ (push notification)
iPhone (Voice Agent app)
    ↓ (wake app)
CallKit Provider (show incoming call)
    ↓ (user answers)
Voice Agent (start conversation)
```

## Prerequisites

1. Apple Developer account ($99/year)
2. Backend server for sending push notifications (can be n8n with HTTP node)
3. VoIP Services certificate from Apple
4. Device token from the app

## Step 1: Create VoIP Certificate

### A. In Apple Developer Portal

1. Go to https://developer.apple.com/account/resources/certificates
2. Click **+** to create new certificate
3. Select **VoIP Services Certificate**
4. Click **Continue**
5. Select your App ID (e.g., `com.yourcompany.voiceagent`)
6. Upload a Certificate Signing Request (CSR)
   - Open **Keychain Access** on Mac
   - Menu: Certificate Assistant → Request a Certificate from a Certificate Authority
   - Enter your email and name
   - Select "Saved to disk"
   - Click Continue and save the `.certSigningRequest` file
7. Upload the CSR file
8. Download the `.cer` certificate file

### B. Convert Certificate to .p12

```bash
# In Keychain Access, find the certificate you just added
# Right-click → Export "Apple Push Services: com.yourcompany.voiceagent"
# Save as: voip_certificate.p12
# Set a password (remember it!)
```

Or via command line:
```bash
# Convert .cer to .pem
openssl x509 -in voip_certificate.cer -inform DER -out voip_cert.pem

# Export private key from keychain
# Find the private key in Keychain Access, export as .p12

# Or combine both
openssl pkcs12 -in voip_certificate.p12 -out voip_cert.pem -nodes
```

## Step 2: Update App Capabilities

The app already includes VoIP capability in `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
</array>
```

And in `VoiceAgentApp.entitlements`:

```xml
<key>com.apple.developer.pushkit</key>
<true/>
```

Verify in Xcode:
1. Select project → Target → Signing & Capabilities
2. Ensure **Background Modes** includes "Voice over IP"
3. Ensure **Push Notifications** capability is added

## Step 3: Get Device Token

The app automatically registers for VoIP push in `AppDelegate.swift`:

```swift
func registerForVoIPPushes() {
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]
}
```

### Retrieve Token

1. Run the app on a **physical device** (simulator doesn't support VoIP push)
2. Check Xcode console for output:
   ```
   VoIP device token: a1b2c3d4e5f6...
   ```
3. Copy this token

### Send Token to Backend

The app posts token to `NotificationCenter`:

```swift
NotificationCenter.default.addObserver(forName: .voipTokenReceived) { notification in
    let token = notification.object as! String

    // TODO: Send to your backend
    sendTokenToBackend(token)
}
```

Implement `sendTokenToBackend()` to store the token on your server:

```swift
func sendTokenToBackend(_ token: String) {
    let url = URL(string: "https://your-backend.com/api/register-device")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["device_token": token, "user_id": "your-user-id"]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request).resume()
}
```

## Step 4: Set Up APNs Backend Service

### Option A: Python with apns2 Library

Install dependencies:
```bash
pip install apns2
```

Create APNs service:

```python
# voip_push_service.py
from apns2.client import APNsClient
from apns2.payload import Payload

class VoIPPushService:
    def __init__(self, cert_path: str, use_sandbox: bool = False):
        """
        Initialize APNs client

        Args:
            cert_path: Path to .p12 certificate file
            use_sandbox: True for development, False for production
        """
        self.client = APNsClient(
            cert_path,
            use_sandbox=use_sandbox,
            use_alternative_port=False
        )
        self.topic = 'com.yourcompany.voiceagent.voip'  # Your bundle ID + .voip

    def send_call_notification(self, device_token: str, caller_name: str = "Voice Assistant", context: str = None):
        """
        Send VoIP push notification

        Args:
            device_token: Device token from iOS app
            caller_name: Name to display in CallKit UI
            context: Optional context for the call
        """
        payload_data = {
            'caller': caller_name,
            'type': 'voice_call'
        }

        if context:
            payload_data['context'] = context

        payload = Payload(custom=payload_data)

        try:
            self.client.send_notification(device_token, payload, self.topic)
            print(f"VoIP push sent to {device_token[:8]}...")
            return True
        except Exception as e:
            print(f"Failed to send VoIP push: {e}")
            return False

# Usage
if __name__ == '__main__':
    service = VoIPPushService('/path/to/voip_cert.p12', use_sandbox=True)
    service.send_call_notification(
        device_token='a1b2c3d4e5f6...',
        caller_name='Voice Assistant',
        context='Calendar reminder: Meeting in 5 minutes'
    )
```

### Option B: Node.js with apn Library

Install dependencies:
```bash
npm install apn
```

Create service:

```javascript
// voipPushService.js
const apn = require('apn');

class VoIPPushService {
    constructor(certPath, keyPath, isProduction = false) {
        this.provider = new apn.Provider({
            cert: certPath,
            key: keyPath,
            production: isProduction
        });
        this.topic = 'com.yourcompany.voiceagent.voip';
    }

    async sendCallNotification(deviceToken, callerName = 'Voice Assistant', context = null) {
        const notification = new apn.Notification();
        notification.topic = this.topic;
        notification.pushType = 'voip';
        notification.payload = {
            caller: callerName,
            type: 'voice_call'
        };

        if (context) {
            notification.payload.context = context;
        }

        try {
            const result = await this.provider.send(notification, deviceToken);
            console.log('VoIP push sent:', result);
            return true;
        } catch (error) {
            console.error('Failed to send VoIP push:', error);
            return false;
        }
    }
}

// Usage
const service = new VoIPPushService(
    '/path/to/voip_cert.pem',
    '/path/to/voip_key.pem',
    false  // sandbox mode
);

service.sendCallNotification(
    'a1b2c3d4e5f6...',
    'Voice Assistant',
    'You have a new message'
);
```

## Step 5: Integrate with n8n

### n8n Workflow Example

Create a workflow that triggers VoIP push:

1. **Trigger Node**: Webhook, Schedule, or any trigger
2. **HTTP Request Node**: Call your APNs service

#### HTTP Request Node Configuration:

```json
{
  "method": "POST",
  "url": "http://localhost:5000/send-voip-push",
  "authentication": "none",
  "sendBody": true,
  "bodyParameters": {
    "device_token": "{{$json.device_token}}",
    "caller_name": "Voice Assistant",
    "context": "{{$json.message}}"
  }
}
```

### Simple Flask Server for n8n

```python
# voip_server.py
from flask import Flask, request, jsonify
from voip_push_service import VoIPPushService

app = Flask(__name__)
voip_service = VoIPPushService('/path/to/voip_cert.p12', use_sandbox=True)

# Store device tokens (use database in production)
device_tokens = {}

@app.route('/register-device', methods=['POST'])
def register_device():
    """Register device token from iOS app"""
    data = request.json
    user_id = data.get('user_id')
    device_token = data.get('device_token')

    device_tokens[user_id] = device_token
    return jsonify({'status': 'success'})

@app.route('/send-voip-push', methods=['POST'])
def send_voip_push():
    """Endpoint for n8n to trigger VoIP push"""
    data = request.json
    device_token = data.get('device_token')
    caller_name = data.get('caller_name', 'Voice Assistant')
    context = data.get('context')

    if not device_token:
        # Get token by user_id if provided
        user_id = data.get('user_id')
        device_token = device_tokens.get(user_id)

    if not device_token:
        return jsonify({'error': 'No device token provided'}), 400

    success = voip_service.send_call_notification(device_token, caller_name, context)

    if success:
        return jsonify({'status': 'sent'})
    else:
        return jsonify({'error': 'Failed to send push'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

Run the server:
```bash
python voip_server.py
```

## Step 6: Test VoIP Push

### Test from Command Line

Using curl:
```bash
curl -X POST http://localhost:5000/send-voip-push \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_DEVICE_TOKEN",
    "caller_name": "Voice Assistant",
    "context": "Test call"
  }'
```

### Test from n8n

1. Create a test workflow:
   - **Manual Trigger** node
   - **HTTP Request** node to your VoIP service
2. Execute the workflow
3. iPhone should show incoming call UI

### Expected Behavior

1. ✅ iPhone receives VoIP push (even if app is terminated)
2. ✅ App wakes in background
3. ✅ CallKit shows incoming call UI with caller name
4. ✅ User swipes to answer
5. ✅ Voice conversation starts automatically

## Troubleshooting

### No Push Received

**Check device token:**
```bash
# Must be 64 hexadecimal characters
echo "a1b2c3d4..." | wc -c  # Should be 64
```

**Verify certificate:**
```bash
# Check certificate expiration
openssl pkcs12 -in voip_cert.p12 -nokeys | openssl x509 -noout -dates
```

**Use sandbox vs production:**
- Development builds → use sandbox APNs
- TestFlight/App Store → use production APNs

**Check APNs response:**
Enable verbose logging in your APNs library to see error messages.

### App Doesn't Wake

**Ensure VoIP entitlement:**
- Check `VoiceAgentApp.entitlements` includes PushKit
- Rebuild app after adding entitlements

**Test on physical device:**
- VoIP push doesn't work on simulator
- Must use real iPhone

### CallKit Not Showing

**Verify CallKit implementation:**
```swift
// In AppDelegate.swift
func pushRegistry(_ registry: PKPushRegistry,
                  didReceiveIncomingPushWith payload: PKPushPayload,
                  for type: PKPushType,
                  completion: @escaping () -> Void) {
    print("Received VoIP push: \(payload.dictionaryPayload)")

    // MUST report to CallKit within timeout
    callKitProvider?.reportIncomingCall(caller: "...", context: "...") { error in
        completion()  // Always call completion handler
    }
}
```

**CallKit requires:**
1. Call `completion()` handler within timeout (~10 seconds)
2. Report call to `CXProvider` before timeout
3. Valid audio session configuration

### Testing Checklist

- [ ] Device token retrieved and sent to backend
- [ ] VoIP certificate valid and not expired
- [ ] Using correct APNs environment (sandbox/production)
- [ ] App has VoIP background mode enabled
- [ ] CallKit provider initialized before push received
- [ ] Completion handler called after reporting call
- [ ] Audio session configured for voice chat

## Production Considerations

### Security

**Protect device tokens:**
- Store encrypted in database
- Use HTTPS for token transmission
- Implement authentication for registration endpoint

**Validate push requests:**
- Authenticate requests from n8n
- Rate limit push notifications
- Log all push attempts

### Reliability

**Handle token expiration:**
```python
def send_with_retry(device_token, payload, retries=3):
    for attempt in range(retries):
        try:
            client.send_notification(device_token, payload, topic)
            return True
        except TokenExpired:
            # Remove token from database
            remove_device_token(device_token)
            return False
        except Exception as e:
            if attempt == retries - 1:
                raise
            time.sleep(2 ** attempt)  # Exponential backoff
```

**Monitor delivery:**
- Log successful/failed pushes
- Set up alerts for high failure rates
- Track delivery metrics

### Scaling

**Use APNs/2 HTTP/2 protocol:**
- Persistent connections
- Batch notifications
- Better error handling

**Consider push service providers:**
- AWS SNS
- Firebase Cloud Messaging (FCM)
- OneSignal

## Advanced Features

### Rich Notifications

Include additional data in payload:

```python
payload = Payload(
    custom={
        'caller': 'Voice Assistant',
        'context': 'Calendar reminder',
        'priority': 'high',
        'metadata': {
            'meeting_id': '12345',
            'participants': ['Alice', 'Bob']
        }
    }
)
```

Access in app:
```swift
func pushRegistry(_ registry: PKPushRegistry,
                  didReceiveIncomingPushWith payload: PKPushPayload,
                  for type: PKPushType) {
    let metadata = payload.dictionaryPayload["metadata"] as? [String: Any]
    // Use metadata to customize call experience
}
```

### Silent Wake

For background processing without showing call UI:

```python
# Send silent VoIP push
payload = Payload(custom={'type': 'silent_wake'})
```

```swift
// In app, don't report to CallKit for silent wake
if payload.type == "silent_wake" {
    // Do background work
    completion()
} else {
    // Report call to CallKit
}
```

## Resources

- [Apple PushKit Documentation](https://developer.apple.com/documentation/pushkit)
- [Apple CallKit Documentation](https://developer.apple.com/documentation/callkit)
- [APNs Overview](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [VoIP Best Practices](https://developer.apple.com/documentation/pushkit/responding_to_voip_notifications_from_pushkit)

## Next Steps

After VoIP push is working:

1. ✅ Test with n8n workflows
2. ✅ Implement conversation history
3. ✅ Add user authentication
4. ✅ Set up monitoring and logging
5. ✅ Deploy to production

---

**Note**: VoIP push notifications are subject to Apple review. Ensure your app legitimately uses them for voice calling purposes.
