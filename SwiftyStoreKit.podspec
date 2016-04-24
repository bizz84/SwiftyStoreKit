Pod::Spec.new do |s|
  s.name         = 'SwiftyStoreKit'
  s.version      = '0.2.6'
  s.summary      = 'Lightweight In App Purchases Swift framework for iOS 8.0+ and OSX 9.0+'
  s.license      = 'MIT'
  s.homepage     = 'https://github.com/bizz84/SwiftyStoreKit'
  s.author       = { 'Andrea Bizzotto' => 'bizz84@gmail.com' }
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'

  s.source       = { :git => "https://github.com/bizz84/SwiftyStoreKit.git", :tag => s.version }

  s.source_files = 'SwiftyStoreKit/*.{swift}'

  s.screenshots  = ["https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview.png","https://github.com/bizz84/SwiftyStoreKit/raw/master/Screenshots/Preview2.png"]

  s.requires_arc = true
end
