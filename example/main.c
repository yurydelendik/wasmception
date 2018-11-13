// Any copyright is dedicated to the Public Domain.
// http://creativecommons.org/publicdomain/zero/1.0/

#include <string.h>

/*
 * Ask to JS about an integer
 */
int __play_with_js(void);

/*
 * Passing a string through linear memory and print it
 */
void __console_log(int str, int len);
void console_log(char *str) {
	__console_log((int) str, strlen(str));
}

/*
 * Fn exported to JS
 */
int do_something(int a) {
	console_log("I'm speaking from WASM !");
	return a + __play_with_js();
}

