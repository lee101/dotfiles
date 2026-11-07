#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ladspa.h>

#define MAXHOP 256
#define MAXWIN 512
#define MAXC 512
#define MAXH 512
#define ENVN 250

typedef struct {
    int C, H, WIN;
    float *enc, *nw, *nb, *inw, *inb, *ih0, *hh0, *bi0, *bh0, *ih1, *hh1, *bi1, *bh1, *mw, *mb, *gw, *gb, *dec;
    float *mem, *tone;
} Weights;

typedef struct {
    Weights *w;
    float pows[ENVN], kern[ENVN], hist[MAXWIN], ola[MAXWIN], h0[MAXH], h1[MAXH];
    float in_fifo[MAXHOP * 2], out_fifo[MAXHOP * 64];
    int in_n, out_n, started, skip;
    float comp_lvl, comp_g;
    float *ctl_bypass, *ctl_gain, *ctl_floor, *ctl_strength, *ctl_aesthetic, *in, *out;
} Inst;

static Weights *load_weights(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    int hdr[4];
    if (fread(hdr, 4, 4, f) != 4) { fclose(f); return NULL; }
    Weights *w = calloc(1, sizeof *w);
    w->C = hdr[0]; w->H = hdr[1]; w->WIN = hdr[2];
    int C = w->C, H = w->H, WIN = w->WIN;
    size_t sizes[] = {C * WIN, C, C, H * (C + 1), H, 3 * H * H, 3 * H * H, 3 * H, 3 * H, 3 * H * H, 3 * H * H, 3 * H, 3 * H, C * H, C, H, 1, C * WIN};
    float **ptrs[] = {&w->enc, &w->nw, &w->nb, &w->inw, &w->inb, &w->ih0, &w->hh0, &w->bi0, &w->bh0, &w->ih1, &w->hh1, &w->bi1, &w->bh1, &w->mw, &w->mb, &w->gw, &w->gb, &w->dec};
    size_t total = 0;
    for (int i = 0; i < 18; i++) total += sizes[i];
    w->mem = malloc(total * 4);
    if (fread(w->mem, 4, total, f) != total) { fclose(f); free(w->mem); free(w); return NULL; }
    w->tone = NULL;
    if (hdr[3] == 1) { w->tone = malloc(C * 4); if (fread(w->tone, 4, C, f) != (size_t)C) { free(w->tone); w->tone = NULL; } }
    fclose(f);
    size_t o = 0;
    for (int i = 0; i < 18; i++) { *ptrs[i] = w->mem + o; o += sizes[i]; }
    return w;
}

static inline float sigm(float x) { return 1.f / (1.f + expf(-x)); }

static void matvec(const float *W, const float *x, const float *b, float *y, int rows, int cols) {
    for (int r = 0; r < rows; r++) {
        const float *row = W + (size_t)r * cols;
        float s = b ? b[r] : 0.f;
        for (int c = 0; c < cols; c++) s += row[c] * x[c];
        y[r] = s;
    }
}

static void gru(const float *ih, const float *hh, const float *bi, const float *bh, const float *x, float *h, int in, int H) {
    float gi[3 * MAXH], gh[3 * MAXH], hn[MAXH];
    matvec(ih, x, bi, gi, 3 * H, in);
    matvec(hh, h, bh, gh, 3 * H, H);
    for (int i = 0; i < H; i++) {
        float r = sigm(gi[i] + gh[i]);
        float z = sigm(gi[H + i] + gh[H + i]);
        float n = tanhf(gi[2 * H + i] + r * gh[2 * H + i]);
        hn[i] = (1.f - z) * n + z * h[i];
    }
    memcpy(h, hn, H * 4);
}

