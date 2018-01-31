ROOT_DIR=${CURDIR}
LLVM_REV=323889
CLANG_REV=323890
LLD_REV=323856
MUSL_SHA=2b2b3bdb
COMPILER_RT_REV=323837
LIBCXX_REV=323822
LIBCXXABI_REV=323600

default: build

clean:
	rm -rf build src dist sysroot

src/llvm.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm
	cd src/llvm/tools; svn co http://llvm.org/svn/llvm-project/cfe/trunk clang
	cd src/llvm/tools; svn co http://llvm.org/svn/llvm-project/lld/trunk lld
ifdef LLVM_REV
	cd src/llvm; svn up -r$(LLVM_REV)
endif
ifdef CLANG_REV
	cd src/llvm/tools/clang; svn up -r$(CLANG_REV)
endif
ifdef LLD_REV
	cd src/llvm/tools/lld; svn up -r$(LLD_REV)
endif
	cd src/llvm/tools/clang; patch -p 1 < $(ROOT_DIR)/patches/clang.1.patch
	touch src/llvm.CLONED

src/musl.CLONED:
	mkdir -p src/
	cd src/; git clone https://github.com/jfbastien/musl.git
ifdef MUSL_SHA
	cd src/musl; git checkout $(MUSL_SHA)
endif
	cd src/musl; patch -p 1 < $(ROOT_DIR)/patches/musl.1.patch
	touch src/musl.CLONED

src/compiler-rt.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt
ifdef COMPILER_RT_REV
	cd src/compiler-rt; svn up -r$(COMPILER_RT_REV)
endif
	touch src/compiler-rt.CLONED

src/libcxx.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/libcxx/trunk libcxx
ifdef LIBCXX_REV
	cd src/libcxx; svn up -r$(LIBCXX_REV)
endif
	cd src/libcxx; patch -p 1 < $(ROOT_DIR)/patches/libcxx.1.patch
	touch src/libcxx.CLONED

src/libcxxabi.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/libcxxabi/trunk libcxxabi
ifdef LIBCXXABI_REV
	cd src/libcxxabi; svn up -r$(LIBCXXABI_REV)
endif
	touch src/libcxxabi.CLONED

build/llvm.BUILT: src/llvm.CLONED
	mkdir -p build/llvm
	cd build/llvm; cmake -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
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
	cp src/musl/arch/wasm32/libc.imports sysroot/lib/
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
		-DCMAKE_INSTALL_PREFIX=$(ROOT_DIR)/dist/lib/clang/7.0.0/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(ROOT_DIR)/src/compiler-rt/lib/builtins
	cd build/compiler-rt; make -j 8 install
	cp -R $(ROOT_DIR)/build/llvm/lib/clang $(ROOT_DIR)/dist/lib/
	touch build/compiler-rt.BUILT

build/libcxx.BUILT: build/llvm.BUILT src/libcxx.CLONED build/compiler-rt.BUILT build/musl.BUILT
	mkdir -p build/libcxx
	cd build/libcxx; cmake -G "Unix Makefiles" \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasm_standalone.cmake \
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
		-DCMAKE_CXX_FLAGS="--target=wasm32-unknown-unknown-wasm -D_LIBCPP_HAS_MUSL_LIBC" \
		--debug-trycompile \
		../../src/libcxx
	cd build/libcxx; make -j 8 install
	touch build/libcxx.BUILT

build/libcxxabi.BUILT: src/libcxxabi.CLONED build/libcxx.BUILT build/llvm.BUILT
	mkdir -p build/libcxxabi
	cd build/libcxxabi; cmake -G "Unix Makefiles" \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		-DCMAKE_CXX_COMPILER_WORKS=ON \
		-DCMAKE_C_COMPILER_WORKS=ON \
		-DLIBCXXABI_ENABLE_EXCEPTIONS:BOOL=OFF \
		-DLIBCXXABI_ENABLE_SHARED:BOOL=OFF \
		-DLIBCXXABI_ENABLE_THREADS:BOOL=OFF \
		-DCXX_SUPPORTS_CXX11=ON \
		-DLLVM_COMPILER_CHECKED=ON \
		-DCMAKE_BUILD_TYPE=Release \
		-DLIBCXXABI_LIBCXX_PATH=$(ROOT_DIR)/src/libcxx \
		-DLIBCXXABI_LIBCXX_INCLUDES=$(ROOT_DIR)/sysroot/include/c++/v1 \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasm_standalone.cmake \
		-DCMAKE_C_FLAGS="--target=wasm32-unknown-unknown-wasm" \
		-DCMAKE_CXX_FLAGS="--target=wasm32-unknown-unknown-wasm -D_LIBCPP_HAS_MUSL_LIBC" \
		-DUNIX:BOOL=ON \
		--debug-trycompile \
		$(ROOT_DIR)/src/libcxxabi
	cd build/libcxxabi; make -j 8 install
	touch build/libcxxabi.BUILT

BASICS=sysroot/include/wasmception.h sysroot/lib/wasmception.wasm

sysroot/include/wasmception.h: basics/wasmception.h
	cp basics/wasmception.h sysroot/include/

sysroot/lib/wasmception.wasm: build/llvm.BUILT basics/wasmception.c
	dist/bin/clang \
		--target=wasm32-unknown-unknown-wasm \
		--sysroot=./sysroot basics/wasmception.c \
		-c -O3 \
		-o sysroot/lib/wasmception.wasm

build: build/llvm.BUILT build/musl.BUILT build/compiler-rt.BUILT build/libcxxabi.BUILT build/libcxx.BUILT $(BASICS)

strip: build/llvm.BUILT
	cd dist/bin; strip clang-6.0 lld llvm-ar

.PHONY: default clean build strip
