Pod::Spec.new do |s|
  s.name             = "Nexinsight"
  s.version          = "0.1.9"
  s.summary          = "Nexinsight iOS SDK for tracking events in your app."
  s.description      = <<-DESC
    Nexinsight iOS SDK. Prebuilt static xcframework that lets iOS apps send screen, session and custom events to Nexinsight.
    Ships device (arm64) and simulator (arm64, x86_64) slices.
  DESC

  s.homepage         = "https://nexinsight.com.ua"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Alex Budyak" => "a.budyak@nexinsight.com.ua" }
  s.social_media_url = "https://www.linkedin.com/company/nexinsight"

  # The xcframework lives in this repo; a git tag equal to s.version marks each release.
  s.source           = { :git => "https://github.com/Nexinsight/ios-sdk.git", :tag => s.version.to_s }

  s.ios.deployment_target = "13.0"

  s.vendored_frameworks = "Nexinsight.xcframework"
  s.static_framework    = true
  
  s.module_name = "Nexinsight"

  s.frameworks = "Foundation"
  s.libraries  = "sqlite3"

  s.requires_arc = true
end
