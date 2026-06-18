#pragma once

#include <string>
#include <vector>

#include "NativeRTNTestableModuleJSI.h"

namespace facebook::react {

class RTNTestableModule : public NativeRTNTestableModuleCxxSpec<RTNTestableModule> {
 public:
  explicit RTNTestableModule(std::shared_ptr<CallInvoker> jsInvoker);

  std::string concat(
      jsi::Runtime &rt,
      const std::vector<double> &array,
      const std::string &separator);
};

std::shared_ptr<TurboModule> RTNTestableModuleModuleProvider(
    std::shared_ptr<CallInvoker> jsInvoker);

} // namespace facebook::react
