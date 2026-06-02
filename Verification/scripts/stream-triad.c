/* stream-triad.c: STREAM-style memory bandwidth (Copy, Scale, Add, Triad).
 *
 * After John McCalpin's STREAM benchmark (https://www.cs.virginia.edu/stream/),
 * implemented compactly with pthreads so it builds with the clang that ships in
 * the Xcode Command Line Tools, with no OpenMP / libomp / Homebrew dependency.
 * Vendored and auditable: this is the whole program, read it before you run it.
 * Phase 12 (memory-bandwidth.sh) compiles this at runtime and falls back to a
 * pure-Python memmove proxy when clang is unavailable. No network, no I/O.
 *
 * Build:  clang -O3 -pthread stream-triad.c -o stream-triad
 * Usage:  stream-triad <bytes_per_array> <threads> <reps>
 * Output: one JSON object on stdout with per-rep bandwidth (GB/s) per kernel.
 *
 * A single thread cannot saturate the multi-channel memory controllers on
 * Apple Silicon, so the kernels are split across <threads> worker threads the
 * way STREAM uses OpenMP. Arrays should be sized well past the system-level
 * cache so the result is DRAM-bound, not cache-bound.
 */
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double *a, *b, *c;
static size_t N;            /* elements per array */
static int NTHREADS;
static const double SCALAR = 3.0;

typedef struct { size_t lo, hi; int kernel; } work_t;

static void *run(void *arg) {
    work_t *w = (work_t *)arg;
    size_t lo = w->lo, hi = w->hi;
    switch (w->kernel) {
        case 0: for (size_t i = lo; i < hi; i++) c[i] = a[i]; break;             /* Copy  */
        case 1: for (size_t i = lo; i < hi; i++) b[i] = SCALAR * c[i]; break;     /* Scale */
        case 2: for (size_t i = lo; i < hi; i++) c[i] = a[i] + b[i]; break;       /* Add   */
        case 3: for (size_t i = lo; i < hi; i++) a[i] = b[i] + SCALAR * c[i]; break; /* Triad */
    }
    return NULL;
}

static double now_s(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec * 1e-9;
}

/* Returns GB/s for one pass of the given kernel across all threads. */
static double bench(int kernel) {
    pthread_t th[256];
    work_t w[256];
    size_t chunk = N / (size_t)NTHREADS;
    double t0 = now_s();
    for (int i = 0; i < NTHREADS; i++) {
        w[i].lo = (size_t)i * chunk;
        w[i].hi = (i == NTHREADS - 1) ? N : (size_t)(i + 1) * chunk;
        w[i].kernel = kernel;
        if (pthread_create(&th[i], NULL, run, &w[i]) != 0) {
            fprintf(stderr, "pthread_create failed\n");
            exit(4);
        }
    }
    for (int i = 0; i < NTHREADS; i++) pthread_join(th[i], NULL);
    double dt = now_s() - t0;
    /* Copy/Scale touch 2 arrays (1 read + 1 write); Add/Triad touch 3. */
    double arrays = (kernel < 2) ? 2.0 : 3.0;
    double bytes = arrays * (double)N * (double)sizeof(double);
    return dt > 0.0 ? bytes / dt / 1e9 : 0.0;
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: %s <bytes_per_array> <threads> <reps>\n", argv[0]);
        return 2;
    }
    size_t array_bytes = strtoull(argv[1], NULL, 10);
    NTHREADS = atoi(argv[2]);
    if (NTHREADS < 1) NTHREADS = 1;
    if (NTHREADS > 256) NTHREADS = 256;
    int reps = atoi(argv[3]);
    if (reps < 1) reps = 1;

    N = array_bytes / sizeof(double);
    if (N < (size_t)NTHREADS) {
        fprintf(stderr, "array too small for thread count\n");
        return 2;
    }
    a = malloc(N * sizeof(double));
    b = malloc(N * sizeof(double));
    c = malloc(N * sizeof(double));
    if (!a || !b || !c) {
        fprintf(stderr, "allocation failed\n");
        return 3;
    }
    for (size_t i = 0; i < N; i++) { a[i] = 1.0; b[i] = 2.0; c[i] = 0.0; }

    bench(3);  /* warm: fault pages in, prime, discard */

    const char *names[4] = {"copy", "scale", "add", "triad"};
    printf("{\"threads\":%d,\"bytes_per_array\":%zu,\"reps\":%d,\"results\":{",
           NTHREADS, N * sizeof(double), reps);
    for (int k = 0; k < 4; k++) {
        printf("%s\"%s\":[", k ? "," : "", names[k]);
        for (int r = 0; r < reps; r++) {
            printf("%s%.2f", r ? "," : "", bench(k));
        }
        printf("]");
    }
    printf("}}\n");

    free(a); free(b); free(c);
    return 0;
}
