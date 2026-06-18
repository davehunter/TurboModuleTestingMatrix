function (addTest filename)
    get_filename_component(testname "${filename}" NAME_WE)
    message(STATUS "⚛️🚀🧪 Adding TurboModule test: ${testname}")

    add_executable(${testname} "${filename}")
    target_link_libraries(${testname} PUBLIC ${TURBOMODULE_TARGET})
    include_google_test(${testname})
    add_test(NAME ${testname} COMMAND ${testname} --gtest_color=yes)
    set_tests_properties(${testname} PROPERTIES
        TIMEOUT 20
        RUN_SERIAL TRUE
    )
endfunction()
