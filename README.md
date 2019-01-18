# wasmception

Minimal toolset for building wasm files

## Export functions

Use linker's `--export` parameter to specify exports (with clang use `-Wl,--export`, e.g. `-Wl,--export=foo,--export=bar`). The use of `__attribute__ ((visibility ("default")))` is no longer preferable way to make methods visible -- `--export-dynamic` needs to be added.

## Compile C file

```
$(WASMCEPTION)/dist/bin/clang --sysroot=$(WASMCEPTION)/sysroot/ hi.c -o hi.wasm -nostartfiles -Wl,--no-entry,--export=foo
```

## Compile C++ file

```
$(WASMCEPTION)/dist/bin/clang++ --sysroot=$(WASMCEPTION)/sysroot/ hi.cpp -o hi.wasm -nostartfiles -Wl,--no-entry,--export=bar -fno-exceptions
```

## Required `main` and `_start` functions

The `-nostartfiles` will not require you to define the `main` function, but will be looking for the `_start` function:
use `-Wl,--no-entry` clang (linker) option to avoid specified entry point. As alternative, you can add `void _start() {}`
(or `extern "C" void _start() { }` in C++) to make linker happy due to `-nostartfiles`.
