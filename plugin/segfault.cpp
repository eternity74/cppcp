#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

static void __handler(int sig) {
  fputs("Segmentation fault\n", stderr);
  exit(128 + SIGSEGV);
}

bool __register_handler() {
  signal(SIGSEGV, __handler);
  return true;
}

bool __ignore_b = __register_handler();
