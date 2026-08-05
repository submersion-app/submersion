Pod::Spec.new do |s|
  s.name             = 'submersion_transcoder'
  s.version          = '0.1.0'
  s.summary          = 'Native video transcoding for Submersion.'
  s.description      = 'AVFoundation H.264/AAC transcoding behind a Flutter channel.'
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
