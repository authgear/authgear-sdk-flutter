Pod::Spec.new do |s|
  s.name             = 'flutter_authgear'
  s.version          = '0.1.0'
  s.summary          = 'Authgear SDK for Flutter'
  s.description      = 'Authgear SDK for Flutter'
  s.homepage         = 'https://www.authgear.com'
  s.license          = 'Apache-2.0'
  s.author           = { 'Louis Chan' => 'louischan@oursky.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
