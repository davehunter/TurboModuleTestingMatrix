function(include_google_test target)
    include(FetchContent)

    FetchContent_GetProperties(googletest)
    if(NOT googletest_POPULATED)
        FetchContent_Declare(
            googletest
            GIT_REPOSITORY https://github.com/google/googletest.git
            GIT_TAG        v1.17.0
            )
        FetchContent_MakeAvailable(googletest)
    endif()

    target_link_libraries(${target} PRIVATE gtest_main)
endfunction()