Pod::Spec.new do |s|
  s.name             = 'libdivecomputer_plugin'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin wrapping libdivecomputer'
  s.homepage         = 'https://github.com/submersion/submersion'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Submersion' => 'dev@submersion.app' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{swift,c,h}'
  s.public_header_files = 'Classes/libdc_wrapper.h'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '11.0'
  s.swift_version    = '5.9'

  # Preserve libdivecomputer source and config for build script
  s.preserve_paths   = '../third_party/libdivecomputer/**/*', 'config/**/*', 'build_libdc.sh'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/../third_party/libdivecomputer/include"',
      '"$(PODS_TARGET_SRCROOT)/config"',
    ].join(' '),
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/build"',
    'OTHER_LDFLAGS' => '-ldivecomputer',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  }

  # Build libdivecomputer from source before compiling Swift
  s.script_phase = {
    :name => 'Build libdivecomputer',
    :script => '"${PODS_TARGET_SRCROOT}/build_libdc.sh"',
    :execution_position => :before_compile,
  }
end
