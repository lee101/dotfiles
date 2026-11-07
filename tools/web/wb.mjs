import { chromium } from 'playwright-core'
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const HERE = dirname(fileURLToPath(import.meta.url))
const OUT = join(HERE, 'out')
const BROKER = process.env.GPU_BROKER || 'http://127.0.0.1:8791'
const USAGE = `wb bench <url|stress:mode?n=..> [--secs 5] [--w 1280] [--h 720] [--gpu] [--orbit] [--cpu] [--json] [--ready expr] [--eval file.js (\$name -> --name)] [--after expr] [--settle ms]
wb matrix <mode,mode> <n,n> [--gpu] [--secs 3] [stress params as --pr 1 --seg 16 --aa 0 --shadow 1]
wb top <file.cpuprofile> [--n 20] [--match str] [--callers fn] [--stack fn --depth 7]
wb stress   (serve scene on :9500)
stress modes: naive shared instanced batched merged`

function parse(argv) {
  const a = { _: [] }
  for (let i = 0; i < argv.length; i++) {
    const t = argv[i]
    if (!t.startsWith('--')) { a._.push(t); continue }
    const k = t.slice(2), v = argv[i + 1]
    if (v === undefined || v.startsWith('--')) a[k] = true
    else { a[k] = isNaN(+v) ? v : +v; i++ }
  }
  return a
}

const HOOK = `(() => {
  const S = { draws: 0, tris: 0, marks: [], ev: [] }
  window.__wb = S
  const tri = (m, c) => m === 4 ? c / 3 : (m === 5 || m === 6) ? Math.max(c - 2, 0) : 0
  for (const C of [window.WebGLRenderingContext, window.WebGL2RenderingContext]) {
    if (!C) continue
    const P = C.prototype
    const w = (n, f) => { const o = P[n]; if (o) P[n] = function (...a) { f(a); return o.apply(this, a) } }
    w('drawArrays', a => { S.draws++; S.tris += tri(a[0], a[2]) })
    w('drawElements', a => { S.draws++; S.tris += tri(a[0], a[1]) })
    w('drawArraysInstanced', a => { S.draws++; S.tris += tri(a[0], a[2]) * a[3] })
    w('drawElementsInstanced', a => { S.draws++; S.tris += tri(a[0], a[1]) * a[4] })
    w('drawRangeElements', a => { S.draws++; S.tris += tri(a[0], a[4]) })
    const ge = P.getExtension
    P.getExtension = function (n) {
      const e = ge.call(this, n)
      if (e && n === 'WEBGL_multi_draw' && !e.__wb) {
        e.__wb = 1
        const m = e.multiDrawElementsWEBGL
        e.multiDrawElementsWEBGL = function (mode, counts, co, type, oo, offo, n) { S.draws++; for (let i = 0; i < n; i++) S.tris += tri(mode, counts[co + i]); return m.apply(this, arguments) }
        const m2 = e.multiDrawArraysWEBGL
        e.multiDrawArraysWEBGL = function (mode, f, fo, c, co, n) { S.draws++; for (let i = 0; i < n; i++) S.tris += tri(mode, c[co + i]); return m2.apply(this, arguments) }
      }
      return e
    }
  }
  let last = -1
  const raf = window.requestAnimationFrame.bind(window)
  window.requestAnimationFrame = cb => raf(t => { if (t !== last) { last = t; S.marks.push([t, S.draws, S.tris]) } cb(t) })
  new PerformanceObserver(l => { for (const e of l.getEntries()) S.ev.push([e.entryType, e.startTime, e.duration]) }).observe({ entryTypes: ['longtask', 'event'], buffered: true })
})()`

const pct = (s, p) => s[Math.min(s.length - 1, Math.floor(s.length * p))]
function stats(marks) {
  if (marks.length < 3) return { frames: marks.length }
  const dt = [], d = [], tr = []
  for (let i = 1; i < marks.length; i++) { dt.push(marks[i][0] - marks[i - 1][0]); d.push(marks[i][1] - marks[i - 1][1]); tr.push(marks[i][2] - marks[i - 1][2]) }
  const s = [...dt].sort((a, b) => a - b), avg = dt.reduce((x, y) => x + y) / dt.length
  const ds = [...d].sort((a, b) => a - b), ts = [...tr].sort((a, b) => a - b)
  return {
    frames: dt.length, fps: +(1000 / avg).toFixed(1), ms50: +pct(s, .5).toFixed(1), ms95: +pct(s, .95).toFixed(1), ms99: +pct(s, .99).toFixed(1), max: +s[s.length - 1].toFixed(1),
    draws: Math.round(pct(ds, .5)), tris: Math.round(pct(ts, .5))
  }
}

