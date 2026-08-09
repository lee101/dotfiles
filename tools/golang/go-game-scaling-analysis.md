# Why Performance Degrades With More Entities (Go/Ebiten)

A detailed analysis of how BulletGo's performance scales with entity count, covering the spatial data structures, collision systems, AI pathfinding, and rendering pipeline.

## Architecture Overview

The game uses a **toroidal (wraparound) world** where entities can wrap across edges. Every distance check must account for this wrapping, adding overhead to the most fundamental operation in the engine.

### Data Structures

**Spatial Hash** (`internal/world/spatial_hash.go`)
- Elasticsearch-style geohash grid: world divided into 200px cells
- Two storage modes: `map[cellKey][]T` (non-wrapping) or flat `[][]T` grid (toroidal)
- Entities mapped to 1-4 cells based on their radius
- Deduplication via per-entity `seen[]uint32` + generation counter (avoids returning same entity from overlapping cells)
- `QueryCircle` fast path: pre-computes wrapped x-indices to avoid per-cell modulo

**Per-Frame Rebuilds**: Enemy hash + Ally hash are **cleared and rebuilt every frame** because entities move. This is O(E + A) baseline cost before any queries happen.

**Pack Cohesion LOD** (line 5796): When >80 enemies, each enemy reuses its `CachedPackVec` every other frame instead of recomputing via spatial query. This halves pack cohesion cost at high enemy counts.

## Collision System Scaling

Every collision system uses `wrapDistSq()` for distance checks — 4 conditional branches + cave mode check per call.

### With vs Without Spatial Hash

| System | Naive | With Spatial Hash | Where | Key Lines |
|--------|-------|-------------------|-------|-----------|
| Bullet → Player | O(B×P) | O(B×4) same | game_engine.go | 6478-6512 |
| Bullet → Enemy | **O(B×E)** | O(B × d_enemy) | game_engine.go | 6539-6627 |
| Bullet → Structure | **O(B×S)** | O(B × d_struct) | structures.go | 2162-2188 |
| Enemy → Player (closest) | O(E×P) | O(E×4) same | game_engine.go | 5270-5279 |
| Enemy → Structure | **O(E×S)** | O(E × d_struct) | structures.go | 2000-2050 |
| Enemy Pack Cohesion | **O(E²)** | O(E × d_local) | game_engine.go | 6268 |
| Structure Avoidance | **O(E×S)** | O(E × d_struct) | game_engine.go | 6226 |
| Magic → Enemy | **O(M×E)** | O(M × d_enemy) | game_engine.go | 6684-6769 |

Where `d_X` = average local density in spatial hash cells (typically 3-15 entities).

**Bullet → Player** doesn't use spatial hash because there are only 4 players — the hash overhead would exceed the brute-force cost.

### Cost at Different Entity Counts

**50 enemies, 50 bullets, 100 structures:**
- Spatial hash queries: ~800 wrapDistSq calls/frame
- Closest player: 200 wrapDistSq calls/frame
- Total: ~1,500 distance checks/frame

**200 enemies, 200 bullets, 200 structures:**
- Spatial hash queries: ~4,500 wrapDistSq calls/frame (density increases in cells)
- Closest player: 800 wrapDistSq calls/frame
- Total: ~7,000 distance checks/frame
- **4.7x more work for 4x more entities** — super-linear due to density clustering

**500 enemies (boss wave):**
- Spatial hash cell overflow: 15-30 enemies per cell instead of 3-5
- Inner loop iterations jump 5-10x per query
- Pack cohesion even with LOD: 250 queries × 15 neighbors = 3,750 checks
- Total: ~15,000+ distance checks/frame

## The wrapDistSq Hot Path

**File:** `internal/engine/wrap.go`

Every distance calculation in the game passes through:

