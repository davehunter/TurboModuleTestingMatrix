//#import <ReactCommon/RCTTurboModule.h>

#include "RTNTestableModule.h"
#import "RCTTurboModule.h"

@interface NativeRTNTestableModuleProvider : NSObject <RCTModuleProvider>
@end

@implementation NativeRTNTestableModuleProvider

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::RTNTestableModule>(params.jsInvoker);
}

@end
