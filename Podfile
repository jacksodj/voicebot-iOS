# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'VoiceAgentApp' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for VoiceAgentApp

  # WebSocket client (if you prefer a third-party library over URLSession)
  # pod 'Starscream', '~> 4.0'

  # Tailscale SDK (if available, check Tailscale documentation)
  # Note: Tailscale typically requires manual integration or system-level VPN

  # Logging
  # pod 'CocoaLumberjack/Swift', '~> 3.8'

  # JSON parsing (optional, Foundation has built-in support)
  # pod 'SwiftyJSON', '~> 5.0'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
