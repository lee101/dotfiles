(async () => {
  const T = window.THREE, ed = window.editor
  const g = new T.BufferGeometry().copy(new T.SphereGeometry(10, 700, 700))
  const m = new T.Mesh(g, new T.MeshStandardMaterial()); ed.scene.add(m)
  let t = performance.now(); const j = ed.toJSON(); const a = performance.now() - t
  t = performance.now(); const s = JSON.stringify(j); const b = performance.now() - t
  t = performance.now(); JSON.parse(s); const c = performance.now() - t
  return { toJSON: Math.round(a), stringify: Math.round(b), parse: Math.round(c), MB: Math.round(s.length / 1048576) }
})()
