target_sources(${TURBOMODULE_TARGET} PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/RTNTestableModule.cpp
    ${CMAKE_CURRENT_LIST_DIR}/RTNTestableModule.h
)

target_include_directories(${TURBOMODULE_TARGET} PUBLIC ${CMAKE_CURRENT_LIST_DIR})
