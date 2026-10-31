(async () => {
  const T = window.THREE, ed = window.editor
  const n = +'$tris' || 1000000, mats = +'$objs' || 1
  const per = Math.round(n / mats), seg = Math.round(Math.sqrt(per))
  for (let i = 0; i < mats; i++) {
    const g = new T.SphereGeometry(10 / Math.cbrt(mats), seg, Math.round(seg / 2))
    const m = new T.Mesh(g, new T.MeshStandardMaterial({ color: 0x8899aa, roughness: 0.6 }))
    m.name = 'wb-big-' + i
    const s = Math.ceil(Math.cbrt(mats)); m.position.set((i % s) * 12 - s * 6, (Math.floor(i / s) % s) * 12, Math.floor(i / s / s) * 12 - s * 6)
    ed.scene.add(m)
  }
  ed.signals.sceneGraphChanged.dispatch()
  window.__bigDone = true
})()
