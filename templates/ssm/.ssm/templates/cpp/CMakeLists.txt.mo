{{! CLANKER EDITED: the dev-cpp CMakeLists.txt as a cli only, named after the subproject, removed the commented output/link placeholders, spdlog header only from nixpkgs instead of CPM, static mingw link, added install() for package.nix }}
cmake_minimum_required(VERSION 3.20)
project({{subproject_name}} VERSION {{subproject_version}})

if (NOT CMAKE_BUILD_TYPE)
    message(WARNING "No build type provided. Defaulting to 'Debug'")
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Options: Debug, Release, RelWithDebInfo, MinSizeRel" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
endif()

# CLANKER ASSISTED: the nix compiler wrapper injects the dependency include paths, cmake takes them as
# implicit and leaves them out of compile_commands.json. listed explicitly so clangd and clang-tidy find them
set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})

find_package(spdlog REQUIRED)
# spdlog and fmt are used header only, compiled with this project's flags for every target
set_target_properties(spdlog::spdlog_header_only PROPERTIES
    INTERFACE_LINK_LIBRARIES "fmt::fmt-header-only;Threads::Threads"
    INTERFACE_COMPILE_DEFINITIONS "SPDLOG_FMT_EXTERNAL;$<$<NOT:$<BOOL:${MINGW}>>:SPDLOG_FWRITE_UNLOCKED>"
)

add_executable(${PROJECT_NAME}
    src/main.cc
    src/utils.cc
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    CXX_STANDARD 23
    CXX_STANDARD_REQUIRED ON
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    spdlog::spdlog_header_only
)

# the .exe shouldn't need the mingw runtime dlls
if(MINGW)
    target_link_options(${PROJECT_NAME} PRIVATE -static)
endif()

if(MINGW AND CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES)
    list(GET CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES -1 mingw_w64_include_dir)
    target_compile_options(${PROJECT_NAME} PRIVATE "SHELL:-isystem ${mingw_w64_include_dir}")
endif()

target_compile_options(${PROJECT_NAME}
    PRIVATE
        $<$<OR:$<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:GNU>,$<C_COMPILER_ID:Clang>,$<C_COMPILER_ID:GNU>>:
            -Wall -Wextra -Wpedantic -Werror -Wsign-conversion
            -fno-exceptions
            -fno-rtti
            -ffile-prefix-map=${CMAKE_CURRENT_SOURCE_DIR}/=
        >
        $<$<OR:$<CXX_COMPILER_ID:MSVC>,$<C_COMPILER_ID:MSVC>>:
            /W4 /WX
        >
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
    SPDLOG_NO_EXCEPTIONS
    $<$<BOOL:${EXTERNAL_NAME}>:EXTERNAL_NAME="${EXTERNAL_NAME}">
    $<$<CONFIG:Debug>:IS_DEBUG=1>
    $<IF:$<CONFIG:Debug>,SPDLOG_ACTIVE_LEVEL=SPDLOG_LEVEL_DEBUG,SPDLOG_ACTIVE_LEVEL=SPDLOG_LEVEL_ERROR>
)

install(TARGETS ${PROJECT_NAME})

# CLANKER ASSISTED: `./do test` runs ctest, add tests with add_test()
enable_testing()
