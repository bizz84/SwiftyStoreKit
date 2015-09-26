Pod::Spec.new do |s|
  s.name         = 'SwiftyStoreKit'
  s.version      = '0.1.2'
  s.summary      = 'Lightweight In App Purchases Swift framework for iOS 8.0+'
  s.license      = 'MIT'
  s.homepage     = 'https://github.com/bizz84/SwiftyStoreKit'
  s.author       = { 'Andrea Bizzotto' => 'bizz84@gmail.com' }
  s.ios.deployment_target = '8.0'

  s.source       = { :git => "https://github.com/bizz84/SwiftyStoreKit.git", :tag => s.version }

  s.source_files = 'SwiftyStoreKit/*.{swift}'

  s.screenshots  = []

  s.requires_arc = true
end
