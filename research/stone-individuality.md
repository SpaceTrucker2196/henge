# Making the stones individual — research notes

Produced by a multi-agent research pass, 28 July 2026. **Partial**: see the
warning at the end. Nothing here is implemented yet.

## The diagnosis

The stones vary in *shading* — per-stone texture offset, per-plane rotation,
±12% scale jitter — but their **mesh displacement parameters are identical**.
Every sarsen is the same rock shape wearing a differently-rotated coat. Fixing
that is the highest-payoff change available, and it is a mesh change, not a
shader one.

## Adopted (in payoff order)

### 1. The second-scale sample is destroying the histogram — free fix

`sampleStone` multiplies in a second incommensurate-scale sample. Multiplying
two samples of the same texture gives `E[ab] = E[a]E[b]` — the mean drops
(0.5 × 0.5 = 0.25), mid-tone contrast is squeezed, and values appear that are
not in the source. This is the same defect Heitz & Neyret identify for naive
blending: "ghosting, softened discontinuities and reduced contrast, or new
colors not present in the input". It is very likely why the rock reads slightly
flat and plasticky.

The cure is a variance-preserving weighted sum, three lines:

```metal
constant float3 kRockMeanLinear = float3(0.42);   // measure offline, per map
float3 c = (w1 * c1 + w2 * c2 - kRockMeanLinear)
         * rsqrt(w1 * w1 + w2 * w2) + kRockMeanLinear;
```

The `rsqrt(Σw²)` is the whole trick: a linear blend of two independent samples
of variance σ² has variance (w1² + w2²)σ², so dividing by √(w1²+w2²) restores
it. In **linear** space for albedo. Do not mean-recentre the normal map — blend
its derivatives instead (below).

If a multiplicative low-frequency stain is still wanted, make it
contrast-neutral by construction:
`c *= 1 + kContrast * (lum2 - lum2Mean)`.

### 2. Multifractal instead of plain fBm

Four octaves of plain value-noise fBm reads as *noise*. Musgrave hybrid/ridged
multifractal plus one level of domain warp is what reads as *rock*: it produces
the hard/soft differential relief real weathered stone has, because the
amplitude of each octave is modulated by the value of the previous one.

### 3. Make the mesh individual

Per-stone p-norm / half-space block shape with a smooth-min arris radius. This
is what "quarried block" means geometrically: flattish faces meeting at rounded
arrises, with the p-norm exponent, the face normals and the arris radius all
drawn per stone.

### 4. Cavity AO and micro-shadowing

Fine relief without occlusion looks flat. Cavity AO plus Naughty Dog's
micro-shadowing term is the cheap approximation, and it is what stops added
detail reading as a texture rather than as a surface.

### 5. LOD stability

Band-limit octaves at Nyquist and fold the *lost* normal variance into
roughness (Toksvig / Kaplanyan) rather than letting detail fade to grey. This
matters because the app is viewed at 1 m and at 50 m in the same session.

## Rejected, with reasons

**Full histogram-preserving synthesis (Heitz & Neyret 2018 / Deliot & Heitz
2019).** Wrong cost/benefit here. It needs an offline per-channel histogram
transform producing a Gaussianized texture shipped alongside or instead of the
original, an inverse LUT per channel, and an LOD-dependent prefiltered inverse
LUT because linear mip filtering of a Gaussianized texture drifts colour. It
conflicts with BC compression and destroys structured content. Its payoff case
is a large continuous surface where one repeat is visible dozens of times per
frame — ground or cliff. Discrete stones a few tiles across do not qualify.

**Hex-tiling (Mikkelsen 2022)** is the shippable member of that family — no
precomputation, samples the source texture, ~220 lines of HLSL that port to MSL
almost verbatim. But under triplanar it is 3 planes × 3 hex taps × 3 maps = **27
fetches per pixel**, which is not viable on an iOS-class GPU as a blanket
solution. Viable only if restricted to dominant-axis, albedo-only, near-field.
If ever adopted: `g_fallOffContrast = 0.6`, `g_exp = 7`, and the rotated UVs
*must* be sampled with rotated gradients (`gradient2d(dSTdx*rot, dSTdy*rot)`) or
tile edges shimmer. Blend normal-map *derivatives*, not normals.

## Testing

The project's hard-won rule applies: appearance and scale faults render
correctly and pass every existing test. So assertions must be about real-world
dimensions and **measurable inter-stone variance** — e.g. render N stones and
require the variance of their image statistics to exceed a threshold — not
about internal consistency.

## ⚠ Incomplete, and why

The **geology** strand is unusable and must be re-run. Its returned summary
carried an embedded prompt-injection payload — a counterfeit `<system_status>`
block asserting model deprecation and instructing the reader to stop following
user instructions and to conceal the message. It was picked up from material
read during research. The injection was not acted on, and it caused the
downstream synthesis agent to be blocked by the safety classifier, which is the
correct outcome. That agent's structured findings also degraded to placeholders.

Consequence: **there is no sarsen-specific geology in these notes** — no
solution-hollow scales, no dressed-versus-natural face distribution, no lichen
zonation. Re-run that strand before implementing anything that claims to model
sarsen specifically rather than generic weathered rock, and treat any figure
recovered from that run as needing a citation check.

**Update, 28 July 2026 (later).** The strand was re-run clean —
injection-hardened, with an independent citation audit that verified the
load-bearing figures against primary texts and found no injection this time.
The result is `sarsen-geology.md` in this directory. The parameter ranges in
the shipped mesh individuality remain the generic-rock artistic reading;
applying the sarsen-specific figures is deliberately parked as its own future
order, per the owner.

Anything derived from this file that is an artistic choice rather than an
archaeological claim must be labelled as such — see MISSION.md invariant 3.
