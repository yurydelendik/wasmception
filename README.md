# wasmception

Minimal toolset for building wasm files

## Export functions

Use `__attribute__ ((visibility ("default")))` to make methods visible

## Compile C file

```
$(WASMCEPTION)/dist/bin/clang --target=wasm32-unknown-unknown-wasm --sysroot=$(WASMCEPTION)/sysroot/ hi.c -o hi.wasm -nostartfiles -Wl,--no-entry
```

## Compile C++ file

```
$(WASMCEPTION)/dist/bin/clang++ --target=wasm32-unknown-unknown-wasm --sysroot=$(WASMCEPTION)/sysroot/ hi.cpp -o hi.wasm -nostartfiles -Wl,--no-entry
```

## Required `main` and `_start` functions

The `-nostartfiles` will not require you to define the `main` function, but will be looking for the `_start` function:
use `-Wl,--no-entry` clang (linker) option to avoid specified entry point. As alternative, you can add `void _start() {}`
(or `extern "C" void _start() { }` in C++) to make linker happy due to `-nostartfiles`.
