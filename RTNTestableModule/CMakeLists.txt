cmake_minimum_required(VERSION 3.22)

set(TURBOMODULE_TARGET "rtn_testable_module")
set(TURBOMODULE_NAME "NativeRTNTestableModule")
project(${TURBOMODULE_TARGET})

set(TURBOMODULE_TARGET_TYPE STATIC)

if(ANDROID)
  set(TURBOMODULE_TARGET_TYPE SHARED)
endif()

add_library(${TURBOMODULE_TARGET} ${TURBOMODULE_TARGET_TYPE})

if(ANDROID)
    add_subdirectory(android)
endif()

add_subdirectory(cpp)

if (NOT ANDROID)
  TurboModuleTesting_AddTurboModuleDependencies(${TURBOMODULE_TARGET} "${TURBOMODULE_NAME}")
  add_subdirectory(tests)
endif()