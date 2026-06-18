#include "RTNTestableModuleCxxPackage.h"
#include "RTNTestableModule.h"

namespace facebook::react {

jni::local_ref<RTNTestableModuleCxxPackage::jhybriddata>
RTNTestableModuleCxxPackage::initHybrid(jni::alias_ref<jclass> /*jClass*/) {
  return makeCxxInstance();
}

void RTNTestableModuleCxxPackage::registerNatives() {
  registerHybrid({
      makeNativeMethod("initHybrid", RTNTestableModuleCxxPackage::initHybrid),
  });
}

std::shared_ptr<TurboModule> RTNTestableModuleCxxPackage::getModule(
    const std::string &name,
    const std::shared_ptr<CallInvoker> &jsInvoker) {
  if (name == "NativeRTNTestableModule") {
    return std::make_shared<RTNTestableModule>(jsInvoker);
  }
  return nullptr;
}

} // namespace facebook::react
