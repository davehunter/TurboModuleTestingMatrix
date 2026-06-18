#pragma once

#include <fbjni/fbjni.h>
#include <ReactCommon/CxxReactPackage.h>

namespace facebook::react {

class RTNTestableModuleCxxPackage
    : public jni::HybridClass<RTNTestableModuleCxxPackage, CxxReactPackage> {
 public:
  static constexpr auto kJavaDescriptor =
      "Lcom/rtntestablemodule/RTNTestableModuleCxxPackage;";

  static jni::local_ref<jhybriddata> initHybrid(jni::alias_ref<jclass> jClass);
  static void registerNatives();

  std::shared_ptr<TurboModule> getModule(
      const std::string &name,
      const std::shared_ptr<CallInvoker> &jsInvoker) override;
};

} // namespace facebook::react
