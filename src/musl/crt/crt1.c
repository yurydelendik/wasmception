#include <features.h>

#define START "_start"

#include "crt_arch.h"

int main(int argc, char *argv[]);
void _init(void) __attribute__((weak));
void _fini(void) __attribute__((weak));
_Noreturn int __libc_start_main(int (*)(), int, char **,
	void (*)(), void(*)());

void _start_c(long *p)
{
	int argc = p[0];
	char **argv = (void *)(p+1);
	__libc_start_main(main, argc, argv, _init, _fini);
}
