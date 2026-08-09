/* LD_PRELOAD shim that counts Mojo-level allocations.
 *
 * Mojo does NOT allocate through libc malloc — List/String/alloc[T] all go through
 * KGEN_CompilerRT_AlignedAlloc / KGEN_CompilerRT_AlignedFree in
 * libKGENCompilerRTShared.so. valgrind/dhat therefore report only runtime-startup
 * heap and attribute nothing to user code. Intercepting these two symbols is the
 * only way to see what a Mojo program actually allocates.
 *
 * Build: gcc -shared -fPIC -O2 -o mojomem_shim.so mojomem_shim.c -ldl
 * Use:   MOJOMEM_OUT=/tmp/x.tsv LD_PRELOAD=./mojomem_shim.so ./mybin
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#define NBUCKET 4096
#define MAXDEPTH 24
#define PTRSLOTS (1 << 20)   /* live-block map; power of two */

typedef struct {
    uint64_t key;
    uint64_t calls, bytes, live_now, live_peak;
    int depth;
    void *stack[MAXDEPTH];
} Site;

static Site sites[NBUCKET];

/* ptr -> (size, site) so free() can decrement live bytes */
typedef struct { void *p; size_t size; int site; } Live;
static Live live_map[PTRSLOTS];

static size_t pslot(void *p) { return ((uintptr_t)p >> 4) & (PTRSLOTS - 1); }

static void live_put(void *p, size_t size, int site) {
    size_t i = pslot(p);
    for (size_t n = 0; n < 64; n++, i = (i + 1) & (PTRSLOTS - 1))
        if (!live_map[i].p) { live_map[i].p = p; live_map[i].size = size;
                              live_map[i].site = site; return; }
}

static int live_take(void *p, size_t *size) {   /* -> site index or -1 */
    size_t i = pslot(p);
    for (size_t n = 0; n < 64; n++, i = (i + 1) & (PTRSLOTS - 1))
        if (live_map[i].p == p) {
            *size = live_map[i].size; int s = live_map[i].site;
            live_map[i].p = NULL; return s;
        }
    return -1;
}
static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;
static uint64_t g_calls, g_bytes, g_frees, g_live, g_peak;
static uint64_t hist[40];               /* log2 size histogram */
static int skip_frames = 1;   /* just our own hook frame */
static int depth_want = 8;
static int inited, in_hook;

static void *(*real_alloc)(size_t, size_t);
static void (*real_free)(void *);

static void init(void) {
    if (inited) return;
    inited = 1;
    real_alloc = dlsym(RTLD_NEXT, "KGEN_CompilerRT_AlignedAlloc");
    real_free = dlsym(RTLD_NEXT, "KGEN_CompilerRT_AlignedFree");
    const char *d = getenv("MOJOMEM_DEPTH");
    if (d) depth_want = atoi(d);
    if (depth_want > MAXDEPTH) depth_want = MAXDEPTH;
}

/* fnv1a over the return addresses: one bucket per distinct call stack */
static uint64_t hash_stack(void **st, int n) {
    uint64_t h = 1469598103934665603ULL;
    for (int i = 0; i < n; i++) {
        uint64_t v = (uint64_t)st[i];
        for (int b = 0; b < 8; b++) { h ^= (v >> (b * 8)) & 0xff; h *= 1099511628211ULL; }
    }
    return h ? h : 1;
}

void *KGEN_CompilerRT_AlignedAlloc(size_t align, size_t size) {
    init();
    void *p = real_alloc ? real_alloc(align, size) : aligned_alloc(align, size);
    if (in_hook) return p;                    /* backtrace() itself may allocate */
    in_hook = 1;

    void *bt[MAXDEPTH + 4];
    int n = backtrace(bt, depth_want + skip_frames);
    int off = n > skip_frames ? skip_frames : 0;
    int d = n - off;
    uint64_t h = hash_stack(bt + off, d);

    pthread_mutex_lock(&lk);
    g_calls++; g_bytes += size; g_live += size;
    if (g_live > g_peak) g_peak = g_live;
    int b = 0; size_t s = size; while (s > 1 && b < 39) { s >>= 1; b++; }
    hist[b]++;
    size_t i = h % NBUCKET, probes = 0;
    while (sites[i].key && sites[i].key != h && probes++ < NBUCKET) i = (i + 1) % NBUCKET;
    if (probes < NBUCKET) {
        if (!sites[i].key) {
            sites[i].key = h; sites[i].depth = d;
            memcpy(sites[i].stack, bt + off, d * sizeof(void *));
        }
        sites[i].calls++; sites[i].bytes += size;
        sites[i].live_now += size;
        if (sites[i].live_now > sites[i].live_peak) sites[i].live_peak = sites[i].live_now;
        live_put(p, size, (int)i);
    }
    pthread_mutex_unlock(&lk);
    in_hook = 0;
    return p;
}

void KGEN_CompilerRT_AlignedFree(void *p) {
    init();
    if (p) {
        size_t size = 0;
        pthread_mutex_lock(&lk);
        g_frees++;
        int s = live_take(p, &size);
        if (s >= 0) {
            g_live -= size < g_live ? size : g_live;
            sites[s].live_now -= size < sites[s].live_now ? size : sites[s].live_now;
        }
        pthread_mutex_unlock(&lk);
    }
    if (real_free) real_free(p); else free(p);
}

__attribute__((destructor)) static void dump(void) {
    const char *out = getenv("MOJOMEM_OUT");
    FILE *f = out ? fopen(out, "w") : stderr;
    if (!f) return;
    fprintf(f, "#summary\tcalls\tbytes\tfrees\tpeak_live\n");
    fprintf(f, "summary\t%lu\t%lu\t%lu\t%lu\n", g_calls, g_bytes, g_frees, g_peak);
    for (int i = 0; i < 40; i++)
        if (hist[i]) fprintf(f, "hist\t%d\t%lu\n", i, hist[i]);
    for (int i = 0; i < NBUCKET; i++) {
        if (!sites[i].key) continue;
        fprintf(f, "site\t%lu\t%lu\t%lu", sites[i].calls, sites[i].bytes, sites[i].live_peak);
        char **sym = backtrace_symbols(sites[i].stack, sites[i].depth);
        for (int j = 0; j < sites[i].depth; j++) {
            fprintf(f, "\t%p", sites[i].stack[j]);
            if (sym && sym[j]) fprintf(f, "|%s", sym[j]);
        }
        fprintf(f, "\n");
        free(sym);
    }
    if (out) fclose(f);
}
