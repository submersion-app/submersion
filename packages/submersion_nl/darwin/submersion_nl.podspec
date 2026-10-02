Pod::Spec.new do |s|
  s.name             = 'submersion_nl'
  s.version          = '0.1.0'
  s.summary          = 'On-device natural-language query compilation for Submersion.'
  s.description      = 'Apple Foundation Models with guided generation, behind a method channel.'
  s.homepage         = 'https://submersion.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Submersion' => 'dev@submersion.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.weak_frameworks = 'FoundationModels'
  s.swift_version = '5.9'
end
