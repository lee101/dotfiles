# Go Game Performance Guide (Ebiten)

Practical guide for profiling and optimizing 2D Go games built with Ebiten.

## Quick Profiling Commands

### CPU Profiling with pprof

```bash
# Run game with CPU profiling enabled
go test -cpuprofile=cpu.prof -bench=BenchmarkFullUpdate ./internal/engine/

# Analyze profile
go tool pprof cpu.prof
# (pprof) top20
# (pprof) web          # Opens flame graph in browser
# (pprof) list drawTerrain  # Source-annotated profile for a function

# Memory profiling
go test -memprofile=mem.prof -bench=BenchmarkFullUpdate ./internal/engine/
go tool pprof -alloc_space mem.prof
# (pprof) top20 -cum   # Sort by cumulative allocations
```

### Escape Analysis

```bash
# Find every heap escape in a package
go build -gcflags="-m" ./internal/engine/ 2>&1 | grep "escapes to heap"

# Count escapes before/after optimization
go build -gcflags="-m" ./internal/engine/ 2>&1 | grep "escapes to heap" | wc -l

# Verbose escape analysis (shows reasoning)
go build -gcflags="-m -m" ./internal/engine/ 2>&1 | grep -A1 "escapes to heap"
```

### Benchmarking with Allocations

```bash
# Run benchmarks with allocation tracking
go test -bench=BenchmarkDrawTerrain -benchmem ./internal/engine/ -count=3

# Compare before/after with benchstat
go test -bench=. -benchmem ./internal/engine/ -count=5 > old.txt
# ... make changes ...
go test -bench=. -benchmem ./internal/engine/ -count=5 > new.txt
benchstat old.txt new.txt
```

## Common Allocation Pitfalls

### 1. DrawImageOptions Heap Escape

**Bad** (allocates on heap every call):
```go
op := &ebiten.DrawImageOptions{}  // escapes to heap!
op.GeoM.Translate(x, y)
screen.DrawImage(sprite, op)
```

**Good** (stays on stack):
```go
var op ebiten.DrawImageOptions  // stack-allocated
op.GeoM.Translate(x, y)
screen.DrawImage(sprite, &op)  // address taken but doesn't escape
```

In tight loops (terrain tiles, particles), this saves 100-1000+ allocations per frame.

### 2. fmt.Sprintf in Render Loops

**Bad** (allocates every frame):
```go
waveText := fmt.Sprintf("WAVE %d  :%02d", wave, secs)
multText := fmt.Sprintf("x%.1f Score", multiplier)
```

**Good** (zero allocations):
```go
waveText := "WAVE " + strconv.Itoa(wave) + "  :" + zeroPad2(secs)
multText := "x" + strconv.FormatFloat(mult, 'f', 1, 64) + " Score"
```

Use lookup tables for repeated patterns:
```go
var boatSpriteNames = [6]string{"boat-0", "boat-1", "boat-2", "boat-3", "boat-4", "boat-5"}
name := boatSpriteNames[level%len(boatSpriteNames)]
```

### 3. String Concatenation in Maps

**Bad** (allocates a new key string per lookup):
```go
key := nbName + ":" + maskName  // allocates every tile every frame
if tile, ok := cache[key]; ok { ... }
```

**Good** (use struct key or pre-cache):
```go
type blendKey struct{ biome, mask string }
if tile, ok := cache[blendKey{nbName, maskName}]; ok { ... }
```

### 4. Per-Frame Slice Allocations

**Bad**:
```go
func getVisibleEnemies() []*Enemy {
    result := make([]*Enemy, 0)  // allocates every frame
    ...
}
```

**Good** (reuse scratch buffer):
```go
type Renderer struct {
    visibleBuf []*Enemy  // persistent scratch buffer
}
func (r *Renderer) getVisibleEnemies() []*Enemy {
    r.visibleBuf = r.visibleBuf[:0]  // reuse without allocating
    ...
}
```

## DrawTriangles Batching

When drawing many instances of the same texture (particles, bullets), batch them into a single `DrawTriangles` call instead of individual `DrawImage` calls.

### Pattern: Circle Batch

```go
type Renderer struct {
    circleFill     *ebiten.Image       // pre-rendered circle texture
    batchVerts     []ebiten.Vertex     // pre-allocated, reused each frame
    batchIdx       []uint16
    batchCount     int
}

func (r *Renderer) beginBatch(screen *ebiten.Image) {
    r.batchVerts = r.batchVerts[:0]
    r.batchIdx = r.batchIdx[:0]
    r.batchCount = 0
}

func (r *Renderer) addCircle(cx, cy, radius float32, col color.RGBA) {
    srcW := float32(r.circleFill.Bounds().Dx())
    rf, gf, bf, af := float32(col.R)/255, float32(col.G)/255, float32(col.B)/255, float32(col.A)/255
    base := uint16(r.batchCount * 4)

    r.batchVerts = append(r.batchVerts,
        ebiten.Vertex{DstX: cx-radius, DstY: cy-radius, SrcX: 0,    SrcY: 0,    ColorR: rf, ColorG: gf, ColorB: bf, ColorA: af},
        ebiten.Vertex{DstX: cx+radius, DstY: cy-radius, SrcX: srcW, SrcY: 0,    ColorR: rf, ColorG: gf, ColorB: bf, ColorA: af},
        ebiten.Vertex{DstX: cx-radius, DstY: cy+radius, SrcX: 0,    SrcY: srcW, ColorR: rf, ColorG: gf, ColorB: bf, ColorA: af},
        ebiten.Vertex{DstX: cx+radius, DstY: cy+radius, SrcX: srcW, SrcY: srcW, ColorR: rf, ColorG: gf, ColorB: bf, ColorA: af},
    )
    r.batchIdx = append(r.batchIdx, base, base+1, base+2, base+1, base+3, base+2)
    r.batchCount++
}

func (r *Renderer) flush(screen *ebiten.Image) {
    if r.batchCount == 0 { return }
    screen.DrawTriangles(r.batchVerts, r.batchIdx, r.circleFill, &ebiten.DrawTrianglesOptions{})
}
```

