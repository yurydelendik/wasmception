ROOT_DIR=${CURDIR}

default: build

clean:
	rm -rf build src installed sysroot

src/llvm.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm
	cd src/llvm/tools; svn co http://llvm.org/svn/llvm-project/cfe/trunk clang
	cd src/llvm/tools; svn co http://llvm.org/svn/llvm-project/lld/trunk lld
	touch src/llvm.CLONED

src/musl.CLONED:
	mkdir -p src/
	cd src/; git clone https://github.com/jfbastien/musl.git
	touch src/musl.CLONED

src/compiler-rt.CLONED:
	mkdir -p src/
	cd src/; svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt
	touch src/compiler-rt.CLONED

build/llvm.BUILT: src/llvm.CLONED
	mkdir -p build/llvm
	cd build/llvm; cmake -G "Unix Makefiles" \
		-DCMAKE_INSTALL_PREFIX=$(ROOT_DIR)/installed \
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
	mkdir -p sysroot/lib
	src/musl/libc.py \
		--clang_dir=$(ROOT_DIR)/installed/bin \
		--binaryen_dir=$(ROOT_DIR)/installed/bin \
		--musl=$(ROOT_DIR)/src/musl/ \
		--arch=wasm32 \
		--out=$(ROOT_DIR)/sysroot/lib/libc.a \
		--verbose --compile-to-wasm
	mkdir -p sysroot/include
	rsync -uma --include="*/" --include="*.h" --exclude="*" src/musl/include/ sysroot/include/
	rsync -uma --include="*/" --include="*.h" --exclude="*" src/musl/arch/wasm32/ sysroot/include/
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
		-DLLVM_CONFIG_PATH=$(ROOT_DIR)/build/llvm/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=. \
		-DCMAKE_INSTALL_PREFIX=$(ROOT_DIR)/installed/lib/clang/6.0.0/ \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
		$(ROOT_DIR)/src/compiler-rt/lib/builtins
	cd build/compiler-rt; make -j 8 install
	touch build/compiler-rt.BUILT

build: build/llvm.BUILT build/musl.BUILT build/compiler-rt.BUILT

.PHONY: default clean build
