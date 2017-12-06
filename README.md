# wasmception

Minimal toolset for building wasm files

## Export functions

Use `__attribute__ ((visibility ("default")))` to make methods visible

## Compile C file

```
$(WASMCEPTION)/dist/bin/clang --target=wasm32-unknown-unknown-wasm --sysroot=$(WASMCEPTION)/sysroot/ hi.c -o hi.wasm -nostartfiles -D__WASM32__
```

## Compile C++ file

```
$(WASMCEPTION)/dist/bin/clang++ --target=wasm32-unknown-unknown-wasm --sysroot=$(WASMCEPTION)/sysroot/ hi.cpp -o hi.wasm -nostartfiles -D__WASM32__
```

## Required _start

Add `void _start() {}` to make linker happy due to `-nostartfiles`

