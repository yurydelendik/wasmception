# Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/

.PHONY: all

all:
	../dist/bin/clang \
		--sysroot=../sysroot \
		-g \
		-O3 \
		-o main.wasm \
		-nostartfiles \
		-Wl,--allow-undefined-file=main.syms,--import-memory,--import-table,--demangle,--no-entry,--no-threads \
		-Wl,--export=do_something \
		-fvisibility=hidden \
		main.c