**Impact**: 500 circles = 500 DrawImage calls -> 1 DrawTriangles call. Reduces GPU draw call overhead by ~99%.

### When to Batch

- Particles (sparks, explosions, smoke) - all use the same circle texture
- Bullet fallbacks (when no sprite loaded) - circles with different colors
- Gold pickups, minimap dots - many small circles

### When NOT to Batch

- Text particles (each has unique text, uses font rendering)
- Heal particles (cross shapes, use rects not circles)
- Sprites with different source textures (need separate batches per texture)

## Terrain Chunk Compositing

Instead of drawing 300+ terrain tiles per frame, render them to an offscreen buffer and blit once.

```go
type Renderer struct {
    terrainChunk      *ebiten.Image
    terrainChunkCamTX int  // cached camera tile position
    terrainChunkCamTY int
    terrainChunkValid bool
}

func (r *Renderer) drawTerrain(screen *ebiten.Image, camX, camY float64) {
    tileX := int(math.Floor(camX / tileSize))
    tileY := int(math.Floor(camY / tileSize))

    if !r.terrainChunkValid || tileX != r.terrainChunkCamTX || tileY != r.terrainChunkCamTY {
        r.terrainChunk.Clear()
        r.renderAllTilesToChunk(r.terrainChunk, tileX, tileY)
        r.terrainChunkCamTX = tileX
        r.terrainChunkCamTY = tileY
        r.terrainChunkValid = true
    }

    // Single blit with sub-pixel offset
    offsetX := float64(tileX)*tileSize - camX
    offsetY := float64(tileY)*tileSize - camY
    var op ebiten.DrawImageOptions
    op.GeoM.Translate(offsetX, offsetY)
    screen.DrawImage(r.terrainChunk, &op)
}
```

**Impact**: 300 draw calls -> 1 draw call (when camera stays in same tile).

## Ebiten GPU Tips

1. **Never call ReadPixels** - causes GPU->CPU transfer stall
2. **Reuse shader options** - allocate `DrawRectShaderOptions` once, update uniforms in place
3. **Use SubImage for atlas** - zero-cost, shares GPU memory
4. **Deallocate unused images** - call `img.Deallocate()` to free GPU memory
5. **Minimize unique textures per frame** - each new source texture = potential pipeline state change

## Adaptive Quality

Monitor FPS and reduce work when behind:

```
Tier 0 (full):     All rendering
Tier 1 (< 50fps):  Skip tile dressings
Tier 2 (still low): Skip decorations (trees, rocks)
Tier 3 (critical):  Skip blend overlays, reduce particles
```

Use hysteresis (sustained low/high FPS) to avoid flapping between tiers.

## Benchmark Patterns

```go
// Measure rendering allocation overhead
func BenchmarkDrawTerrain(b *testing.B) {
    e := setupStressEngine(10, 0, 0, 5)
    r := NewRenderer(1280, 720)
    screen := ebiten.NewImage(1280, 720)
    camX, camY := e.WorldWidth/2-640, e.WorldHeight/2-360

    r.drawTerrain(screen, camX, camY, e) // warm up cache

    b.ReportAllocs()
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        r.drawTerrain(screen, camX, camY, e)
    }
}

// Compare allocation strategies
func BenchmarkSprintfVsStrconv(b *testing.B) {
    b.Run("Sprintf", func(b *testing.B) {
        b.ReportAllocs()
        for i := 0; i < b.N; i++ { _ = fmt.Sprintf("WAVE %d", 15) }
    })
    b.Run("Strconv", func(b *testing.B) {
        b.ReportAllocs()
        for i := 0; i < b.N; i++ { _ = "WAVE " + strconv.Itoa(15) }
    })
}
```

## Integration with flamegraph-analyzer

```bash
# Generate pprof and convert to flamegraph
go test -cpuprofile=cpu.prof -bench=BenchmarkFullUpdate ./internal/engine/
go tool pprof -svg cpu.prof > flame.svg

# Analyze with dotfiles flamegraph tool
cd ~/code/dotfiles
python flamegraph-analyzer/main.py flame.svg -o perf-report.md
```

## Results Reference (BulletGo)

After applying all optimizations:

| Optimization | Allocs Before | Allocs After | Speedup |
|-------------|--------------|-------------|---------|
| DrawImageOptions stack | 28/frame | 0/frame | - |
| fmt.Sprintf removal | 16-24/frame | 0/frame | 57x (wave text) |
| Terrain chunking | 1288/draw | 3/draw | 160x faster |
| Particle batching | 300-1500/draw | 3/draw | 100-500x fewer allocs |
