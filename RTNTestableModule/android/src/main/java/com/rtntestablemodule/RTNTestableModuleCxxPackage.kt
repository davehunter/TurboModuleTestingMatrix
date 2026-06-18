package com.rtntestablemodule

import com.facebook.jni.HybridData
import com.facebook.react.runtime.cxxreactpackage.CxxReactPackage

class RTNTestableModuleCxxPackage : CxxReactPackage(initHybrid()) {
  companion object {
    init {
      System.loadLibrary("rtn_testable_module")
    }

    @JvmStatic private external fun initHybrid(): HybridData
  }
}
