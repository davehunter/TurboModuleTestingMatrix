cmake_minimum_required(VERSION 3.22)
set(CMAKE_VERBOSE_MAKEFILE on)

if(NOT DEFINED REACT_NATIVE_DIR)
  set(REACT_NATIVE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../react-native")
endif()
if(NOT DEFINED REACT_ANDROID_DIR)
  set(REACT_ANDROID_DIR "${REACT_NATIVE_DIR}/ReactAndroid")
endif()
if(NOT DEFINED REACT_COMMON_DIR)
  set(REACT_COMMON_DIR "${REACT_NATIVE_DIR}/ReactCommon")
endif()

include(${REACT_COMMON_DIR}/cmake-utils/react-native-flags.cmake)

# Ensure Prefab CMake packages are discoverable via CMAKE_PREFIX_PATH.
if(DEFINED CMAKE_FIND_ROOT_PATH)
  if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(_prefab_arch "aarch64-linux-android")
  elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(_prefab_arch "arm-linux-androideabi")
  elseif(ANDROID_ABI STREQUAL "x86")
    set(_prefab_arch "i686-linux-android")
  elseif(ANDROID_ABI STREQUAL "x86_64")
    set(_prefab_arch "x86_64-linux-android")
  endif()
  if(DEFINED _prefab_arch)
    list(APPEND CMAKE_PREFIX_PATH "${CMAKE_FIND_ROOT_PATH}/lib/${_prefab_arch}/cmake")
  endif()
endif()

find_package(fbjni REQUIRED CONFIG)
add_library(fbjni ALIAS fbjni::fbjni)
find_package(ReactAndroid REQUIRED CONFIG)

target_sources(${TURBOMODULE_TARGET} PUBLIC
  ${CMAKE_CURRENT_LIST_DIR}/src/main/jni/RTNTestableModuleCxxPackage.cpp
  ${CMAKE_CURRENT_LIST_DIR}/src/main/jni/OnLoad.cpp
)

target_include_directories(${TURBOMODULE_TARGET} PRIVATE
  ${CMAKE_CURRENT_LIST_DIR}/../cpp
  ${CMAKE_CURRENT_LIST_DIR}/build/generated/source/codegen/jni
  ${CMAKE_CURRENT_LIST_DIR}/build/generated/source/codegen/jni/react/renderer/components/NativeRTNTestableModule
  ${REACT_COMMON_DIR}
  ${REACT_ANDROID_DIR}
  ${REACT_COMMON_DIR}/jsi
  ${REACT_COMMON_DIR}/callinvoker
  ${REACT_COMMON_DIR}/react/nativemodule/core
  ${REACT_ANDROID_DIR}/src/main/jni/react/runtime/cxxreactpackage
)

target_link_libraries(${TURBOMODULE_TARGET}
  fbjni
  ReactAndroid::jsi
  ReactAndroid::reactnative
)

target_compile_reactnative_options(${TURBOMODULE_TARGET} PRIVATE)
