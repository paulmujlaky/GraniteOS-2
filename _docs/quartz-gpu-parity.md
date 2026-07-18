# Quartz GPU parity gate

The global virgl cutover is accepted only after the GPU path matches the retained software-reference capture matrix. Keep both images from every row; do not replace the established software reference with a GPU capture.

| Capture | Required state |
| --- | --- |
| `light-panel` | Light density, any Quartz panel over a high-contrast background |
| `medium-panel` | Medium density, any Quartz panel over a high-contrast background |
| `dark-panel` | Dark density, any Quartz panel over a high-contrast background |
| `header` | Decorated window with visible Quartz title treatment |
| `overlap` | At least two overlapping glass surfaces |
| `chromatic-edge` | Strong light/dark edge crossing the panel bezel |
| `damage-small` | Small client damage beneath a Quartz panel, after the resulting repaint |
| `damage-move` | Window movement beneath and just outside the panel's backdrop halo |
| `all-layers` | Every visible Quartz panel and decorated title bar is resolved by virgl |
| `resize-grow` | First settled frame after growing the display |
| `resize-shrink` | First settled frame after shrinking the display |

Use the retained `reference` images from the original software renderer and boot `zig build qemu-gpu` for new candidates. At each stable state, enter this in QEMU's monitor, changing the path and capture name:

```text
screendump _docs/quartz-parity/virgl/medium-panel.ppm
```

The GPU capture must retain the same panel bounds, material tint and coverage, frost radius, refracted edge position, rim clarity, and red/blue dispersion direction as its software reference. Damage captures must have no seam or stale pixel anywhere in the expanded backdrop halo, including just beyond a visible panel edge. Resize captures must show the restored CPU scanout, with no proof-frame pixels and no old-size content.

The serial metrics line is part of the gate. It must contain only `Quartz GPU` reports: no `Quartz CPU` resolver remains. Every damaged Quartz panel and title bar must contribute one resolve, one backdrop capture, and two blur passes. The reusable two-entry GPU workspace must avoid resource reconstruction for repeated layer geometries, and the resolve submission must contain only horizontal blur, vertical blur, and final material resolve; the redundant full-resolution copy pass is forbidden.

Finally repeat one candidate boot with virgl unavailable. The desktop must remain usable with flat window composition, without a Quartz IPC failure, CPU Quartz fallback, or blank scanout.
