cmake_minimum_required(VERSION 3.20)
project(draw-skt)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(OpenCV REQUIRED)
add_library(drawskt STATIC src/skt.cpp)
target_link_libraries(drawskt PUBLIC ${OpenCV_LIBS})
target_include_directories(drawskt PRIVATE ${OpenCV_INCLUDE_DIRS})

add_custom_command(TARGET drawskt POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:drawskt> ${CMAKE_CURRENT_LIST_DIR}
)