async function lease() {
  try {
    const r = await fetch(BROKER + '/v1/gpu/lease', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ owner: 'wb-bench', pid: process.pid, mb: 1500, min_mb: 1500, tier: 'free', ttl_s: 180, wait_ms: 30000, force: false }) })
    if (r.status !== 200) throw new Error(r.status + ' ' + (await r.text()).slice(0, 200))
    return (await r.json()).lease_id
  } catch (e) { throw new Error('gpu lease failed: ' + e.message) }
}
const release = id => id && fetch(BROKER + '/v1/gpu/release', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ lease_id: id }) }).catch(() => {})

function serveStress(port = 0) {
  const three = join(HERE, 'node_modules/three')
  return Bun.serve({
    port, async fetch(req) {
      const p = new URL(req.url).pathname
      if (p === '/favicon.ico') return new Response(null, { status: 204 })
      if (p === '/') return new Response(Bun.file(join(HERE, 'scenes/stress.html')))
      if (p.startsWith('/three/')) { const f = Bun.file(join(three, p.slice(7))); return (await f.exists()) ? new Response(f) : new Response('nf', { status: 404 }) }
      return new Response('nf', { status: 404 })
    }
  })
}

async function runPage(url, o) {
  const args = ['--no-sandbox', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows', '--disable-frame-rate-limit', '--disable-gpu-vsync', '--enable-precise-memory-info', '--js-flags=--expose-gc']
  if (o.gpu) args.push('--use-angle=vulkan', '--enable-features=Vulkan', '--ignore-gpu-blocklist', '--enable-gpu-rasterization', '--disable-vulkan-surface')
  else args.push('--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist')
  const exe = process.env.WB_CHROME || (existsSync(process.env.HOME + '/.local/bin/google-chrome') ? process.env.HOME + '/.local/bin/google-chrome' : undefined)
  const leaseId = o.gpu ? await lease() : null
  const br = await chromium.launch({ headless: true, executablePath: exe, args })
  try {
    const ctx = await br.newContext({ viewport: { width: o.w || 1280, height: o.h || 720 } })
    const page = await ctx.newPage()
    const errs = []
    page.on('pageerror', e => errs.push(String(e.message).slice(0, 200)))
    page.on('response', r => { if (r.status() >= 400) errs.push(r.status() + ' ' + r.url().replace(/^https?:\/\/[^/]+/, '').slice(0, 100)) })
    page.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) errs.push(m.text().slice(0, 200)) })
    await page.addInitScript(HOOK)
    const cdp = await ctx.newCDPSession(page)
    await cdp.send('Performance.enable')
    const t0 = Date.now()
    let evalOut
    await page.goto(url, { waitUntil: 'load', timeout: 120000 })
    if (o.ready) await page.waitForFunction(o.ready, null, { timeout: 120000 })
    else await page.waitForFunction(() => window.__ready || window.__wb.marks.length > 30, null, { timeout: 120000 }).catch(() => {})
    const load = Date.now() - t0
    if (o.eval) evalOut = await page.evaluate(readFileSync(o.eval, 'utf8').replace(/\$(\w+)/g, (m, k) => o[k] ?? m))
    if (o.after) await page.waitForFunction(o.after, null, { timeout: 120000 })
    const gl = await page.evaluate(() => { const c = document.createElement('canvas').getContext('webgl2'); const e = c && c.getExtension('WEBGL_debug_renderer_info'); return e ? c.getParameter(e.UNMASKED_RENDERER_WEBGL) : 'none' })
    await page.waitForTimeout(o.settle || 800)
    const secs = (o.secs || 5) * 1000
    const m0 = await cdp.send('Performance.getMetrics')
    if (o.cpu) await cdp.send('Profiler.enable'), await cdp.send('Profiler.setSamplingInterval', { interval: 500 }), await cdp.send('Profiler.start')
    let i0 = await page.evaluate(() => window.__wb.marks.length)
    await page.waitForTimeout(secs)
    let i1 = await page.evaluate(() => window.__wb.marks.length)
    let orbit = null
    if (o.orbit) {
      const w = o.w || 1280, h = o.h || 720
      await page.mouse.move(w / 2, h / 2); await page.mouse.down()
      const end = Date.now() + secs; let k = 0
      while (Date.now() < end) { k++; await page.mouse.move(w / 2 + Math.sin(k / 8) * w / 4, h / 2 + Math.cos(k / 11) * h / 6); await page.waitForTimeout(8) }
      await page.mouse.up()
      const i2 = await page.evaluate(() => window.__wb.marks.length)
      orbit = [i1, i2]
    }
    const m1 = await cdp.send('Performance.getMetrics')
    const res = await page.evaluate(([a, b, c]) => {
      const S = window.__wb, mem = performance.memory
      return { idle: S.marks.slice(a, b), orbit: c ? S.marks.slice(c[0], c[1]) : null, lt: S.ev.filter(e => e[0] === 'longtask').length, ltMs: Math.round(S.ev.filter(e => e[0] === 'longtask').reduce((x, e) => x + e[2], 0)), ltMax: Math.round(Math.max(0, ...S.ev.filter(e => e[0] === 'longtask').map(e => e[2]))), evMax: Math.round(Math.max(0, ...S.ev.filter(e => e[0] === 'event').map(e => e[2]))), heapMB: mem ? Math.round(mem.usedJSHeapSize / 1048576) : null, canvas: [...document.querySelectorAll('canvas')].map(c => c.width + 'x' + c.height).join(',') }
    }, [i0, i1, orbit])
    let prof = null
    if (o.cpu) { prof = (await cdp.send('Profiler.stop')).profile; mkdirSync(OUT, { recursive: true }); prof.__file = join(OUT, `cpu-${Date.now()}.cpuprofile`); writeFileSync(prof.__file, JSON.stringify(prof)) }
    const mv = n => (m1.metrics.find(x => x.name === n)?.value ?? 0) - (m0.metrics.find(x => x.name === n)?.value ?? 0)
    const out = {
      ...(evalOut !== undefined ? { eval: evalOut } : {}), url, mode: o.gpu ? 'gpu' : 'sw', gl, loadMs: load, canvas: res.canvas, idle: stats(res.idle), ...(res.orbit ? { orbit: stats(res.orbit) } : {}),
      cpu: { script: +(mv('ScriptDuration') / (secs / 1000 * (o.orbit ? 2 : 1))).toFixed(2), task: +(mv('TaskDuration') / (secs / 1000 * (o.orbit ? 2 : 1))).toFixed(2), layouts: mv('LayoutCount'), recalc: mv('RecalcStyleCount') },
      heapMB: res.heapMB, longtasks: res.lt, longtaskMs: res.ltMs, longtaskMax: res.ltMax, maxEventMs: res.evMax, errors: errs.slice(0, 5), ...(prof ? { profile: prof.__file } : {})
    }
    return { out, prof }
  } finally { await br.close(); await release(leaseId) }
}

