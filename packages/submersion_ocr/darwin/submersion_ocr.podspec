Pod::Spec.new do |s|
  s.name             = 'submersion_ocr'
  s.version          = '0.1.0'
  s.summary          = 'On-device OCR for Submersion.'
  s.description      = 'Apple Vision text recognition returning positioned text blocks.'
  s.homepage         = 'https://submersion.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Submersion' => 'dev@submersion.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'
end
