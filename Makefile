ROOT_DIR=${CURDIR}

default: build

clean:
	rm -rf build src dist sysroot

src/llvm.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm
	cd src/llvm/tools; svn co http://llvm.org/svn/llvm-project/cfe/trunk clang
	cd src/llvm/tools; svn co http://llvm.org/svn/llvm-project/lld/trunk lld
	cd src/llvm; patch -p 1 < $(ROOT_DIR)/patches/llvm.1.patch
	cd src/llvm/tools/clang; patch -p 1 < $(ROOT_DIR)/patches/clang.1.patch
	touch src/llvm.CLONED

src/musl.CLONED:
	mkdir -p src/
	cd src/; git clone https://github.com/jfbastien/musl.git
	cd src/musl; patch -p 1 < $(ROOT_DIR)/patches/musl.1.patch
	cd src/musl; patch -p 1 < $(ROOT_DIR)/patches/musl.2.patch
	touch src/musl.CLONED

src/compiler-rt.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt
	touch src/compiler-rt.CLONED

src/libcxx.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/libcxx/trunk libcxx
	cd src/libcxx; patch -p 1 < $(ROOT_DIR)/patches/libcxx.1.patch
	touch src/libcxx.CLONED

build/llvm.BUILT: src/llvm.CLONED
	mkdir -p build/llvm
	cd build/llvm; cmake -G "Unix Makefiles" \
		-DCMAKE_INSTALL_PREFIX=$(ROOT_DIR)/dist \
		-DLLVM_TARGETS_TO_BUILD= \
		-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly \
		$(ROOT_DIR)/src/llvm
	cd build/llvm; $(MAKE) -j 8 \
		install-clang \
		install-lld \
		install-llvm-ar \
		install-llvm-ranlib \
		llvm-config
	touch build/llvm.BUILT

build/musl.BUILT: src/musl.CLONED build/llvm.BUILT
	mkdir -p build/musl
	cd build/musl; ../../src/musl/configure \
		CC=../../dist/bin/clang \
		CFLAGS="--target=wasm32-unknown-unknown-wasm -O3" \
		--prefix=$(ROOT_DIR)/sysroot \
		wasm32
	make -C build/musl -j 8 install CROSS_COMPILE=$(ROOT_DIR)/dist/bin/llvm-
	cp src/musl/arch/wasm32/wasm.syms sysroot/lib/
	touch build/musl.BUILT

build/compiler-rt.BUILT: src/compiler-rt.CLONED build/llvm.BUILT
	mkdir -p build/compiler-rt
	cd build/compiler-rt; cmake -G "Unix Makefiles" \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasm_standalone.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DCMAKE_C_FLAGS="--target=wasm32-unknown-unknown-wasm -O1" \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=. \
		-DCMAKE_INSTALL_PREFIX=$(ROOT_DIR)/dist/lib/clang/6.0.0/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(ROOT_DIR)/src/compiler-rt/lib/builtins
	cd build/compiler-rt; make -j 8 install
	touch build/compiler-rt.BUILT

build/libcxx.BUILT: build/llvm.BUILT src/libcxx.CLONED build/compiler-rt.BUILT build/musl.BUILT
	mkdir -p build/libcxx
	cd build/libcxx; cmake -G "Unix Makefiles" \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)//wasm_standalone.cmake \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		-DLIBCXX_ENABLE_THREADS:BOOL=OFF \
		-DLIBCXX_ENABLE_STDIN:BOOL=OFF \
		-DLIBCXX_ENABLE_STDOUT:BOOL=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DLIBCXX_ENABLE_SHARED:BOOL=OFF \
		-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF \
		-DLIBCXX_ENABLE_FILESYSTEM:BOOL=OFF \
		-DLIBCXX_ENABLE_EXCEPTIONS:BOOL=OFF \
		-DLIBCXX_ENABLE_RTTI:BOOL=OFF \
		-DCMAKE_C_FLAGS="--target=wasm32-unknown-unknown-wasm" \
		-DCMAKE_CXX_FLAGS="--target=wasm32-unknown-unknown-wasm -D__WASM32__ -D_LIBCPP_HAS_MUSL_LIBC" \
		--debug-trycompile \
		../../src/libcxx
	cd build/libcxx; make -j 8 install
	touch build/libcxx.BUILT

BASICS=sysroot/include/wasmception.h sysroot/lib/wasmception.wasm

sysroot/include/wasmception.h: basics/wasmception.h
	cp basics/wasmception.h sysroot/include/

sysroot/lib/wasmception.wasm: build/llvm.BUILT basics/wasmception.c
	dist/bin/clang \
		--target=wasm32-unknown-unknown-wasm \
		--sysroot=./sysroot basics/wasmception.c \
		-c -O3 \
		-o sysroot/lib/wasmception.wasm

build: build/llvm.BUILT build/musl.BUILT build/compiler-rt.BUILT build/libcxx.BUILT $(BASICS)

strip: build/llvm.BUILT
	cd dist/bin; strip clang-6.0 lld llvm-ar

.PHONY: default clean build strip
