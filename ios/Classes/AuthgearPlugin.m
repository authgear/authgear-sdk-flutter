#import "AuthgearPlugin.h"
#if __has_include(<flutter_authgear/flutter_authgear-Swift.h>)
#import <flutter_authgear/flutter_authgear-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_authgear-Swift.h"
#endif

@implementation AuthgearPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAuthgearPlugin registerWithRegistrar:registrar];
}
@end
