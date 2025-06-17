Pod::Spec.new do |s|
  s.name             = 'Add-OTHER_LDFLAGS-ObjC'
  s.version          = '1.0.0'
  s.summary          = 'Add -ObjC by stating this is a static_framework'
  s.description      = 'Add -ObjC by stating this is a static_framework'
  s.platforms        = { :ios => '8.0' }
  s.authors = {
    'dummy' => 'user@example.com',
  }
  s.license = 'MIT'
  s.homepage = 'https://example.com'
  s.source = {
    :type => 'zip',
    :http => 'http://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.4.zip',
  }
  # This is why this file exists.
  # The project needs at least one static_framework so that Cocoapods
  # will include -ObjC in OTHER_LDFLAGS.
  # Note that -ObjC is so special that you cannot add it with post_install hook.
  # -ObjC can only be added this way.
  #
  # The reason why -ObjC is needed is documented here.
  # https://developers.weixin.qq.com/community/develop/article/doc/000e8e316d4590c7ef92ec1a366c13
  s.static_framework = true
  # Yes, this file does not actually exist, but Cocoapods does not complain.
  s.source_files = 'dummy.h'
end
