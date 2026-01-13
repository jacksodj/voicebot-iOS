# Xcode Project Setup Instructions

This guide walks you through creating the Xcode project for the Voice Agent iOS app using the source files provided in this repository.

## Prerequisites

- macOS Ventura or later
- Xcode 14.0 or later
- Apple Developer account (for device testing and VoIP features)

## Step 1: Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **iOS** → **App**
4. Click **Next**

### Project Configuration:

- **Product Name**: `VoiceAgentApp`
- **Team**: Select your Apple Developer team
- **Organization Identifier**: `com.yourcompany` (use your own)
- **Bundle Identifier**: `com.yourcompany.voiceagent`
- **Interface**: **Storyboard** (we'll use programmatic UI)
- **Language**: **Swift**
- **Storage**: None
- **Include Tests**: Yes (recommended)

5. Click **Next**
6. Choose save location: This repository root (`voicebot-iOS/`)
7. Click **Create**

## Step 2: Remove Default Files

Xcode creates some default files we won't use:

1. Select these files in Project Navigator and delete (Move to Trash):
   - `ViewController.swift` (we have our own)
   - `Main.storyboard` (using programmatic UI)
   - `SceneDelegate.swift` (we'll replace it)
   - `AppDelegate.swift` (we'll replace it)

## Step 3: Add Source Files to Project

### Drag and Drop Method:

1. In Finder, navigate to this repository
2. Select all folders with Swift files:
   - `VoiceAgentApp/` folder
3. Drag into Xcode Project Navigator
4. In the dialog:
   - ✅ **Copy items if needed**
   - ✅ **Create groups**
   - ✅ Select **VoiceAgentApp** target
5. Click **Finish**

### Manual File Addition:

Alternatively, add files one by one:

1. Right-click on project → Add Files to "VoiceAgentApp"
2. Navigate to each folder and add:

**Root Level:**
- `AppDelegate.swift`
- `SceneDelegate.swift`

**Manager/**
- `VoiceAgentManager.swift`

**Networking/**
- `WebSocketClient.swift`

**Audio/**
- `AudioEngine.swift`

**CallKit/**
- `VoiceCallProvider.swift`

**ViewControllers/**
- `MainViewController.swift`
- `SettingsViewController.swift`

## Step 4: Add Configuration Files

### Info.plist

1. Select existing `Info.plist` in Project Navigator
2. Delete it
3. Add the `VoiceAgentApp/Info.plist` from this repo
   - Right-click project → Add Files
   - Select `Info.plist`
   - Ensure target is selected

### Entitlements File

1. File → New → File
2. Select **Property List**
3. Name it: `VoiceAgentApp.entitlements`
4. Delete the new file content
5. Copy content from `VoiceAgentApp.entitlements` in repo

Or simply:
1. Add Files → Select `VoiceAgentApp.entitlements`

### Configuration.plist

1. Add Files → Select `Configuration.plist`
2. Ensure "Add to targets: VoiceAgentApp" is checked

## Step 5: Configure Project Settings

### A. General Settings

1. Select project in Navigator
2. Select **VoiceAgentApp** target
3. Go to **General** tab

**Identity:**
- Display Name: `Voice Agent`
- Bundle Identifier: `com.yourcompany.voiceagent`
- Version: `1.0`
- Build: `1`

**Deployment Info:**
- iOS Deployment Target: `15.0`
- iPhone orientation: ✅ Portrait
- iPad orientation: All
- Status Bar Style: Default

### B. Signing & Capabilities

1. Go to **Signing & Capabilities** tab
2. Select your Team
3. ✅ Automatically manage signing

**Add Capabilities:**

Click **+ Capability** and add:

1. **Background Modes**
   - ✅ Audio, AirPlay, and Picture in Picture
   - ✅ Voice over IP

2. **Push Notifications**
   - (Just add the capability, no configuration needed)

### C. Build Settings

1. Go to **Build Settings** tab
2. Search for "Info.plist File"
3. Set path to: `VoiceAgentApp/Info.plist`
4. Search for "Code Signing Entitlements"
5. Set path to: `VoiceAgentApp.entitlements`

### D. Remove Storyboard Reference

1. Select **Info** tab
2. Find "Application Scene Manifest"
3. Expand → Scene Configuration → Application Session Role → Item 0
4. Delete the "Storyboard Name" row (if present)

Or in Info.plist source:
```xml
<!-- Remove this line if present -->
<key>UISceneStoryboardFile</key>
<string>Main</string>
```

## Step 6: Update Build Phases

1. Go to **Build Phases** tab
2. Expand **Copy Bundle Resources**
3. Ensure these are included:
   - `Configuration.plist`
   - `Info.plist` should NOT be here (it's automatic)

## Step 7: Install Dependencies (Optional)

If using CocoaPods:

```bash
cd /path/to/voicebot-iOS

# Initialize Podfile (or use the one provided)
pod init

# Or copy the provided Podfile
cp Podfile Podfile.backup  # if you already have one

# Install pods
pod install
```

**Important**: After running `pod install`, always use `VoiceAgentApp.xcworkspace` instead of `.xcodeproj`

If not using CocoaPods, skip this step (URLSession WebSocket is built-in).

## Step 8: Fix Import Issues

The app uses iOS built-in frameworks. Ensure imports are present in each file:

**AppDelegate.swift:**
```swift
import UIKit
import PushKit
import CallKit
import AVFoundation  // Add if missing
```

**AudioEngine.swift:**
```swift
import Foundation
import AVFoundation
```

**All other files** should compile without additional imports.

## Step 9: Build and Run

### Build for Simulator (Limited Testing):

1. Select simulator: iPhone 15 Pro
2. Product → Build (⌘B)
3. Fix any build errors (usually import issues)

**Note**: VoIP push and CallKit work differently on simulator.

### Build for Physical Device (Recommended):

1. Connect iPhone via USB
2. Trust the computer on iPhone if prompted
3. Select your iPhone in device dropdown
4. Product → Run (⌘R)
5. If "Untrusted Developer" error:
   - iPhone: Settings → General → VPN & Device Management
   - Trust your developer certificate

## Step 10: Grant Permissions

On first run, grant permissions:

1. **Microphone**: Tap "Allow"
2. **Notifications**: Tap "Allow" (for VoIP push)

## Verification Checklist

After setup, verify:

- [ ] App builds successfully
- [ ] App launches without crashes
- [ ] Main view controller displays
- [ ] Settings button works
- [ ] Tapping "Start Conversation" shows microphone permission alert
- [ ] Quick Action appears (long-press app icon)
- [ ] Console shows "VoIP device token: ..." on physical device

## Common Build Errors

### "Cannot find 'VoiceAgentManager' in scope"

**Fix**: Ensure all Swift files are added to the target
1. Select file in Navigator
2. File Inspector (right panel) → Target Membership
3. ✅ Check VoiceAgentApp

### "Missing Info.plist"

**Fix**: Set Info.plist path in Build Settings
1. Build Settings → search "Info.plist"
2. Set to: `VoiceAgentApp/Info.plist`

### "Sandbox: rsync.samba deny(1) file-write-create"

**Fix**: Clean build folder
1. Product → Clean Build Folder (⇧⌘K)
2. Quit Xcode
3. Delete `~/Library/Developer/Xcode/DerivedData`
4. Reopen and rebuild

### "Entitlements file not found"

**Fix**: Create or add entitlements file
1. Ensure `VoiceAgentApp.entitlements` exists
2. Set path in Build Settings → Code Signing Entitlements

### "Could not find Developer Disk Image"

**Fix**: Update Xcode to match iOS version
1. Check iOS version on device
2. Update Xcode if necessary
3. Or downgrade iOS (not recommended)

## Project Structure After Setup

```
VoiceAgentApp/
├── VoiceAgentApp.xcodeproj
├── VoiceAgentApp.xcworkspace  (if using CocoaPods)
├── Podfile                     (if using CocoaPods)
├── Pods/                       (if using CocoaPods)
│
├── VoiceAgentApp/
│   ├── Info.plist
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── Manager/
│   │   └── VoiceAgentManager.swift
│   ├── Networking/
│   │   └── WebSocketClient.swift
│   ├── Audio/
│   │   └── AudioEngine.swift
│   ├── CallKit/
│   │   └── VoiceCallProvider.swift
│   └── ViewControllers/
│       ├── MainViewController.swift
│       └── SettingsViewController.swift
│
├── VoiceAgentApp.entitlements
├── Configuration.plist
│
└── Documentation/
    ├── README.md
    ├── TAILSCALE_SETUP.md
    ├── VOIP_SETUP.md
    └── XCODE_PROJECT_SETUP.md
```

## Next Steps

After successful build:

1. ✅ Configure Tailscale (see TAILSCALE_SETUP.md)
2. ✅ Set up DGX Spark backend (NVIDIA Blueprint)
3. ✅ Test WebSocket connection
4. ✅ Configure VoIP push notifications (see VOIP_SETUP.md)
5. ✅ Integrate with n8n workflows

## Troubleshooting Resources

- [Apple Developer Forums](https://developer.apple.com/forums/)
- [Stack Overflow - iOS](https://stackoverflow.com/questions/tagged/ios)
- [Xcode Release Notes](https://developer.apple.com/documentation/xcode-release-notes)

## Getting Help

If you encounter issues:

1. Check console logs in Xcode
2. Clean build folder and rebuild
3. Verify file paths in Build Settings
4. Ensure all files have target membership
5. Check iOS deployment target compatibility

---

**You're now ready to develop and test the Voice Agent iOS app!**
