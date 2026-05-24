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
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'
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

  # Build libdivecomputer from source before compiling Swift.
  # No :output_files on purpose: with an output declared and no inputs, Xcode
  # skips this phase whenever build/libdivecomputer.a already exists, so a
  # patched source (e.g. the Swift GPS exit fix) would never be recompiled.
  # build_libdc.sh does its own source-freshness check, so always running it is
  # cheap when nothing changed.
  s.script_phase = {
    :name => 'Build libdivecomputer',
    :script => '"${PODS_TARGET_SRCROOT}/build_libdc.sh"',
    :execution_position => :before_compile,
  }
end
