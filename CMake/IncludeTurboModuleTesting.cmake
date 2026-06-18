# Source resolution order:
#   1. -DTURBO_MODULE_TESTING_SRC=<path>     (or env var TURBO_MODULE_TESTING_SRC)
#   2. -DTURBO_MODULE_TESTING_TAG=<tag>      (or env var TURBO_MODULE_TESTING_TAG)
#   3. Sibling fallback: ../TurboModuleTesting
#   4. Hard error.
macro(include_turbo_module_testing app_path)
    include(FetchContent)

    if(DEFINED ENV{TURBO_MODULE_TESTING_SRC} AND NOT DEFINED TURBO_MODULE_TESTING_SRC)
        set(TURBO_MODULE_TESTING_SRC "$ENV{TURBO_MODULE_TESTING_SRC}")
    endif()
    if(DEFINED ENV{TURBO_MODULE_TESTING_TAG} AND NOT DEFINED TURBO_MODULE_TESTING_TAG)
        set(TURBO_MODULE_TESTING_TAG "$ENV{TURBO_MODULE_TESTING_TAG}")
    endif()

    FetchContent_GetProperties(TurboModuleTesting)
    if(NOT turbomoduletesting_POPULATED)
        set(_tmt_resolved "")
        if(TURBO_MODULE_TESTING_SRC AND EXISTS "${TURBO_MODULE_TESTING_SRC}/CMakeLists.txt")
            message(STATUS "TurboModuleTesting: local source ${TURBO_MODULE_TESTING_SRC}")
            FetchContent_Declare(TurboModuleTesting SOURCE_DIR "${TURBO_MODULE_TESTING_SRC}")
            set(_tmt_resolved "src")
        elseif(TURBO_MODULE_TESTING_TAG)
            message(STATUS "TurboModuleTesting: GitHub tag ${TURBO_MODULE_TESTING_TAG}")
            FetchContent_Declare(
                TurboModuleTesting
                GIT_REPOSITORY https://github.com/davehunter/TurboModuleTesting.git
                GIT_TAG        ${TURBO_MODULE_TESTING_TAG}
            )
            set(_tmt_resolved "tag")
        else()
            set(_sibling "${CMAKE_CURRENT_LIST_DIR}/../../TurboModuleTesting")
            get_filename_component(_sibling "${_sibling}" ABSOLUTE)
            if(EXISTS "${_sibling}/CMakeLists.txt")
                message(STATUS "TurboModuleTesting: sibling fallback ${_sibling}")
                FetchContent_Declare(TurboModuleTesting SOURCE_DIR "${_sibling}")
                set(_tmt_resolved "sibling")
            endif()
        endif()

        if(NOT _tmt_resolved)
            message(FATAL_ERROR
                "TurboModuleTesting source not resolved. Set TURBO_MODULE_TESTING_SRC "
                "(local path) or TURBO_MODULE_TESTING_TAG (GitHub tag), or place "
                "TurboModuleTesting/ as a sibling of this repo.")
        endif()

        FetchContent_MakeAvailable(TurboModuleTesting)
    endif()

    TurboModuleTesting_ConfigureBasedOnApp("${app_path}")
endmacro()
