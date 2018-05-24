# Cmake toolchain description file for the Makefile

# This is arbitrary, AFAIK, for now.
cmake_minimum_required(VERSION 3.4.0)

set(CMAKE_SYSTEM_NAME Wasm)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(triple wasm32-unknown-unknown-wasm)

set(WASM_SDKROOT ${CMAKE_CURRENT_LIST_DIR})
set(CMAKE_C_COMPILER ${WASM_SDKROOT}/dist/bin/clang)
set(CMAKE_CXX_COMPILER ${WASM_SDKROOT}/dist/bin/clang++)
set(CMAKE_AR ${WASM_SDKROOT}/dist/bin/llvm-ar CACHE STRING "wasmception build")
set(CMAKE_RANLIB ${WASM_SDKROOT}/dist/bin/llvm-ranlib CACHE STRING "wasmception build")
set(CMAKE_C_COMPILER_TARGET ${triple} CACHE STRING "wasmception build")
set(CMAKE_CXX_COMPILER_TARGET ${triple} CACHE STRING "wasmception build")
set(CMAKE_C_FLAGS "-v --sysroot=${WASM_SDKROOT}/sysroot" CACHE STRING "wasmception build")
set(CMAKE_CXX_FLAGS "-v --sysroot=${WASM_SDKROOT}/sysroot -std=c++11" CACHE STRING "wasmception build")
set(CMAKE_EXE_LINKER_FLAGS "-Wl,--allow-undefined-file=${WASM_SDKROOT}/sysroot/lib/libc.imports,--no-threads" CACHE STRING "wasmception build")

set(CMAKE_SYSROOT ${WASM_SDKROOT}/sysroot CACHE STRING "wasmception build")
set(CMAKE_STAGING_PREFIX ${WASM_SDKROOT}/sysroot CACHE STRING "wasmception build")

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Some other hacks
set(CMAKE_C_COMPILER_WORKS ON)
set(CMAKE_CXX_COMPILER_WORKS ON)
