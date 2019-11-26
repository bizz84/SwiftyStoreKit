Pod::Spec.new do |s|
  s.name         = 'SwiftyStoreKit'
  s.version      = '0.15.0'
  s.summary      = 'Lightweight In App Purchases Swift framework for iOS 8.0+, tvOS 9.0+ and OSX 10.10+'
  s.license      = 'MIT'
  s.homepage     = 'https://github.com/lampateam/SwiftyStoreKit'
  s.author       = { 'Andrea Bizzotto' => 'bizz84@gmail.com' }
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.swift_version = '5.0'
  s.source       = { :git => "https://github.com/lampateam/SwiftyStoreKit.git", branch: 'master' }
c7772a36f47dacd0052c16104b3a65c64c4ab896
  s.source_files = 'SwiftyStoreKit/*.{swift}'

  s.screenshots  = ["https://github.com/lampateam/SwiftyStoreKit/raw/master/Screenshots/Preview.jpg"]

  s.requires_arc = true
end
