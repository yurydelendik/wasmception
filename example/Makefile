# Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/

.PHONY: all

all:
	../dist/bin/clang \
		--target=wasm32-unknown-unknown-wasm \
		--sysroot=../sysroot \
		-g \
		-O3 \
		-o main.wasm \
		-nostartfiles \
		-Wl,--allow-undefined-file=main.syms,--import-memory,--import-table,--demangle,--no-entry,--no-threads \
		-fvisibility=hidden \
		main.c
