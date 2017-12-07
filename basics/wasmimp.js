function syscall(stub, n) {
    switch (n) {
      default:
        console.error("NYI syscall", arguments);
        throw new Error("NYI syscall");
        break;
  
  
      case /*brk*/ 45:
        return 0;
      case /*mmap2*/ 192:
        var instance = stub.instance;
        var memory = instance.exports.memory;
        var requested = arguments[3];
        if (!stub.memory) {
            stub.memory = {
                object: memory,
                currentPosition: memory.buffer.byteLength,
            };
        }
        var cur = stub.memory.currentPosition;
        if (cur + requested > memory.buffer.byteLength) {
          var need = Math.ceil((cur + requested - memory.buffer.byteLength) / 65536);
          memory.grow(need);
        }
        stub.memory.currentPosition += requested;
        return cur;
    }
}

function createWasmceptionStub() {
    var imports = {
        env: {
            __syscall0: (n) => syscall(stub, n),
            __syscall1: (n,a) => syscall(stub, n, a),
            __syscall2: (n,a,b) => syscall(stub, n, a, b),
            __syscall3: (n,a,b,c) => syscall(stub, n, a, b, c),
            __syscall4: (n,a,b,c,d) => syscall(stub, n, a, b, c, d),
            __syscall5: (n,a,b,c,d,e) => syscall(stub, n, a, b, c, d, e),
            __syscall6: (n,a,b,c,d,e,f) => syscall(stub, n, a, b, c, d, e, f),
        },
    };
    var stub = {
        imports,
        instance: null,
        memory: null,
    };
    return stub;
}