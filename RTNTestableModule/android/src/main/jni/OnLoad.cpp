#include <fbjni/fbjni.h>

#include "RTNTestableModuleCxxPackage.h"

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *) {
  return facebook::jni::initialize(vm, [] {
    facebook::react::RTNTestableModuleCxxPackage::registerNatives();
  });
}
