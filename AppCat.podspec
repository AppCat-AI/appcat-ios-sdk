Pod::Spec.new do |s|
  s.name         = "AppCat"
  s.version      = "0.1.0"
  s.summary      = "AppCat iOS SDK — deferred deep link resolution and attribution"
  s.homepage     = "https://github.com/AppCat-AI/appcat-ios-sdk"
  s.license      = { :type => "MIT" }
  s.author       = "AppCat"
  s.source       = { :git => "https://github.com/AppCat-AI/appcat-ios-sdk.git", :tag => s.version }

  s.platform     = :ios, "13.0"
  s.swift_version = "5.10"

  s.source_files = "Sources/AppCat/**/*.swift"

  # Closed-source core binary
  s.vendored_frameworks = "AppCatCoreKit.xcframework"

  # Optional frameworks for device signal collection
  s.weak_frameworks = [
    "AdSupport",
    "AppTrackingTransparency",
    "AdServices",
    "CoreTelephony",
  ]
end