```go
func (e *GameEngine) wrapDistSq(a, b math2d.Vec2) float64 {
    if e.CaveActive {              // Branch 1: cave mode check
        return a.DistanceSq(b)
    }
    return WrapDistanceSq(a, b, e.WorldWidth, e.WorldHeight)
}

func WrapDistanceSq(a, b math2d.Vec2, w, h float64) float64 {
    d := WrapDelta(a, b, w, h)    // 4 more conditional branches
    return d.X*d.X + d.Y*d.Y
}

func WrapDelta(from, to math2d.Vec2, w, h float64) math2d.Vec2 {
    dx := to.X - from.X
    dy := to.Y - from.Y
    if dx > w/2 { dx -= w }       // Branch 2
    else if dx < -w/2 { dx += w } // Branch 3
    if dy > h/2 { dy -= h }       // Branch 4
    else if dy < -h/2 { dy += h } // Branch 5
    return math2d.Vec2{X: dx, Y: dy}
}
```

At 100 enemies: **3,000-5,000 calls/frame** = 180K-300K calls/second at 60fps.
At 500 enemies: **~15,000 calls/frame** = 900K calls/second.

Profiling shows `wrap.go:69` at 4.4% flat CPU time and `spatial_hash.go:320` at 4.9% flat — these are the actual innermost loops where the CPU spins.

## Enemy AI and Movement

### Per-Enemy Per-Frame Work

Each living enemy executes this pipeline every frame:

```
1. UpdateTimers()              — tick status effect timers       O(1)
2. UpdatePhysics()             — apply velocity, friction        O(1)
3. Find closest player         — O(P) = 4 distance checks       O(P)
4. canEnemyTraverse()          — terrain biome check             O(1)
5. updateEnemyMovement()       — steering vector calculation:
   a. Base direction to target                                   O(1)
   b. structureAvoidanceVector — spatial hash query              O(d_struct)
   c. enemyPackVector          — spatial hash query              O(d_local)
   d. Wobble/random offset                                       O(1)
   e. Normalize + blend vectors                                  O(1) with sqrt
6. resolveEnemyStructureCollisions — spatial hash query          O(d_struct)
7. Boss state machine (if boss)                                  O(1)
```

Total per enemy: ~3-4 spatial hash queries + 4 player distance checks + vector math.

### AI Pathfinding Heuristics

The enemy AI uses **weighted steering vectors** rather than full A* pathfinding:

1. **Move toward closest player** — simple direction vector
2. **Avoid structures** — repulsion from nearby walls/towers, weighted by `TowerFear` stat (flying enemies fear towers at 120px range, ground enemies at 55px)
3. **Pack cohesion/separation** — boids-style: cohesion toward nearby group center + separation from too-close neighbors (configurable radius 90-110px)
4. **Wobble** — sinusoidal offset to prevent perfect stacking

These vectors are blended with weights and normalized. The `math.Sqrt` in normalization is unavoidable and shows up in profiles.

The **autoplay AI** (for AI-controlled players) does use more sophisticated pathfinding:
- Nearest enemy targeting with distance weighting
- Group threat assessment (avoid large enemy clusters, weighted by count)
- Ability cooldown management
- Shows up as 5.9% cum in profiling (`autoplay.go:234`)

## Spatial Hash QueryCircle — The Hot Inner Loop

```go
// spatial_hash.go:284-368 (simplified)
func (h *SpatialHash[T]) QueryCircle(center Vec2, radius float64) []T {
    h.gen++                        // Bump generation for dedup
    h.result = h.result[:0]        // Reuse result slice

    // Pre-compute wrapped cell x-indices (fast path optimization)
    minCX, maxCX := cellRange(center.X, radius, h.cellSize)
    wrappedXs := precomputeWrappedX(minCX, maxCX, h.cols)  // Avoid modulo in loop

    minCY, maxCY := cellRange(center.Y, radius, h.cellSize)
    rSq := radius * radius

    for cy := minCY; cy <= maxCY; cy++ {
        wy := wrapY(cy, h.rows)
        for _, wx := range wrappedXs {       // Pre-computed x indices
            cell := h.grid[wy*h.cols + wx]   // Direct array index
            for _, entity := range cell {     // ← THIS IS THE HOT LOOP (line 320)
                id := entity.GetID()
                if h.seen[id] == h.gen {
                    continue                  // Already returned this entity
                }
                h.seen[id] = h.gen
                if distSq(center, entity.GetPos()) <= rSq {
                    h.result = append(h.result, entity)
                }
            }
        }
    }
    return h.result
}
```