static void hop(Inst *s, const float *blk, float *out_blk, float floor, float strength, float aesthetic) {
    Weights *w = s->w;
    int C = w->C, H = w->H, WIN = w->WIN, HOP = WIN / 2;
    float z[MAXC], h[MAXC + 1], x0[MAXH], m[MAXC], fr[MAXWIN];
    float p = 0;
    for (int k = 0; k < HOP; k++) p += blk[k] * blk[k];
    memmove(s->pows + 1, s->pows, (ENVN - 1) * 4);
    s->pows[0] = p / HOP;
    float acc = 0;
    for (int j = 0; j < ENVN; j++) acc += s->kern[j] * s->pows[j];
    float env = sqrtf(acc > 1e-9f ? acc : 1e-9f);
    float envs = env > 1.7782794e-4f ? env : 1.7782794e-4f;
    float scale = 0.11220185f / envs;
    float lv = log10f(env > 1e-6f ? env : 1e-6f) / 3.f;
    memmove(s->hist, s->hist + HOP, (WIN - HOP) * 4);
    memcpy(s->hist + WIN - HOP, blk, HOP * 4);
    matvec(w->enc, s->hist, NULL, z, C, WIN);
    float mu = 0, var = 0;
    for (int i = 0; i < C; i++) { h[i] = log10f(fabsf(z[i]) * scale + 1e-4f); mu += h[i]; }
    mu /= C;
    for (int i = 0; i < C; i++) var += (h[i] - mu) * (h[i] - mu);
    var /= C;
    float inv = 1.f / sqrtf(var + 1e-5f);
    for (int i = 0; i < C; i++) h[i] = (h[i] - mu) * inv * w->nw[i] + w->nb[i];
    h[C] = lv;
    matvec(w->inw, h, w->inb, x0, H, C + 1);
    for (int i = 0; i < H; i++) if (x0[i] < 0) x0[i] = 0;
    gru(w->ih0, w->hh0, w->bi0, w->bh0, x0, s->h0, H, H);
    gru(w->ih1, w->hh1, w->bi1, w->bh1, s->h0, s->h1, H, H);
    matvec(w->mw, s->h1, w->mb, m, C, H);
    float g = 0;
    for (int i = 0; i < H; i++) g += w->gw[i] * s->h1[i];
    g += w->gb[0];
    g = g < -3.f ? -3.f : g > 3.f ? 3.f : g;
    float gs = powf(expf(g) * scale, strength);
    memset(fr, 0, WIN * 4);
    for (int c = 0; c < C; c++) {
        const float *d = w->dec + (size_t)c * WIN;
        float mk = 1.f + strength * (2.f * sigm(m[c]) - 1.f);
        if (mk < floor) mk = floor;
        float tg = w->tone && aesthetic > 0.f ? powf(10.f, aesthetic * w->tone[c] / 20.f) : 1.f;
        float yc = z[c] * mk * tg * gs;
        for (int k = 0; k < WIN; k++) fr[k] += yc * d[k];
    }
    for (int k = 0; k < WIN; k++) s->ola[k] += fr[k];
    memcpy(out_blk, s->ola, HOP * 4);
    memmove(s->ola, s->ola + HOP, (WIN - HOP) * 4);
    memset(s->ola + WIN - HOP, 0, HOP * 4);
}

static LADSPA_Handle inst_new(const LADSPA_Descriptor *d, unsigned long sr) {
    (void)d;
    if (sr != 48000) return NULL;
    const char *path = getenv("NVE_WEIGHTS");
    char def[1024];
    if (!path) {
        snprintf(def, sizeof def, "%s/.local/share/neural-voice-enhance/enh.bin", getenv("HOME") ? getenv("HOME") : ".");
        path = def;
    }
    Weights *w = load_weights(path);
    if (!w) { fprintf(stderr, "nve: cannot load %s\n", path); return NULL; }
    Inst *s = calloc(1, sizeof *s);
    s->w = w;
    for (int j = 0; j < ENVN; j++) s->kern[j] = (1.f - expf(-1.f / 250.f)) * expf(-(float)j / 250.f);
    return s;
}

