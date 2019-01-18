# Any copyright is dedicated to the Public Domain.
# http://creativecommons.org/publicdomain/zero/1.0/

ROOT_DIR=${CURDIR}
LLVM_PROJECT_URL=https://github.com/llvm/llvm-project.git
MUSL_PROJECT_URL=https://github.com/jfbastien/musl.git

#LLVM_PROJECT_BRANCH=release/8.x
LLVM_PROJECT_SHA=2ed0e79bb8efc3d642e3d8212e17a160f5ebb499
MUSL_SHA=16d3d3825b4bd125244e43826fb0f0da79a1a4ad

VERSION=0.2
DEBUG_PREFIX_MAP=-fdebug-prefix-map=$(ROOT_DIR)=wasmception://v$(VERSION)
WASM_TRIPLE=wasm32-unknown-unknown-wasm
LLVM_VERSION=9
#DEFAULT_SYSROOT_CFG=-DDEFAUT_SYSROOT=$(ROOT_DIR)/sysroot

default: build
ifdef DEFAULT_SYSROOT_CFG
	echo "Use $(DEBUG_PREFIX_MAP)"
else
	echo "Use --sysroot=$(ROOT_DIR)/sysroot $(DEBUG_PREFIX_MAP)"
endif

clean:
	rm -rf build src dist sysroot wasmception-*-bin.tar.gz

src/llvm-project.CLONED:
	mkdir -p src/
	cd src/; git clone $(LLVM_PROJECT_URL)
ifdef LLVM_PROJECT_BRANCH
	cd src/llvm-project; git checkout $(LLVM_PROJECT_BRANCH)
else
ifdef LLVM_PROJECT_SHA
	cd src/llvm-project; git checkout $(LLVM_PROJECT_SHA)
endif
endif
	touch src/llvm-project.CLONED

src/musl.CLONED:
	mkdir -p src/
	cd src/; git clone $(MUSL_PROJECT_URL)
ifdef MUSL_SHA
	cd src/musl; git checkout $(MUSL_SHA)
endif
	cd src/musl; patch -p 1 < $(ROOT_DIR)/patches/musl.1.patch
	touch src/musl.CLONED

build/llvm.BUILT: src/llvm-project.CLONED
	mkdir -p build/llvm
	cd build/llvm; cmake -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_INSTALL_PREFIX=$(ROOT_DIR)/dist \
		-DLLVM_TARGETS_TO_BUILD=WebAssembly \
		-DLLVM_DEFAULT_TARGET_TRIPLE=$(WASM_TRIPLE) \
		$(DEFAULT_SYSROOT_CFG) \
		-DLLVM_EXTERNAL_CLANG_SOURCE_DIR=$(ROOT_DIR)/src/llvm-project/clang \
		-DLLVM_EXTERNAL_LLD_SOURCE_DIR=$(ROOT_DIR)/src/llvm-project/lld \
		-DLLVM_ENABLE_PROJECTS="lld;clang" \
		$(ROOT_DIR)/src/llvm-project/llvm
	cd build/llvm; $(MAKE) -j 8 \
		install-clang \
		install-lld \
		install-llc \
		install-llvm-ar \
		install-llvm-ranlib \
		install-llvm-dwarfdump \
		install-clang-headers \
		install-llvm-nm \
		install-llvm-size \
		llvm-config
	touch build/llvm.BUILT

build/musl.BUILT: src/musl.CLONED build/llvm.BUILT
	mkdir -p build/musl
	cd build/musl; $(ROOT_DIR)/src/musl/configure \
		CC=$(ROOT_DIR)/dist/bin/clang \
		CFLAGS="-O3 $(DEBUG_PREFIX_MAP)" \
		--prefix=$(ROOT_DIR)/sysroot \
		--enable-debug \
		wasm32
	make -C build/musl -j 8 install CROSS_COMPILE=$(ROOT_DIR)/dist/bin/llvm-
	cp src/musl/arch/wasm32/libc.imports sysroot/lib/
	touch build/musl.BUILT

build/compiler-rt.BUILT: src/llvm-project.CLONED build/llvm.BUILT
	mkdir -p build/compiler-rt
	cd build/compiler-rt; cmake -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasm_standalone.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DCMAKE_C_FLAGS="-O1 $(DEBUG_PREFIX_MAP)" \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=. \
		-DCMAKE_INSTALL_PREFIX=$(ROOT_DIR)/dist/lib/clang/$(LLVM_VERSION).0.0/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(ROOT_DIR)/src/llvm-project/compiler-rt/lib/builtins
	cd build/compiler-rt; make -j 8 install
	cp -R $(ROOT_DIR)/build/llvm/lib/clang $(ROOT_DIR)/dist/lib/
	touch build/compiler-rt.BUILT