**Why this doesn't scale linearly**: As enemy count increases, the average number of entities per cell increases. A query that scans 4-6 cells checking 3 entities each (18 iterations) at 50 enemies becomes 4-6 cells checking 15 entities each (90 iterations) at 250 enemies — **5x more inner loop iterations for the same query radius**.

## Rendering Scaling

### Per-Entity Draw Cost

| Entity Type | Draw Method | Cost Per Entity | Scales With |
|-------------|------------|-----------------|-------------|
| Enemy | DrawImage (sprite) | 1 draw call | E |
| Bullet (sprite) | DrawImage | 1 draw call | B |
| Bullet (fallback) | Batched circle | ~0 (batched) | 1 per flush |
| Particle (circle) | Batched DrawTriangles | ~0 (batched) | 1 per flush |
| Particle (text) | Font rendering | **6+ draw calls** (glyph × shadow) | T × glyphs |
| Structure | DrawImage + rotation | 1-2 draw calls | S |

**Text particles are the rendering bottleneck**: 50 damage numbers = ~300 individual glyph DrawImage calls. Cannot be batched because each has unique text content.

### Terrain (Not Scaling-Sensitive)

Terrain uses chunk compositing — tiles rendered to offscreen buffer, single blit to screen. Only redraws when camera moves 1+ tile. Cost is constant regardless of entity count.

## Why It's Non-Linear: Summary

```
Total frame cost ≈ C_base
                 + O(E + A)                    # Spatial hash rebuilds
                 + O(E × P)                    # Closest player search
                 + O(B × d_enemy)              # Bullet-enemy collision
                 + O(B × d_struct)             # Bullet-structure collision
                 + O(E × d_struct)             # Enemy-structure collision
                 + O(E × d_local)              # Pack cohesion
                 + O(E × d_struct)             # Structure avoidance
                 + O(E)                        # Per-entity timers, physics
                 + O(M × d_enemy)              # Magic projectile collision
                 + O(E + B + T_text)           # Rendering
```

The `d_X` terms (local density) are what cause non-linearity. As you add more entities:

1. **Linear terms** O(E), O(B) grow predictably
2. **Density terms** d_enemy, d_local grow **faster than linearly** because entities cluster around players, towns, and objectives
3. **Two spatial hash rebuilds** are pure O(E + A) overhead even before queries
4. **Cache pressure** increases — entity slices exceed L1/L2 cache at high counts
5. **GC pressure** from spatial hash result slices (mitigated by reuse, but still allocates when growing)

### Measured Scaling (Headless Profiling)

| Metric | 50 Enemies | 100 Enemies | 200 Enemies |
|--------|-----------|-------------|-------------|
| updateEnemies() | ~25% CPU | ~49% CPU | ~65% CPU |
| wrapDistSq calls/frame | ~1,500 | ~4,000 | ~12,000 |
| Spatial hash queries | ~200 | ~600 | ~1,800 |
| Frame time (headless) | ~0.03ms | ~0.07ms | ~0.2ms |

The jump from 100→200 enemies is **~3x** rather than 2x because of density clustering effects.

## Current Mitigations

1. **Spatial Hash** — reduces O(N²) collision to O(N × d), where d << N
2. **Pack Cohesion LOD** — halves pack queries when >80 enemies
3. **Per-enemy structure hit timer** — prevents spam (30-frame cooldown)
4. **Particle pressure scale** — reduces spawn rate when pool is 60%+ full
5. **Adaptive quality** — drops rendering tiers when FPS drops
6. **Auto-calibrating particle cap** — tunes MaxCount to hardware capability
7. **Circle batching** — 500 particle draws → 1 DrawTriangles call
8. **Terrain chunking** — constant cost regardless of entity count

## Potential Future Optimizations

1. **Spatial hash for closest-player search** — replace O(E×P) with O(E×d_player), though P=4 makes the gain marginal
2. **Enemy update LOD** — distant enemies (>2 screen widths from any player) update at half rate
3. **Collision group phases** — skip bullet-structure checks for bullets moving away from structures
4. **AABB pre-filter** — cheap axis-aligned check before expensive circle/OBB collision
5. **Entity pooling for spatial hash cells** — pre-allocate cell slices to avoid append growth
6. **wrapDistSq inlining** — remove cave mode branch, use compile-time constant for world size