static void connect_port(LADSPA_Handle h, unsigned long p, LADSPA_Data *d) {
    Inst *s = h;
    if (p == 0) s->in = d; else if (p == 1) s->out = d; else if (p == 2) s->ctl_bypass = d; else if (p == 3) s->ctl_gain = d; else if (p == 4) s->ctl_floor = d; else if (p == 5) s->ctl_strength = d; else s->ctl_aesthetic = d;
}

static void run(LADSPA_Handle h, unsigned long n) {
    Inst *s = h;
    const int HOP = s->w->WIN / 2;
    if (s->ctl_bypass && *s->ctl_bypass > 0.5f) { memcpy(s->out, s->in, n * 4); return; }
    float gain = powf(10.f, (s->ctl_gain ? *s->ctl_gain : 14.f) / 20.f);
    if (s->comp_g == 0.f) s->comp_g = 1.f;
    const float rel = expf(-1.f / (0.06f * 48000.f));
    if (!s->started) { s->out_n = HOP; memset(s->out_fifo, 0, HOP * 4); s->skip = (s->w->WIN - HOP) / HOP; s->started = 1; }
    for (unsigned long i = 0; i < n; i++) {
        s->in_fifo[s->in_n++] = s->in[i];
        if (s->in_n == HOP) {
            float blk[MAXHOP];
            hop(s, s->in_fifo, blk, s->ctl_floor ? *s->ctl_floor : 0.f, s->ctl_strength ? *s->ctl_strength : 1.f, s->ctl_aesthetic ? *s->ctl_aesthetic : 0.f);
            if (s->skip > 0) s->skip--; else { memcpy(s->out_fifo + s->out_n, blk, HOP * 4); s->out_n += HOP; }
            s->in_n = 0;
        }
        float o = s->out_n > 0 ? s->out_fifo[0] : 0.f;
        o *= gain;
        float ao0 = fabsf(o);
        s->comp_lvl = ao0 > s->comp_lvl ? ao0 : s->comp_lvl * rel;
        float tg = s->comp_lvl > 0.3f ? powf(0.3f / s->comp_lvl, 0.667f) : 1.f;
        s->comp_g += (tg < s->comp_g ? 0.08f : 0.0004f) * (tg - s->comp_g);
        o *= s->comp_g;
        float ao = fabsf(o);
        if (ao > 0.7f) o = copysignf(0.7f + 0.3f * tanhf((ao - 0.7f) / 0.3f), o);
        s->out[i] = o;
        if (s->out_n > 0) { memmove(s->out_fifo, s->out_fifo + 1, (s->out_n - 1) * 4); s->out_n--; }
    }
}

static void cleanup(LADSPA_Handle h) { Inst *s = h; if (s) { free(s->w->mem); free(s->w->tone); free(s->w); free(s); } }

static LADSPA_PortDescriptor pd[7] = {LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO, LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO, LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL, LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL, LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL, LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL, LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL};
static const char *pn[7] = {"Input", "Output", "Bypass", "Gain (dB)", "Floor", "Strength", "Aesthetic"};
static LADSPA_PortRangeHint ph[7] = {{0, 0, 0}, {0, 0, 0}, {LADSPA_HINT_TOGGLED | LADSPA_HINT_DEFAULT_0, 0, 1}, {LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_0, -20, 20}, {LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_0, 0, 1}, {LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_MAXIMUM, 0, 1}, {LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE | LADSPA_HINT_DEFAULT_0, 0, 1}};
static LADSPA_Descriptor desc = {
    .UniqueID = 0x4e5645, .Label = "nve_mono", .Name = "Neural Voice Enhance", .Maker = "dotfiles", .Copyright = "none",
    .PortCount = 7, .PortDescriptors = pd, .PortNames = pn, .PortRangeHints = ph,
    .instantiate = inst_new, .connect_port = connect_port, .run = run, .cleanup = cleanup,
};

const LADSPA_Descriptor *ladspa_descriptor(unsigned long i) { return i == 0 ? &desc : NULL; }
