cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "p2p_file_pool")

add_executable(${BINARY_NAME} WIN32
  "main.cpp"
  "flutter_window.cpp"
  "win32_window.cpp"
  "Runner.rc"
)

apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE
  $<$<CONFIG:Debug>:DEBUG>
)

target_link_libraries(${BINARY_NAME} PRIVATE
  flutter
  flutter_wrapper_app
)