function fmt(r) {
  const f = s => s.fps === undefined ? `frames=${s.frames}` : `${s.fps}fps p50=${s.ms50} p95=${s.ms95} p99=${s.ms99} max=${s.max}ms draws=${s.draws} tris=${s.tris}`
  const l = [...(r.eval !== undefined ? ['eval: ' + JSON.stringify(r.eval)] : []), `${r.url} [${r.mode}] ${r.gl.slice(0, 60)}`, `idle  ${f(r.idle)}`]
  if (r.orbit) l.push(`orbit ${f(r.orbit)}`)
  l.push(`cpu/s script=${r.cpu.script} task=${r.cpu.task} layouts=${r.cpu.layouts} | heap=${r.heapMB}MB load=${r.loadMs}ms longtasks=${r.longtasks}(${r.longtaskMs}ms,max ${r.longtaskMax}ms) maxEvent=${r.maxEventMs}ms canvas=${r.canvas}`)
  if (r.errors.length) l.push('errors: ' + r.errors.join(' | '))
  if (r.profile) l.push('profile: ' + r.profile)
  return l.join('\n')
}

function analyze(prof, { n = 20, match, callers, stack, depth = 7 }) {
  const nodes = new Map(prof.nodes.map(x => [x.id, x]))
  const parent = new Map()
  for (const x of prof.nodes) for (const c of x.children || []) parent.set(c, x.id)
  const dt = prof.timeDeltas, self = new Map()
  for (let i = 0; i < prof.samples.length; i++) self.set(prof.samples[i], (self.get(prof.samples[i]) || 0) + (dt[i] || 0))
  const name = x => { const c = x.callFrame; return `${c.functionName || '(anon)'} ${(c.url || '').split('/').slice(-2).join('/')}:${c.lineNumber + 1}` }
  const agg = new Map(), cal = new Map()
  let total = 0
  for (const [id, t] of self) {
    total += t
    const k = name(nodes.get(id))
    agg.set(k, (agg.get(k) || 0) + t)
    if (callers && k.startsWith(callers)) { const p = parent.get(id); const pk = p ? name(nodes.get(p)) : 'root'; cal.set(pk, (cal.get(pk) || 0) + t) }
  }
  if (stack) {
    const ch = new Map()
    for (const [id, t] of self) {
      const k = name(nodes.get(id))
      if (!k.includes(stack)) continue
      const c = []
      for (let p = id; p && c.length < depth; p = parent.get(p)) { const nm = name(nodes.get(p)); if (!nm.startsWith('(root)') && !nm.startsWith('(program)')) c.push(nm.replace(/ \S*\//, ' ')) }
      const key = c.reverse().join('\n    > ')
      ch.set(key, (ch.get(key) || 0) + t)
    }
    return [...ch].sort((a, b) => b[1] - a[1]).slice(0, n).map(([k, t]) => `${(t / 1000).toFixed(0)}ms  ${k}`).join('\n')
  }
  const src = callers ? cal : agg
  const rows = [...src].filter(([k]) => !match || k.includes(match)).sort((a, b) => b[1] - a[1]).slice(0, n)
  return `total ${(total / 1000).toFixed(0)}ms${callers ? ` callers of ${callers}` : ''}\n` + rows.map(([k, t]) => `${(t / 1000).toFixed(1).padStart(8)}ms ${(100 * t / total).toFixed(1).padStart(5)}%  ${k}`).join('\n')
}

function stressUrl(base, o) {
  const q = new URLSearchParams()
  for (const k of ['pr', 'seg', 'aa', 'shadow', 'lod']) if (o[k] !== undefined) q.set(k, o[k])
  return base + (base.includes('?') ? '&' : '?') + q
}

const a = parse(process.argv.slice(2)), cmd = a._[0]
if (cmd === 'bench') {
  let url = a._[1], srv
  if (!url) { console.log(USAGE); process.exit(1) }
  if (url.startsWith('stress:')) { srv = serveStress(); url = stressUrl(`http://localhost:${srv.port}/?mode=${url.slice(7).replace('?', '&')}`, a) }
  const { out, prof } = await runPage(url, a)
  srv?.stop()
  console.log(a.json ? JSON.stringify(out) : fmt(out))
  if (prof) console.log(analyze(prof, { n: 12 }))
} else if (cmd === 'matrix') {
  const srv = serveStress(), modes = String(a._[1] || 'naive,instanced').split(','), ns = String(a._[2] || '1000,10000').split(',')
  console.log('mode n | fps p95ms draws tris | script/s heapMB')
  for (const m of modes) for (const n of ns) {
    try {
      const { out } = await runPage(stressUrl(`http://localhost:${srv.port}/?mode=${m}&n=${n}`, a), { ...a, secs: a.secs || 3 })
      const s = out.idle
      console.log(`${m} ${n} | ${s.fps}fps ${s.ms95} ${s.draws} ${s.tris} | ${out.cpu.script} ${out.heapMB}${out.errors.length ? ' ERR ' + out.errors[0] : ''}`)
    } catch (e) { console.log(`${m} ${n} | FAIL ${String(e.message).slice(0, 100)}`) }
  }
  srv.stop()
} else if (cmd === 'top') {
  console.log(analyze(JSON.parse(readFileSync(a._[1], 'utf8')), a))
} else if (cmd === 'stress') {
  const s = serveStress(9500); console.log(`http://localhost:${s.port}/?mode=instanced&n=10000`)
} else console.log(USAGE)
