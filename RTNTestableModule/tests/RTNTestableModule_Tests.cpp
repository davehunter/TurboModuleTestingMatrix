#include "RTNTestableModule.h"
#include <TurboModuleTesting.h>
#include <gtest/gtest.h>

class RTNTestableModule_Tests : public ::testing::Test {
protected:
    void SetUp() override
    {
        facebook::react::registerCxxModuleToGlobalModuleMap(
            "RTNTestableModule", [&](std::shared_ptr<facebook::react::CallInvoker> jsInvoker) {
                return std::make_shared<facebook::react::RTNTestableModule>(std::move(jsInvoker));
            });

        _env = std::make_unique<TurboModuleTestingEnvironment>();
    }

    void TearDown() override
    {
        _env = nullptr;
    }

    std::unique_ptr<TurboModuleTestingEnvironment> _env;
};

TEST_F(RTNTestableModule_Tests, testCallingTurboModule)
{
    facebook::jsi::Value result = _env->evaluateJavascript(
        "globalThis.__turboModuleProxy('RTNTestableModule').concat([1,2,3,4], '-')");
    EXPECT_TRUE(result.isString());
    std::string concatResult = facebook::react::Bridging<std::string>::fromJs(_env->rt(), result.getString(_env->rt()));
    EXPECT_EQ(concatResult, "1-2-3-4");
}

TEST_F(RTNTestableModule_Tests, testCallingTurboModuleWithEmptySeparator)
{
    facebook::jsi::Value result = _env->evaluateJavascript(
        "globalThis.__turboModuleProxy('RTNTestableModule').concat([1,2,3,4], '')");
    EXPECT_TRUE(result.isString());
    std::string concatResult = facebook::react::Bridging<std::string>::fromJs(_env->rt(), result.getString(_env->rt()));
    EXPECT_EQ(concatResult, "1234");
}

TEST_F(RTNTestableModule_Tests, testCallingTurboModuleWithEmptyArray)
{
    facebook::jsi::Value result = _env->evaluateJavascript(
        "globalThis.__turboModuleProxy('RTNTestableModule').concat([], '+')");
    EXPECT_TRUE(result.isString());
    std::string concatResult = facebook::react::Bridging<std::string>::fromJs(_env->rt(), result.getString(_env->rt()));
    EXPECT_EQ(concatResult, "");
}

TEST_F(RTNTestableModule_Tests, testCallingTurboModuleWithSingleElementArray)
{
    facebook::jsi::Value result = _env->evaluateJavascript(
        "globalThis.__turboModuleProxy('RTNTestableModule').concat([42], '+')");
    EXPECT_TRUE(result.isString());
    std::string concatResult = facebook::react::Bridging<std::string>::fromJs(_env->rt(), result.getString(_env->rt()));
    EXPECT_EQ(concatResult, "42");
}

TEST_F(RTNTestableModule_Tests, testCallingTurboModuleWithNonStringSeparator)
{
    EXPECT_THROW(
        _env->evaluateJavascript(
            "globalThis.__turboModuleProxy('RTNTestableModule').concat([1,2,3,4], 0)"),
        facebook::jsi::JSError);
}

TEST_F(RTNTestableModule_Tests, testCallingTurboModuleWithNonArray)
{
    EXPECT_THROW(
        _env->evaluateJavascript(
            "globalThis.__turboModuleProxy('RTNTestableModule').concat('not an array', '-')"),
        facebook::jsi::JSError);
}

TEST_F(RTNTestableModule_Tests, testCallingTurboModuleWithNullArray)
{
    EXPECT_THROW(
        _env->evaluateJavascript(
            "globalThis.__turboModuleProxy('RTNTestableModule').concat(null, '-')"),
        facebook::jsi::JSError);
}
