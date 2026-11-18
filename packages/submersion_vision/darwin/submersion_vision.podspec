Pod::Spec.new do |s|
  s.name             = 'submersion_vision'
  s.version          = '0.1.0'
  s.summary          = 'On-device marine life detection for Submersion.'
  s.description      = 'Runs a fish detector and an image embedding model with Core ML.'
  s.homepage         = 'https://submersion.app'
  s.license          = { :type => 'GPL-3.0' }
  s.author           = { 'Submersion' => 'dev@submersion.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.frameworks = 'CoreML', 'ImageIO', 'CoreGraphics'
  s.swift_version = '5.9'
end
