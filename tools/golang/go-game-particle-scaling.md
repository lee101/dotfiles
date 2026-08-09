# Why Particle Rendering Doesn't Scale (Go/Ebiten)

A practical analysis of particle system performance in 2D Go games, using BulletGo as a case study.

## The Problem

At 100 particles, rendering takes ~0.1ms. At 500 particles, it should take ~0.5ms. In practice it takes 2-3ms+ due to non-linear scaling. Why?

## Cost Breakdown Per Particle

### Update Loop (CPU): O(n) per particle

Each particle update does:
- Physics: velocity += gravity, velocity *= (1-friction), position += velocity
- Rotation: rotation += rotSpeed
- Size: size += growRate
- Life: life--, death check
- In-place compaction: dead particles returned to pool, live particles shifted

This is pure arithmetic — fast and linear. At 500 particles, Update() takes ~50μs. **Not the bottleneck.**

### Draw Loop (GPU): The real cost

Two categories of particles with very different costs:

**1. Circle particles (sparks, blood, smoke, fire, gold, explosions)**

After batching optimization (DrawTriangles): all circles in a single draw call.
- 500 circles → 1 DrawTriangles call with 2000 vertices + 3000 indices
- Cost: ~0.2ms regardless of count (up to vertex buffer capacity ~512 circles)
- **Scales well** after batching

**2. Text particles (damage numbers, gold amounts, heal numbers)**

Each text particle requires:
- Font glyph lookup and rendering via `rendertext.Draw()` / `rendertext.DrawShadow()`
- Each glyph = separate DrawImage call (Ebiten font rendering is character-by-character)
- Shadow text = 2x the glyph draws
- A 3-digit damage number "247" = 6 DrawImage calls (3 glyphs × 2 for shadow)
- Alpha blending for fade-out = additional compositor work

At 50 text particles (typical combat): 50 × ~6 = 300 individual DrawImage calls. **Does not scale.**

## Why It Gets Worse Under Load

The scaling problem isn't the steady-state particle count — it's the **burst spawn rate**:

1. **Enemy death cascade**: Each enemy death calls `SpawnDeathEffect()` (3-20 smoke + sparks) + `SpawnDamageNumber()` (1 text particle). A wave of 30 enemies dying in 2 seconds = 60-600 particles + 30 text particles spawned simultaneously.

2. **Boss attacks**: Area effects spawn particles at multiple hit points. A single boss telegraph + execution can spawn 50+ particles across all affected entities.

3. **Multi-player multiplier**: 4 players shooting = 4x bullet hit sparks. Each bullet hit calls `SpawnHitSparks()` (1-3 particles).

4. **Compound effects**: Explosions spawn smoke + sparks + core glow + damage numbers. A single explosion = 15-25 particles.

Peak spawn rate during intense combat: **200-500 particles/second**.

## Current Mitigation Stack

### Layer 1: Object Pool (particles.go)
- `pool []*Particle` free list recycles dead particle memory
- Avoids heap allocation for new particles
- In-place compaction avoids per-frame slice allocation
- **Impact**: Eliminates GC pressure from particle allocation

### Layer 2: Pressure Scale (particles.go)
```
Pool usage 0-60%:   spawn multiplier = 1.0 (full effects)
Pool usage 60-100%: spawn multiplier = 1.0→0.2 (linear ramp)
```
- Cosmetic particles (sparks, smoke) reduced first
- Text particles (damage numbers) are never dropped — they evict cosmetic particles if pool is full
- **Impact**: Prevents pool exhaustion, prioritizes gameplay feedback

### Layer 3: Adaptive Quality (renderer.go)
```
Tier 0 (>58 FPS):  ParticleScale = 1.0
Tier 1 (<50 FPS):  ParticleScale = 0.7, skip tile dressings
Tier 2 (still low): ParticleScale = 0.5, skip decorations
Tier 3 (critical):  ParticleScale = 0.3, skip blend overlays
```
- FPS-based with hysteresis (3s upgrade, 0.5s downgrade)
- ParticleScale feeds into pressureScale as a multiplier
- **Impact**: Reduces particle count by up to 70% on slow hardware

### Layer 4: Circle Batching (renderer.go)
- All circle-type particles batched into single DrawTriangles call
- Pre-allocated vertex/index buffers (512 circle capacity)
- **Impact**: 500 draw calls → 1 draw call for visual particles

### Layer 5: Hard Cap (settings.go)
- `Settings.ParticleCount` sets MaxCount (default 500)
- User-configurable in settings menu (50-500 range)
- Auto-calibration adjusts this based on hardware FPS (see below)

## The Remaining Bottleneck: Text Particles

After all optimizations, the dominant cost is text particle rendering:

| Particle Type | Count | Draw Calls | Time |
|--------------|-------|------------|------|
| 200 circle particles | 200 | 1 (batched) | ~0.1ms |
| 50 text particles | 50 | ~300 (glyphs) | ~2.0ms |
| **Total** | 250 | ~301 | ~2.1ms |

Text particles are **20x more expensive per-particle** than batched circles.

### Why text can't be batched
- Each damage number has unique text content
- Font rendering produces different glyphs per particle
- Glyph positions and sizes vary
- Ebiten's text rendering API doesn't support batched multi-string rendering

### Potential future mitigations (not yet implemented)
1. **Text particle sub-cap**: Separate MaxCount for text vs visual particles (e.g., 50 text max)
2. **Text atlas caching**: Pre-render common damage numbers ("1", "2", ... "999", "1.0K") as sprites, batch those
3. **Particle LOD**: Far-away particles rendered as simpler/smaller shapes or skipped entirely
4. **Text consolidation**: Combine rapid-fire damage numbers into accumulated totals

## Auto-Calibrating Particle Cap

The auto-calibration system adjusts `MaxCount` based on sustained FPS during actual gameplay:

- **Downgrade**: If Tier 3 (lowest quality) sustained for 10 seconds → reduce MaxCount by 20%
- **Upgrade**: If Tier 0 (full quality) sustained for 30 seconds → increase MaxCount by 10%
- Floor: 100 particles (minimum for gameplay feedback)
- Ceiling: User's configured `Settings.ParticleCount`
- Persisted to settings for next launch

This means: a low-end laptop might auto-settle at MaxCount=200, while a gaming desktop stays at 500. No user configuration needed.

## Recommendations for New Particle Effects

When adding new particle-spawning code:

1. **Always check `remaining()`** before spawning
2. **Use `pressureScale()`** to reduce cosmetic counts under load
3. **Prefer circle particles** over text particles when possible (20x cheaper)
4. **Cap per-effect particle counts** — explosion debris capped at 15, death effects at 20
5. **Avoid spawning in tight loops** — batch the spawn logic, don't call SpawnHitSparks() per-frame for persistent effects
6. **Text particles for gameplay info only** — damage numbers yes, decorative floating text no
