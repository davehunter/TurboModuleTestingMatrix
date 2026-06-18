//
//  RTNTestableModule.cpp
//

#include "RTNTestableModule.h"

#include <sstream>

std::shared_ptr<facebook::react::TurboModule> RTNTestableModuleModuleProvider(
		std::shared_ptr<facebook::react::CallInvoker> jsInvoker) {
	return std::make_shared<facebook::react::RTNTestableModule>(
			std::move(jsInvoker));
}

namespace facebook::react {

RTNTestableModule::RTNTestableModule(std::shared_ptr<CallInvoker> jsInvoker)
		: NativeRTNTestableModuleCxxSpec(std::move(jsInvoker)) {}

std::string RTNTestableModule::concat(
		jsi::Runtime & /*rt*/,
		const std::vector<double> &array,
		const std::string &separator) {
	std::ostringstream stream;
	for (size_t i = 0; i < array.size(); ++i) {
		if (i > 0) {
			stream << separator;
		}
		stream << array[i];
	}
	return stream.str();
}

} // namespace facebook::react
