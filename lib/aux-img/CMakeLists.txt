cmake_minimum_required(VERSION 3.20)
project(aux-img)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(CImg INTERFACE)
target_include_directories(CImg INTERFACE third-party/CImg)

add_library(auximg SHARED src/aux.cpp src/skt.cpp)
target_link_libraries(auximg PUBLIC CImg)
target_include_directories(auximg PUBLIC inc)

add_custom_command(TARGET auximg POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:auximg> ${CMAKE_CURRENT_LIST_DIR}
)