build/libcxx.BUILT: src/llvm-project.CLONED build/llvm.BUILT build/compiler-rt.BUILT build/musl.BUILT
	mkdir -p build/libcxx
	cd build/libcxx; cmake -G "Unix Makefiles" \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasm_standalone.cmake \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		-DLIBCXX_ENABLE_THREADS:BOOL=OFF \
		-DCMAKE_BUILD_TYPE=RelWithDebugInfo \
		-DLIBCXX_ENABLE_SHARED:BOOL=OFF \
		-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF \
		-DLIBCXX_ENABLE_EXCEPTIONS:BOOL=OFF \
		-DLIBCXX_CXX_ABI=libcxxabi \
		-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$(ROOT_DIR)/src/llvm-project/libcxxabi/include \
		-DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
		-DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP) -D_LIBCPP_HAS_MUSL_LIBC" \
		--debug-trycompile \
		$(ROOT_DIR)/src/llvm-project/libcxx
	cd build/libcxx; make -j 8 install
	touch build/libcxx.BUILT

build/libcxxabi.BUILT: src/llvm-project.CLONED build/libcxx.BUILT build/llvm.BUILT
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
		-DCMAKE_BUILD_TYPE=RelWithDebugInfo \
		-DLIBCXXABI_LIBCXX_PATH=$(ROOT_DIR)/src/llvm-project/libcxx \
		-DLIBCXXABI_LIBCXX_INCLUDES=$(ROOT_DIR)/sysroot/include/c++/v1 \
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCMAKE_TOOLCHAIN_FILE=$(ROOT_DIR)/wasm_standalone.cmake \
		-DCMAKE_C_FLAGS="$(DEBUG_PREFIX_MAP)" \
		-DCMAKE_CXX_FLAGS="$(DEBUG_PREFIX_MAP) -D_LIBCPP_HAS_MUSL_LIBC" \
		-DUNIX:BOOL=ON \
		--debug-trycompile \
		$(ROOT_DIR)/src/llvm-project/libcxxabi
	cd build/libcxxabi; make -j 8 install
	touch build/libcxxabi.BUILT

BASICS=sysroot/include/wasmception.h sysroot/lib/wasmception.wasm

sysroot/include/wasmception.h: basics/wasmception.h
	cp basics/wasmception.h sysroot/include/

sysroot/lib/wasmception.wasm: build/llvm.BUILT basics/wasmception.c
	dist/bin/clang \
		--sysroot=./sysroot basics/wasmception.c \
		-c -O3 -g $(DEBUG_PREFIX_MAP) \
		-o sysroot/lib/wasmception.wasm

build: build/llvm.BUILT build/musl.BUILT build/compiler-rt.BUILT build/libcxxabi.BUILT build/libcxx.BUILT $(BASICS)

strip: build/llvm.BUILT
	cd dist/bin; strip clang-$(LLVM_VERSION) llc lld llvm-ar

collect-sources:
	-rm -rf build/sources build/sources.txt
	{ find sysroot -name "*.o"; find sysroot -name "*.wasm"; find dist/lib sysroot -name "lib*.a"; } | \
	  xargs ./list_debug_sources.py | sort > build/sources.txt
	echo "sysroot/include" >> build/sources.txt
	for f in $$(cat build/sources.txt); \
	  do mkdir -p `dirname build/sources/$$f`; cp -R $$f `dirname build/sources/$$f`; done;
	cd build/sources && { git init; git checkout --orphan v$(VERSION); git add -A .; git commit -m "Sources"; }
	echo "cd build/sources && git push -f git@github.com:yurydelendik/wasmception.git v$(VERSION)"

revisions:
	cd src/llvm-project; echo "LLVM_PROJECT_SHA=`git log -1 --format="%H"`"
	cd src/musl; echo "MUSL_SHA=`git log -1 --format="%H"`"

OS_NAME=$(shell uname -s | tr '[:upper:]' '[:lower:]')
pack:
	tar czf wasmception-${OS_NAME}-bin.tar.gz dist sysroot

.PHONY: default clean build strip revisions pack collect-sources
