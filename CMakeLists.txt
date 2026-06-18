cmake_minimum_required(VERSION 3.22)
project(TurboModuleTestingMatrix LANGUAGES CXX)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED EXAMPLE_APP_PATH)
  message(FATAL_ERROR
    "Pass -DEXAMPLE_APP_PATH=apps/<rn>/HostApp; the matrix is driven one version at a time.")
endif()

enable_testing()
include("CMake/IncludeGoogleTest.cmake")
include("CMake/IncludeTurboModuleTesting.cmake")
include("CMake/AddTest.cmake")

include_turbo_module_testing("${EXAMPLE_APP_PATH}")
add_subdirectory(RTNTestableModule)
