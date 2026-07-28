//
//  Henge.metal — the light on the stones.
//
//  Compiled from source at renderer start (see FACTORY.md, "Shader build
//  integration"). Struct layouts must stay in step with ShaderTypes.swift by
//  hand; a mismatch shows up as geometry in the wrong place, not as an error.
//

#include <metal_stdlib>
using namespace metal;

// ── shared layouts ──────────────────────────────────────────────────────────

struct FrameUniforms {
    float4x4 viewProjection;
    float4x4 view;
    float4x4 projection;
    float4   cameraPosition;
    float4   sunDirection;   // toward the sun
    float4   sunRadiance;    // rgb radiance, w = angular radius (radians)
    float4x4 shadowMatrices[3];
    float4x4 inverseViewProjection;
    float4   cascadeSplits;
    float4   skyParameters;  // x turbidity, y exposure, z time, w shadow texel
    float4   moonDirection;  // toward the moon, w = angular radius
    float4   moonLight;      // rgb radiance, w = illuminated fraction
    float4   cascadeRadii;   // xyz: half-extent in metres of each cascade's ortho
                             // box. w: how many radii deep that box runs
    float4   wind;           // xz: unit direction the wind blows toward,
                             // y: speed in m/s, w: seconds of wind time
    float4   grass;          // x: blade radius in metres, y: fade width, zw spare
    float4   night;          // rgb night ambient, w: visibility floor
    float4   season;         // rgb vegetation tint, w: dryness
    float4   shadowSource;   // x: 0 sun-cast shadows, 1 moon-cast
    float4   haze;           // x: scatter per metre (0 skips the pass),
                             // y: march distance m, z: scale height m, w spare
};

struct DrawUniforms {
    float4x4 model;
    float4x4 normalMatrix;
    float4   albedo;         // rgb albedo, w = roughness
    float4   surface;        // x: 0 stone / 1 ground, y: metres per texture tile,
                             // z: normal strength, w: 1 textured / 0 flat
    float4   weather;        // x: world Y of the stone's foot, y: lichen amount,
                             // z: damp rise in metres, w: per-stone seed
    float4   reflectance;    // x: specular strength, y: roughness floor,
                             // z: 1 if the surface takes wind, w: spare
};

struct Vertex {
    float4 position [[attribute(0)]];   // w: 0 bare soil … 1 turf
    float4 normal   [[attribute(1)]];
};

struct SceneInOut {
    float4 clipPosition [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float  viewDepth;
    float  turf;             // 0 bare soil … 1 turf, for the soil banks
};

// ── depth-only pass, for the shadow cascades ────────────────────────────────

vertex float4 shadow_vertex(Vertex in [[stage_in]],
                            constant DrawUniforms &draw [[buffer(1)]],
                            constant float4x4 &lightViewProjection [[buffer(2)]])
{
    float4 world = draw.model * float4(in.position.xyz, 1.0);
    return lightViewProjection * world;
}

// ── main scene pass ─────────────────────────────────────────────────────────

vertex SceneInOut scene_vertex(Vertex in [[stage_in]],
                               constant FrameUniforms &frame [[buffer(0)]],
                               constant DrawUniforms &draw [[buffer(1)]])
{
    SceneInOut out;
    float4 world = draw.model * float4(in.position.xyz, 1.0);
    out.worldPosition = world.xyz;
    out.worldNormal = normalize((draw.normalMatrix * float4(in.normal.xyz, 0.0)).xyz);
    out.turf = in.position.w;
    out.clipPosition = frame.viewProjection * world;
    out.viewDepth = -(frame.view * world).z;
    return out;
}

// Cook–Torrance GGX. Sarsen is a rough dielectric, so there is no metallic
// term: F0 is fixed at the 0.04 every non-metal shares.
static float distributionGGX(float3 n, float3 h, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float ndoth = max(dot(n, h), 0.0);
    float d = ndoth * ndoth * (a2 - 1.0) + 1.0;
    return a2 / max(M_PI_F * d * d, 1e-7);
}

static float geometrySmith(float3 n, float3 v, float3 l, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    float ndotv = max(dot(n, v), 0.0);
    float ndotl = max(dot(n, l), 0.0);
    float ggxv = ndotv / (ndotv * (1.0 - k) + k);
    float ggxl = ndotl / (ndotl * (1.0 - k) + k);
    return ggxv * ggxl;
}

static float3 fresnelSchlick(float cosTheta, float3 f0)
{
    return f0 + (1.0 - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Percentage-closer *soft* shadows, with the penumbra derived rather than dialled.
//
// The sun is not a point. It subtends about 0.53°, so every shadow edge on
// Salisbury Plain is a penumbra whose width is set by one thing: how far the
// blocker stands above the surface catching its shadow. A stone 4 m above the
// ground casts an edge about 4 × tan(0.53°) ≈ 3.7 cm soft; the same stone at a
// low midwinter sun, throwing a shadow forty metres, softens that edge to
// nearly 40 cm. You can watch that happen at the monument, and it is why a
// fixed blur looks wrong at every hour except the one it was tuned for.
//
// So nothing here is a tuned radius. `sunRadiance.w` carries the sun's angular
// radius in radians — the same number the disc is drawn with — and
// `cascadeRadii` converts shadow-map units back to metres and out again. Change
// the sun's size and the shadows follow.
//
// Three steps, the standard PCSS shape (Fernando 2005):
//   1. search a small neighbourhood for anything blocking, and average its depth
//   2. that gives blocker-to-receiver distance, and thus the penumbra width
//   3. filter over exactly that width
//
// Step 1 is the expensive one and the reason the search radius is capped: an
// unbounded search over a 15 km ground plane would sample the far cascade's
// entire texture for a pixel at the horizon.
constant float2 kPoissonDisk[16] = {
    float2(-0.613392,  0.617481), float2( 0.170019, -0.040254),
    float2(-0.299417,  0.791925), float2( 0.645680,  0.493210),
    float2(-0.651784,  0.717887), float2( 0.421003,  0.027070),
    float2(-0.817194, -0.271096), float2(-0.705374, -0.668203),
    float2( 0.977050, -0.108615), float2( 0.063326,  0.142369),
    float2( 0.203528,  0.214331), float2(-0.667531,  0.326090),
    float2(-0.098422, -0.295755), float2(-0.885922,  0.215369),
    float2( 0.566637,  0.605213), float2( 0.039766, -0.396100)
};

static float sampleShadow(depth2d_array<float> shadowMap,
                          sampler shadowSampler,
                          float3 worldPosition,
                          constant FrameUniforms &frame,
                          float viewDepth,
                          float ndotl)
{
    uint cascade = 2;
    if (viewDepth < frame.cascadeSplits.x)      cascade = 0;
    else if (viewDepth < frame.cascadeSplits.y) cascade = 1;

    float4 lightClip = frame.shadowMatrices[cascade] * float4(worldPosition, 1.0);
    float3 projected = lightClip.xyz / lightClip.w;

    float2 uv = projected.xy * float2(0.5, -0.5) + 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || projected.z > 1.0) {
        return 1.0;
    }

    // Slope-scaled depth bias, kept deliberately small.
    //
    // Bias buys freedom from self-shadowing acne and pays for it in
    // peter-panning: the shadow detaches from its caster and falls short. Here
    // that shortfall is not a cosmetic nuisance, it is measurement error in a
    // calendar — at 30° elevation a bias of 0.0015 pulled the shadow tip a
    // third of a metre in, which the agreement test caught. Culling front
    // faces in the shadow pass already removes most acne, so the bias only has
    // to cover depth quantisation.
    float bias = mix(0.00035, 0.00004, clamp(ndotl, 0.0, 1.0));

    float texel = frame.skyParameters.w;
    float radius = frame.cascadeRadii[cascade];      // metres, half the ortho box
    // The ortho box spans 2r across, and cascadeRadii.w deep — passed rather
    // than hardcoded, so the depth span cannot drift out of step with
    // `cascadeMatrix` and quietly mis-scale every penumbra.
    float metresPerDepth = radius * frame.cascadeRadii.w;
    float metresPerUV    = radius * 2.0;

    // ── 1. blocker search ───────────────────────────────────────────────────
    //
    // The search radius follows the sun too, and it has to. A fixed eight-texel
    // search caps the filter: quadruple the sun's angular size and the penumbra
    // widens by only a third, because the clamp below never lets the filter
    // exceed the region the blocker was found in.
    //
    // The right radius falls out of the geometry. A blocker at distance d gives
    // a penumbra of half-width d·tan(θ) metres, which in UV is d·tan(θ)/(2r).
    // For a blocker within one cascade radius — d ≤ r — that is at most
    // tan(θ)/2, independent of r. Doubling it for headroom on nearer cascades
    // gives tan(θ), which at 0.53° is about nine texels at 2048: near enough to
    // the constant it replaces, but now it scales with the light.
    float searchUV = clamp(tan(frame.sunRadiance.w), 2.0 * texel, 0.05);
    float blockerSum = 0.0;
    float blockerCount = 0.0;
    for (int i = 0; i < 16; ++i) {
        float depth = shadowMap.sample(shadowSampler,
                                       uv + kPoissonDisk[i] * searchUV, cascade);
        if (depth < projected.z - bias) {          // something is in the way
            blockerSum += depth;
            blockerCount += 1.0;
        }
    }
    if (blockerCount == 0.0) { return 1.0; }       // fully lit, nothing to filter

    // ── 2. penumbra width from the sun's actual angular size ────────────────
    float blockerDepth = blockerSum / blockerCount;
    float distanceMetres = max((projected.z - blockerDepth) * metresPerDepth, 0.0);
    // Full angular diameter: sunRadiance.w is the radius.
    float penumbraMetres = distanceMetres * tan(frame.sunRadiance.w) * 2.0;
    float penumbraUV = penumbraMetres / metresPerUV;
    // Never narrower than one texel — below that the filter is just aliasing —
    // and never wider than the search that found the blocker, or the estimate
    // would be filtering over casters it never looked at.
    float filterUV = clamp(penumbraUV * 0.5, texel, searchUV);

    // ── 3. filter over exactly that width ───────────────────────────────────
    float sum = 0.0;
    for (int i = 0; i < 16; ++i) {
        float depth = shadowMap.sample(shadowSampler,
                                       uv + kPoissonDisk[i] * filterUV, cascade);
        sum += (projected.z - bias) <= depth ? 1.0 : 0.0;
    }
    return sum / 16.0;
}

// ── noise ───────────────────────────────────────────────────────────────────
//
// Shared by the weathering and the wind, and declared up here because MSL has
// no forward declarations: putting it beside its first user left `windField`
// calling an `fbm` the compiler had not seen yet, and the whole library failed
// to build. Nothing rendered at all, which the suite caught immediately — the
// one failure mode a pixel test cannot miss.

static float hash13(float3 p)
{
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

static float valueNoise(float3 p)
{
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);          // smoothstep, so the derivative is continuous

    float n000 = hash13(i + float3(0, 0, 0)), n100 = hash13(i + float3(1, 0, 0));
    float n010 = hash13(i + float3(0, 1, 0)), n110 = hash13(i + float3(1, 1, 0));
    float n001 = hash13(i + float3(0, 0, 1)), n101 = hash13(i + float3(1, 0, 1));
    float n011 = hash13(i + float3(0, 1, 1)), n111 = hash13(i + float3(1, 1, 1));

    float nx00 = mix(n000, n100, f.x), nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x), nx11 = mix(n011, n111, f.x);
    return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

static float fbm(float3 p)
{
    float sum = 0.0, amplitude = 0.5;
    for (int i = 0; i < 4; ++i) {
        sum += amplitude * valueNoise(p);
        p *= 2.03;                         // not exactly 2, to avoid the octaves
        amplitude *= 0.5;                  // lining their features up
    }
    return sum;
}

// ── surface texture ─────────────────────────────────────────────────────────
//
// The stones carry no UVs, deliberately: `StoneMesh` welds a box grid and any
// unwrap of that shape seams somewhere visible. So the rock is mapped
// triplanar — sampled three times along the world axes and blended by the
// surface normal — which needs no UVs at all and cannot seam, at the cost of
// three fetches where one would do. On a scene of eighty stones that is a
// trade worth making.
//
// The ground has an obvious parameterisation (world X and Z) and takes a
// single tiled fetch.
//
// **The photograph supplies detail, not colour.** Each texture is divided by
// its own mean and multiplied by the material's albedo, so `SurfaceMaterial`
// stays in charge of what colour a stone is. That matters here more than it
// would elsewhere: sarsen and bluestone are different rocks and the app says
// so, and a single photographic albedo would flatten them into one. It also
// keeps the archaeology honest — the texture is standing in for weathering and
// grain, not claiming to be a photograph of stone 56.
constant float3 kRockMean  = float3(0.36, 0.33, 0.30);
constant float3 kGrassMean = float3(0.24, 0.27, 0.14);
// The two ends of the ground's colour range. Everything between a bare soil
// bank and clean turf is a mix of these two, chosen so the banks around the
// stones have somewhere to blend *to* rather than being a separate colour laid
// on top of the grass.
constant float3 kSoilAlbedo = float3(0.26, 0.235, 0.165);
constant float3 kTurfAlbedo = float3(0.28, 0.32, 0.18);
// Worn chalk, for paths and thin ground.
constant float3 kChalkAlbedo = float3(0.66, 0.64, 0.56);

// ── paths and the marks people leave ────────────────────────────────────────
//
// From the air this landscape is not plain grass. The features that read are
// the ones feet and wheels have made, and they read because worn turf shows the
// chalk beneath — which is why they are pale rather than dark, unlike a worn
// path on almost any other soil in Britain.
//
// Three, all still visible:
//
//   **The visitor circuit.** A path rings the stones at about 35 m, walked by
//   more than a million people a year. It is the single most obvious human mark
//   in any aerial photograph of the site.
//
//   **The Avenue.** The Neolithic earthwork running north-east on the solstice
//   axis, about 22 m between its banks. Ploughed nearly flat, but it still
//   shows as a pair of parallel marks in dry summers.
//
//   **Approach desire lines.** Where people cut between the circuit and the
//   paths in from the road, the turf goes first.
//
// Returned as a wear value, 0 to 1, which the mottling then folds into its own
// chalk term — so a path is not painted on, it is the same worn-turf treatment
// as the bare patches, just following a line.
static float pathWear(float2 groundXZ)
{
    float radius = length(groundXZ);

    // The circuit: a soft-edged annulus, wandering a little so it is not a
    // drawn circle. Nobody walks a perfect ring.
    float wander = (fbm(float3(groundXZ.x * 0.06, 21.0, groundXZ.y * 0.06)) - 0.5) * 5.0;
    float circuit = 1.0 - smoothstep(0.0, 4.5, abs(radius - (35.0 + wander)));

    // The Avenue: a corridor on the monument's axis, 49.9° from north, running
    // out to the north-east. World +X is east and +Z is south.
    const float axis = 49.9 * (M_PI_F / 180.0);
    float2 along = float2(sin(axis), -cos(axis));
    float2 across = float2(along.y, -along.x);
    float distanceAlong = dot(groundXZ, along);
    float distanceAcross = abs(dot(groundXZ, across));
    // Only beyond the bank, and fading out as it goes.
    float avenue = smoothstep(50.0, 80.0, distanceAlong)
        * (1.0 - smoothstep(0.0, 11.0, distanceAcross))
        * (1.0 - smoothstep(300.0, 700.0, distanceAlong));

    // Desire lines: a few radial scuffs, strongest near the circuit.
    float spokes = fbm(float3(atan2(groundXZ.y, groundXZ.x) * 2.6, 33.0, radius * 0.012));
    float scuff = smoothstep(0.62, 0.9, spokes)
        * (1.0 - smoothstep(20.0, 60.0, abs(radius - 30.0)));

    return clamp(max(max(circuit, avenue * 0.75), scuff * 0.55), 0.0, 1.0);
}

struct Surface {
    float3 albedo;
    float3 normal;
    float  roughness;
};

static float3 triplanarWeights(float3 n)
{
    // Raised to a power so the blend band stays narrow — a wide blend reads as
    // a smear along the diagonals of every stone.
    float3 w = pow(abs(n), float3(6.0));
    return w / max(w.x + w.y + w.z, 1e-4);
}

static Surface sampleStone(float3 worldPosition, float3 n,
                           constant DrawUniforms &draw,
                           texture2d<float> albedoMap,
                           texture2d<float> normalMap,
                           texture2d<float> roughnessMap,
                           sampler surfaceSampler)
{
    // Per-stone randomisation of the mapping.
    //
    // One photographed rock face tiled across eighty stones repeats, and the
    // eye finds it fast — the same crack in the same place on three uprights is
    // more obviously wrong than no texture at all. Triplanar mapping makes this
    // worse, not better: every stone samples the same world-space grid, so
    // neighbours in a circle land on nearly the same texels.
    //
    // Three cheap breaks, all driven off `weather.w`, the per-stone seed that
    // is already there for the weathering:
    //
    //   **Offset.** Each stone starts somewhere else in the texture.
    //   **Rotation.** Each stone's mapping is turned, so the grain does not run
    //   the same way twice. This is what kills the repeat — offsetting alone
    //   leaves every stone with parallel bedding.
    //   **Scale jitter.** ±12%, so the grain is not all the same size either.
    //
    // The rotation is per-plane as well as per-stone, which costs nothing and
    // stops the three triplanar projections agreeing with each other.
    float seed = draw.weather.w;
    float2 offset = fract(float2(seed * 0.7548776662, seed * 0.5698402909)) * 8.0;
    float jitter = 0.88 + fract(seed * 0.3141592653) * 0.24;
    float scale = jitter / max(draw.surface.y, 0.01);
    float3 w = triplanarWeights(n);

    float turn = fract(seed * 0.6180339887) * 6.2831853;
    float2x2 spinX = float2x2(cos(turn), -sin(turn), sin(turn), cos(turn));
    float turnY = turn + 2.0943951;                      // +120°
    float2x2 spinY = float2x2(cos(turnY), -sin(turnY), sin(turnY), cos(turnY));
    float turnZ = turn + 4.1887902;                      // +240°
    float2x2 spinZ = float2x2(cos(turnZ), -sin(turnZ), sin(turnZ), cos(turnZ));

    float2 uvX = spinX * (worldPosition.zy * scale) + offset;
    float2 uvY = spinY * (worldPosition.xz * scale) + offset.yx;
    float2 uvZ = spinZ * (worldPosition.xy * scale) + offset;

    float3 cx = albedoMap.sample(surfaceSampler, uvX).rgb;
    float3 cy = albedoMap.sample(surfaceSampler, uvY).rgb;
    float3 cz = albedoMap.sample(surfaceSampler, uvZ).rgb;
    float3 colour = cx * w.x + cy * w.y + cz * w.z;

    // And a second sample at an incommensurate scale, multiplied in — the same
    // trick the ground uses. Within a single seven-metre upright the 1.5 m tile
    // repeats four times over, and no amount of per-stone variation hides a
    // repeat that happens inside one stone.
    float2 broad = spinX * (worldPosition.zy * scale * 0.229) + offset;
    float2 broadY = spinY * (worldPosition.xz * scale * 0.229) + offset.yx;
    float2 broadZ = spinZ * (worldPosition.xy * scale * 0.229) + offset;
    float3 bx = albedoMap.sample(surfaceSampler, broad).rgb;
    float3 by = albedoMap.sample(surfaceSampler, broadY).rgb;
    float3 bz = albedoMap.sample(surfaceSampler, broadZ).rgb;
    float3 broadColour = bx * w.x + by * w.y + bz * w.z;
    colour *= mix(float3(1.0), broadColour / kRockMean, 0.45);

    float rx = roughnessMap.sample(surfaceSampler, uvX).r;
    float ry = roughnessMap.sample(surfaceSampler, uvY).r;
    float rz = roughnessMap.sample(surfaceSampler, uvZ).r;

    // Whiteout blend: perturb each planar normal in its own frame, then sum.
    // Doing it this way means no tangent basis has to be carried through the
    // vertex format, which would otherwise have to grow for one effect.
    float3 nx = normalMap.sample(surfaceSampler, uvX).xyz * 2.0 - 1.0;
    float3 ny = normalMap.sample(surfaceSampler, uvY).xyz * 2.0 - 1.0;
    float3 nz = normalMap.sample(surfaceSampler, uvZ).xyz * 2.0 - 1.0;
    float strength = draw.surface.z;
    nx.xy *= strength; ny.xy *= strength; nz.xy *= strength;
    float3 bent = normalize(
          float3(0.0, nx.y, nx.x) * w.x
        + float3(ny.x, 0.0, ny.y) * w.y
        + float3(nz.x, nz.y, 0.0) * w.z
        + n);

    Surface out;
    out.albedo = draw.albedo.rgb * (colour / kRockMean);
    out.normal = bent;
    out.roughness = clamp(draw.albedo.w * (rx * w.x + ry * w.y + rz * w.z) * 2.0,
                          0.15, 1.0);
    return out;
}

static Surface sampleGround(float3 worldPosition, float3 n, float turf,
                            constant FrameUniforms &frame,
                            constant DrawUniforms &draw,
                            texture2d<float> albedoMap,
                            texture2d<float> normalMap,
                            texture2d<float> roughnessMap,
                            sampler surfaceSampler)
{
    float scale = 1.0 / max(draw.surface.y, 0.01);
    float2 uv = worldPosition.xz * scale;

    // A second sample an irrational factor apart, multiplied in. One tile of
    // grass repeating across fifteen kilometres of Salisbury Plain is the most
    // obvious tell in any outdoor scene; two incommensurate frequencies push
    // the visible repeat out past the horizon for the cost of one extra fetch.
    float3 near = albedoMap.sample(surfaceSampler, uv).rgb;
    float3 far  = albedoMap.sample(surfaceSampler, uv * 0.137).rgb;
    float3 colour = near * mix(1.0, far / kGrassMean, 0.55);

    // Erosion, read off the terrain itself.
    //
    // Chalk downland wears where water runs and gathers where it settles: a
    // steep face is thin, pale and stony because the soil creeps off it, while
    // a hollow holds moisture and grows rank and dark. The ground mesh already
    // carries the real Salisbury Plain heightfield, so the surface normal is a
    // measurement of slope — no extra data, no invented terrain features, just
    // reading what the survey already said.
    float groundSlope = clamp(1.0 - n.y, 0.0, 1.0);
    float steepness = smoothstep(0.02, 0.22, groundSlope);

    // Where this fragment sits between bare soil and turf.
    //
    // The vertex blend gives the shape of the transition; the noise breaks its
    // edge up so a bank does not end on a clean contour line. A soil mound that
    // fades smoothly but *evenly* still reads as an applied object — real earth
    // meets grass in a ragged front, with tufts standing in the soil and bare
    // patches out in the turf.
    float ragged = fbm(float3(worldPosition.x * 1.6, 41.0, worldPosition.z * 1.6));
    float soilness = clamp((1.0 - turf) * 1.35 + (ragged - 0.5) * 0.85, 0.0, 1.0);

    // Mottling, at the scale a person actually reads the ground at.
    //
    // Downland is not one green. It is a patchwork a few metres across: thin
    // worn turf where the chalk comes through pale, rank tussocky growth where
    // it does not, molehills, old spoil, the scars of a century of feet. The
    // texture supplies centimetres of grain and the second sample supplies
    // tens of metres of drift, and between the two sat a gap at exactly the
    // scale the eye checks — which is why the ground read as a uniform mat
    // right where you look hardest, around the feet of the stones.
    //
    // Two bands. The broad one moves the tone; the finer one both lightens and
    // desaturates toward chalk, because a worn patch is not simply a brighter
    // green — it is a different substance showing through.
    float broadMottle = fbm(float3(worldPosition.x * 0.22, 3.0, worldPosition.z * 0.22));
    float fineMottle = fbm(float3(worldPosition.x * 0.85, 7.0, worldPosition.z * 0.85));

    colour *= 0.78 + 0.44 * broadMottle;

    // Worn ground: the natural thin patches, plus the paths people have made.
    // Both are the same thing physically — turf gone, chalk showing — so they
    // share a treatment rather than the paths being drawn over the top.
    float natural = smoothstep(0.52, 0.86, fineMottle * 0.65 + broadMottle * 0.35);
    float trodden = pathWear(worldPosition.xz);
    // The path's own edge is broken by the fine mottle, so it has the frayed
    // margin a walked line really has instead of a clean band.
    trodden *= 0.55 + 0.75 * fineMottle;
    // Steep ground is worn ground, and the season's dryness bleaches
    // everything: high summer and autumn let far more chalk through than a wet
    // spring does.
    float wear = clamp(max(max(natural, trodden), steepness * 0.55)
                       + frame.season.w * 0.22, 0.0, 1.0);

    colour = mix(colour, colour * 0.55 + kChalkAlbedo * kGrassMean * 1.15, wear * 0.6);

    float3 t = normalMap.sample(surfaceSampler, uv).xyz * 2.0 - 1.0;
    float strength = draw.surface.z;
    float3 bent = normalize(n + float3(t.x, 0.0, t.y) * strength);

    // Give the mottling *form*, not just colour.
    //
    // The texture's own normal map carries centimetres of grain, which at any
    // distance averages away to nothing — so the ground was a flat plane
    // wearing a patterned coat, and at a low sun it stayed flat while
    // everything around it grew long shadows. Downland is not flat at metre
    // scale: it is tussock and hollow, molehill and old spoil, and that relief
    // is most of what you see when the light comes in sideways.
    //
    // The mottle field already describes where the ground is rough. Taking its
    // gradient by finite difference turns that description into a surface: the
    // same patches that read paler now also tilt, so they catch the light and
    // shade their own lee sides. Two samples, and the ground acquires a shape
    // that answers the sun's direction instead of ignoring it.
    const float step = 0.6;             // metres between samples
    const float relief = 0.55;          // how strongly the field tilts
    float hereMottle = fbm(float3(worldPosition.x * 0.22, 3.0, worldPosition.z * 0.22));
    float eastMottle = fbm(float3((worldPosition.x + step) * 0.22, 3.0,
                                  worldPosition.z * 0.22));
    float southMottle = fbm(float3(worldPosition.x * 0.22, 3.0,
                                   (worldPosition.z + step) * 0.22));
    float3 slope = float3(-(eastMottle - hereMottle), 0.0, -(southMottle - hereMottle));
    bent = normalize(bent + slope * relief);

    Surface out;
    // The material colour is chosen per fragment rather than per draw, so the
    // soil banks and the turf they sit in are two ends of one range instead of
    // two separately-authored greens that never quite meet.
    float3 material = mix(kTurfAlbedo, kSoilAlbedo, soilness);
    // The season tints the vegetation but not the bare earth under it — soil
    // is soil in March and in September, and tinting it too made the whole
    // world change hue like a filter rather than the grass changing colour.
    material *= mix(frame.season.rgb, float3(1.0), soilness);
    out.albedo = material * (colour / kGrassMean);
    out.normal = bent;
    // Floored high. The old floor was 0.2, which is a polished floor, not a
    // hillside — and combined with a dielectric F0 of 0.04 and Fresnel at
    // grazing incidence it put a bright specular rim along every distant slope.
    // Grass is a mass of thin scattering blades: it has a faint sheen when the
    // sun is behind it and is otherwise as matte as a surface gets.
    out.roughness = clamp(draw.albedo.w
                          * roughnessMap.sample(surfaceSampler, uv).r * 2.0,
                          draw.reflectance.y, 1.0);
    return out;
}

// ── wind over the grass ─────────────────────────────────────────────────────
//
// No blade geometry. At eye height on a plain that runs to the horizon, what
// you actually see of wind in grass is not individual blades moving — it is the
// *shading* changing across a field as gusts lay the blades over, the pale
// travelling cat's-paws that cross a meadow ahead of a squall. That is a
// reflectance effect, and it can be modelled where reflectance lives.
//
// The field is noise advected along the wind, which is what makes gusts travel
// rather than pulse in place. Two scales, because real wind has two: broad
// fronts tens of metres across, and a finer ripple riding on them. They move at
// different speeds so they never lock into a repeating pattern.
//
// Bending changes two things, and both are needed or it reads as a stain
// sliding over the ground:
//
//   **The normal tilts toward the wind.** Blades lie over downwind, so the
//   surface they present tips that way.
//
//   **The surface goes paler and smoother.** A standing blade shows its edge; a
//   bent one shows its flat, waxier underside. That is why a gust reads as a
//   silver wave running away from you — it is the undersides catching the sky.
//
// Wind time is *wall-clock*, deliberately, and is not the app's astronomical
// clock. At a day a second the sun must race and the wind must not: a breeze
// that sped up with the time-lapse would be a strobe.
static float windField(float2 groundXZ, constant FrameUniforms &frame)
{
    float2 direction = frame.wind.xz;
    float speed = frame.wind.y;
    float t = frame.wind.w;

    // Spatial and temporal factors are deliberately the same number in each
    // term. `p * k - dir * speed * t * k` advects the pattern at exactly
    // `speed` metres per second; different factors would make the gusts travel
    // at some other speed than the wind, which is the sort of thing that reads
    // as wrong without being nameable.
    //
    // Scales matter more than they look. The first version used 40 m fronts,
    // which is a plausible gust and larger than the patch of ground a standing
    // viewer has in front of them — so the whole near field gated on and off
    // together instead of a wave crossing it, and six seconds of wind produced
    // a byte-identical frame. Fronts are now ~33 m and the ripple ~3 m, so both
    // vary within a few paces.
    const float frontScale = 0.03;      // ~33 m
    const float rippleScale = 0.34;     // ~3 m
    // The surface ripple outruns the mean wind; it is the fastest air, nearest
    // the top of the sward.
    const float rippleSpeed = 1.25;

    float2 broad = groundXZ * frontScale - direction * (speed * t * frontScale);
    float front = fbm(float3(broad.x, 0.0, broad.y));

    float2 fine = groundXZ * rippleScale
        - direction * (speed * rippleSpeed * t * rippleScale);
    float ripple = fbm(float3(fine.x, 11.0, fine.y));

    // Gusts modulate the ripple's strength rather than gating it. A hard gate
    // meant that wherever the front was weak the grass was perfectly still,
    // which is not what a windy day looks like — the sward is always working,
    // and the gusts are where it works hardest.
    float gust = smoothstep(0.22, 0.72, front);
    return clamp((0.28 + 0.72 * gust) * (0.30 + 0.70 * ripple), 0.0, 1.0);
}

static Surface blowGrass(Surface surface, float3 worldPosition,
                         constant FrameUniforms &frame, constant DrawUniforms &draw)
{
    if (draw.reflectance.z < 0.5 || frame.wind.y <= 0.0) { return surface; }

    float bend = windField(worldPosition.xz, frame);

    float3 downwind = float3(frame.wind.x, 0.0, frame.wind.z);

    Surface out;
    // Paler where laid over — the undersides catching the sky.
    out.albedo = surface.albedo * (1.0 + bend * 0.28);
    // Tilting the normal is what carries most of the effect: it changes n·l,
    // so a gust reads differently depending on where the sun is, and crossing
    // grass toward a low sun brightens while crossing away from it darkens.
    // A constant albedo wobble would look the same in every light.
    out.normal = normalize(surface.normal + downwind * bend * 0.45);
    // Smoother, but nowhere near shiny: a waxy leaf back, not a mirror.
    out.roughness = clamp(surface.roughness - bend * 0.12, draw.reflectance.y, 1.0);
    return out;
}

// ── weathering ──────────────────────────────────────────────────────────────
//
// A rock photograph gives grain. It does not give four thousand years standing
// in Wiltshire rain, and that is what actually distinguishes these stones: they
// are not uniformly stone-coloured, they are *mapped* by where water runs and
// where it lingers.
//
// Four effects, each keyed to something physical rather than to taste:
//
//   **A damp foot.** Groundwater wicks up the first half-metre or so. Wet rock
//   is darker and glossier than dry — same rock, lower albedo, lower roughness.
//
//   **Lichen where water lingers.** Crustose lichens take upward-facing ledges
//   and the sheltered side. In Britain that is the north and east faces, which
//   dry slowest; the sun-baked south-west stays comparatively bare. Yellow-green
//   because *Xanthoria* and *Rhizocarpon* are what is actually on them, and
//   matte because lichen is.
//
//   **Rain streaking.** Water running down a vertical face washes it cleaner in
//   channels, leaving pale vertical bands. Stretched hard along Y — that
//   anisotropy is the whole reason a streak reads as a streak and not as a
//   stain.
//
//   **Wind scour on the tops.** Exposed upper surfaces are lighter and rougher,
//   the lichen scrubbed off them.
//
// All procedural: value noise, no textures, nothing to license. Seeded per
// stone from `Stone.seed`, so no two weather alike and the pattern is stable
// across frames — a weathering that shimmered as the camera moved would be
// worse than none.
static Surface weatherStone(Surface surface, float3 worldPosition, float3 n,
                            constant DrawUniforms &draw)
{
    float lichenAmount = draw.weather.y;
    if (lichenAmount <= 0.0) { return surface; }

    float height = max(worldPosition.y - draw.weather.x, 0.0);
    float3 p = worldPosition + draw.weather.w;

    // Damp foot. Softened by noise so the line is not a bathtub ring.
    float damp = 1.0 - smoothstep(0.0, max(draw.weather.z, 0.05), height);
    damp *= 0.55 + 0.45 * fbm(p * 0.8);

    // Shelter: upward-facing, and the north-east half. World +Z is south, so
    // north is -Z and east is +X — the sheltered quarter faces -Z and +X.
    float up = clamp(n.y, 0.0, 1.0);
    float sheltered = clamp(-n.z * 0.5 + n.x * 0.25 + 0.5, 0.0, 1.0);
    // Widened from 0.40–0.72. Four and a half thousand years of it: the
    // sheltered faces of these stones are more lichen than rock, and the
    // earlier range left them looking freshly quarried with a few spots on.
    float patch = smoothstep(0.28, 0.66, fbm(p * 1.7));
    float lichen = lichenAmount * clamp(up * 1.05 + sheltered * 0.85, 0.0, 1.0) * patch;

    // Solution hollows. Rain standing on a horizontal ledge dissolves the
    // silcrete's carbonate cement and leaves pits — the pocked upper surfaces
    // that are the most distinctive thing about a weathered sarsen close to.
    float pits = smoothstep(0.55, 0.85, fbm(p * 4.5)) * clamp(n.y, 0.0, 1.0);

    // Rain wash: vertical channels, so the noise is stretched hard along Y.
    float vertical = 1.0 - up;
    float streak = fbm(float3(p.x * 7.0, p.y * 0.30, p.z * 7.0));
    float wash = vertical * smoothstep(0.52, 0.88, streak) * (1.0 - damp);

    // Wind scour: the exposed top, above the damp and away from the shelter.
    float scour = clamp(up - 0.55, 0.0, 1.0) * 2.2 * smoothstep(0.3, 1.2, height);

    const float3 dampTint   = float3(0.52, 0.53, 0.50);
    const float3 lichenTint = float3(0.74, 0.79, 0.48);
    const float3 washTint   = float3(0.88, 0.87, 0.83);

    float3 albedo = surface.albedo;
    albedo *= mix(1.0, dampTint, damp * 0.80);
    albedo = mix(albedo, albedo * lichenTint * 1.45, clamp(lichen, 0.0, 1.0));
    albedo *= mix(1.0, washTint, wash * 0.40);
    albedo *= 1.0 + scour * 0.14;
    // Pits read as shadow, not as stain: they are holes.
    albedo *= 1.0 - pits * 0.32;

    float roughness = surface.roughness;
    roughness = mix(roughness, 0.96, clamp(lichen, 0.0, 1.0) * 0.85);  // lichen is matte
    roughness = mix(roughness, roughness * 0.70, damp * 0.60);         // wet is glossier
    roughness = mix(roughness, min(roughness * 1.2, 1.0), scour * 0.5);

    // Lichen sits proud of the rock. A small crust in the surface normal is
    // what stops it reading as a decal printed on the stone.
    float3 crust = float3(fbm(p * 9.0) - 0.5, fbm(p * 9.0 + 17.0) - 0.5,
                          fbm(p * 9.0 + 43.0) - 0.5);
    float3 normal = normalize(surface.normal + crust * lichen * 0.35
                              + crust * pits * 0.55);

    Surface out;
    out.albedo = albedo;
    out.normal = normal;
    out.roughness = clamp(roughness, 0.12, 1.0);
    return out;
}

// ── the sky ─────────────────────────────────────────────────────────────────

// Preetham et al., "A Practical Analytic Model for Daylight" (1999).
//
// Chosen over Hosek–Wilkie for M1 because it is closed form: HW needs a
// vendored coefficient table carrying its own licence, and MISSION.md
// invariant 5 says data arrives with provenance settled first. HW drops in
// later without changing anything else here.
static float3 preethamSky(float3 direction, float3 sunDirection, float turbidity)
{
    float cosTheta = max(direction.y, 0.001);
    float cosGamma = clamp(dot(direction, sunDirection), -1.0, 1.0);
    float gamma = acos(cosGamma);
    float sunTheta = acos(clamp(sunDirection.y, -1.0, 1.0));

    // Distribution coefficients as functions of turbidity.
    float t = turbidity;
    float ay = 0.1787 * t - 1.4630, by = -0.3554 * t + 0.4275;
    float cy = -0.0227 * t + 5.3251, dy = 0.1206 * t - 2.5771;
    float ey = -0.0670 * t + 0.3703;

    float ax = -0.0193 * t - 0.2592, bx = -0.0665 * t + 0.0008;
    float cx = -0.0004 * t + 0.2125, dx = -0.0641 * t - 0.8989;
    float ex = -0.0033 * t + 0.0452;

    float az = -0.0167 * t - 0.2608, bz = -0.0950 * t + 0.0092;
    float cz = -0.0079 * t + 0.2102, dz = -0.0441 * t - 1.6537;
    float ez = -0.0109 * t + 0.0529;

    float3 A = float3(ax, ay, az), B = float3(bx, by, bz);
    float3 C = float3(cx, cy, cz), D = float3(dx, dy, dz), E = float3(ex, ey, ez);

    float3 num = (1.0 + A * exp(B / cosTheta))
               * (1.0 + C * exp(D * gamma) + E * cosGamma * cosGamma);
    float3 den = (1.0 + A * exp(B))
               * (1.0 + C * exp(D * sunTheta) + E * cos(sunTheta) * cos(sunTheta));
    float3 xyY = num / max(den, 1e-4);

    // Zenith values, in the Yxy space the model is defined in.
    float theta2 = sunTheta * sunTheta, theta3 = theta2 * sunTheta;
    float chi = (4.0 / 9.0 - t / 120.0) * (M_PI_F - 2.0 * sunTheta);
    float zenithY = max((4.0453 * t - 4.9710) * tan(chi) - 0.2155 * t + 2.4192, 0.0);

    float zenithx =
        (0.00165 * theta3 - 0.00375 * theta2 + 0.00209 * sunTheta) * t * t +
        (-0.02903 * theta3 + 0.06377 * theta2 - 0.03202 * sunTheta + 0.00394) * t +
        (0.11693 * theta3 - 0.21196 * theta2 + 0.06052 * sunTheta + 0.25886);

    float zenithy =
        (0.00275 * theta3 - 0.00610 * theta2 + 0.00317 * sunTheta) * t * t +
        (-0.04214 * theta3 + 0.08970 * theta2 - 0.04153 * sunTheta + 0.00516) * t +
        (0.15346 * theta3 - 0.26756 * theta2 + 0.06670 * sunTheta + 0.26688);

    float Y = zenithY * xyY.y;
    float x = zenithx * xyY.x;
    float y = zenithy * xyY.z;

    // Yxy → XYZ → linear sRGB.
    float3 XYZ = float3(x / max(y, 1e-4) * Y, Y, (1.0 - x - y) / max(y, 1e-4) * Y);
    float3 rgb = float3(
        dot(XYZ, float3( 3.2406, -1.5372, -0.4986)),
        dot(XYZ, float3(-0.9689,  1.8758,  0.0415)),
        dot(XYZ, float3( 0.0557, -0.2040,  1.0570))
    );
    return max(rgb, 0.0) * 0.05;
}

// ACES filmic curve, fitted form. Keeps the sun's core from clipping to a
// flat white disc at dawn.
static float3 acesToneMap(float3 colour)
{
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((colour * (a * colour + b)) / (colour * (c * colour + d) + e), 0.0, 1.0);
}

fragment float4 scene_fragment(SceneInOut in [[stage_in]],
                               constant FrameUniforms &frame [[buffer(0)]],
                               constant DrawUniforms &draw [[buffer(1)]],
                               depth2d_array<float> shadowMap [[texture(0)]],
                               texture2d<float> albedoMap [[texture(1)]],
                               texture2d<float> normalMap [[texture(2)]],
                               texture2d<float> roughnessMap [[texture(3)]],
                               sampler shadowSampler [[sampler(0)]],
                               sampler surfaceSampler [[sampler(1)]])
{
    float3 geometricNormal = normalize(in.worldNormal);

    // The untextured branch has to be a branch, not merely an unbound texture.
    // Sampling a texture that was never bound returns zero, and since the
    // albedo is the material colour *times* the sampled detail, that renders
    // the entire world black — which is how this was found: the geometry tests
    // reported a lit/shade contrast of 0.003 and no shadow edge anywhere.
    Surface surface;
    if (draw.surface.w > 0.5) {
        if (draw.surface.x > 0.5) {
            surface = sampleGround(in.worldPosition, geometricNormal, in.turf, frame, draw,
                                   albedoMap, normalMap, roughnessMap, surfaceSampler);
            surface = blowGrass(surface, in.worldPosition, frame, draw);
        } else {
            surface = sampleStone(in.worldPosition, geometricNormal, draw,
                                  albedoMap, normalMap, roughnessMap, surfaceSampler);
            surface = weatherStone(surface, in.worldPosition, geometricNormal, draw);
        }
    } else {
        surface.albedo = draw.albedo.rgb;
        surface.normal = geometricNormal;
        surface.roughness = draw.albedo.w;
    }

    float3 n = surface.normal;
    float3 v = normalize(frame.cameraPosition.xyz - in.worldPosition);
    float3 l = normalize(frame.sunDirection.xyz);
    float3 h = normalize(v + l);

    float ndotl = max(dot(n, l), 0.0);
    float3 albedo = surface.albedo;
    float roughness = clamp(surface.roughness, 0.05, 1.0);

    // Bias against the *geometric* normal, not the bumped one. Normal mapping
    // swings n by tens of degrees on a rough rock face, and feeding that into
    // the slope-scaled bias would make the bias flicker from texel to texel —
    // acne on some pixels, peter-panning on their neighbours.
    float geometricNdotl = max(dot(geometricNormal, l), 0.0);
    float shadow = geometricNdotl > 0.0
        ? sampleShadow(shadowMap, shadowSampler, in.worldPosition, frame,
                       in.viewDepth, geometricNdotl)
        : 1.0;

    float3 f0 = float3(0.04);
    float3 f = fresnelSchlick(max(dot(h, v), 0.0), f0);
    float ndf = distributionGGX(n, h, roughness);
    float g = geometrySmith(n, v, l, roughness);
    // Specular strength is per material. A dielectric F0 of 0.04 is right for
    // a solid surface, and grass is not one — it is a mass of thin blades with
    // air between them, and most of what would be a specular lobe scatters
    // instead. Left at full strength the plain grew a bright rim along every
    // slope facing the low sun, which is the hour that matters most here.
    float3 specular = (ndf * g * f) / max(4.0 * max(dot(n, v), 0.0) * ndotl, 1e-4);
    specular *= draw.reflectance.x;
    float3 diffuse = (1.0 - f) * albedo / M_PI_F;

    // The shadow map belongs to whichever light was fitted this frame. When
    // the moon is casting, the sun is below the horizon and its term is zero
    // anyway, so handing it an unshadowed 1 costs nothing and keeps the branch
    // out of the inner loop.
    float sunShadow = frame.shadowSource.x > 0.5 ? 1.0 : shadow;
    float moonShadow = frame.shadowSource.x > 0.5 ? shadow : 1.0;

    float3 direct = (diffuse + specular) * frame.sunRadiance.rgb * ndotl * sunShadow;

    // Moonlight. Unshadowed for now — giving the moon its own cascades is M5
    // work — so it is kept dim enough that the missing shadows do not read as
    // a mistake. A gibbous moon on a clear night is about a four-hundred
    // thousandth of the sun, and the eye's own adaptation does the rest.
    float3 l2 = normalize(frame.moonDirection.xyz);
    float moonNdotL = max(dot(n, l2), 0.0);
    direct += albedo / M_PI_F * frame.moonLight.rgb * moonNdotL * moonShadow;

    // Hemispheric ambient: sky from above, bounce from the ground below,
    // mixed by which way the surface looks.
    //
    // A single sun with a weak uniform fill is what makes objects read flat —
    // every face turned away from it collapses to the same near-black and the
    // form disappears. Outdoors most of the light on a shaded face is sky, and
    // a good deal of what strikes its underside has come off the ground. Giving
    // those two different colours and letting the normal choose between them is
    // what makes a solid look solid.
    float3 skyColour = preethamSky(float3(0, 1, 0), l, frame.skyParameters.x);
    float3 horizonColour = preethamSky(normalize(float3(l.x, 0.12, l.z)),
                                       l, frame.skyParameters.x);
    // Chalk grassland: a dim, warm-green bounce carrying the sun's own colour.
    float3 groundBounce = float3(0.26, 0.28, 0.16) * frame.sunRadiance.rgb * 0.045;

    float upwards = n.y * 0.5 + 0.5;
    float3 skyFill = mix(horizonColour, skyColour, upwards);
    // Strength matters as much as direction. Too little and every face turned
    // from the sun collapses to the same black; too much and the fill drowns
    // the sun, which is worse — the stones go flat pale and stop reading as
    // solid at all. The sun must remain the modelling light.
    float3 ambient = albedo * mix(groundBounce, skyFill, upwards) * 0.55;

    // Night. The palette blends full moon to new across the lunar month, and
    // its `w` is a floor — the least light any surface receives — so that the
    // darkest night is dim but never illegible. A physically honest new moon on
    // a screen is a black rectangle, and an app about standing among these
    // stones cannot go blank for several hours a month.
    //
    // Faded in as the sun sets rather than switched: the crossover through
    // twilight is the most-looked-at hour here and a step in it would be the
    // first thing anyone noticed.
    float nightness = 1.0 - smoothstep(-0.10, 0.06, frame.sunDirection.y);
    float3 nightAmbient = frame.night.rgb * (0.35 + 0.65 * upwards);
    ambient += albedo * nightAmbient * nightness;
    ambient += albedo * frame.night.w * nightness;

    // Specular ambient: the sky, reflected.
    //
    // Until now the only specular in the scene came from the sun, which meant
    // that away from the sun's own highlight every surface was purely diffuse —
    // and a wet sarsen with no sheen from the sky above it reads as chalk. The
    // sky model is closed form, so it can simply be evaluated down the
    // reflection vector: the actual colour of the actual sky in the direction
    // the surface is looking. At dawn that puts the sunrise itself faintly on
    // the eastern faces, which is the whole point of the app.
    //
    // Weighted by Fresnel — reflections strengthen at grazing angles, and that
    // is most of why wet things look wet — and folded down by roughness, since
    // a rough surface scatters the reflection into the diffuse term instead.
    float3 reflected = reflect(-v, n);
    float3 skyReflection = preethamSky(normalize(float3(reflected.x,
                                                        max(reflected.y, 0.02),
                                                        reflected.z)),
                                       l, frame.skyParameters.x);
    float grazing = fresnelSchlick(max(dot(n, v), 0.0), f0).r;
    float gloss = (1.0 - roughness) * (1.0 - roughness);
    ambient += skyReflection * grazing * gloss * draw.reflectance.x * 0.85;

    // Cheap wrap term so the terminator is not a hard line — light does creep
    // around a boulder, and a knife edge there is the other thing that reads
    // as cardboard.
    float wrap = clamp((dot(n, l) + 0.35) / 1.35, 0.0, 1.0);
    ambient += albedo * frame.sunRadiance.rgb * wrap * 0.018 * shadow;

    // Aerial perspective — distance haze keeps the barrows on the horizon from
    // reading as cardboard cut-outs.
    float distance = length(frame.cameraPosition.xyz - in.worldPosition);
    float fogAmount = 1.0 - exp(-distance * 0.0016);
    float3 fogColour = preethamSky(normalize(float3(v.x, max(v.y, 0.02), v.z) * -1.0),
                                   l, frame.skyParameters.x);

    float3 colour = mix(direct + ambient, fogColour, clamp(fogAmount, 0.0, 0.85));
    colour = acesToneMap(colour * frame.skyParameters.y);
    return float4(colour, 1.0);
}

// ── sky pass ────────────────────────────────────────────────────────────────

struct SkyInOut {
    float4 clipPosition [[position]];
    float2 ndc;
};

vertex SkyInOut sky_vertex(uint vertexID [[vertex_id]])
{
    // Fullscreen triangle — no vertex buffer, no index buffer.
    float2 positions[3] = { float2(-1, -3), float2(-1, 1), float2(3, 1) };
    SkyInOut out;
    out.ndc = positions[vertexID];
    // Reverse-Z: the far plane is 0, so that is where the sky sits.
    out.clipPosition = float4(positions[vertexID], 0.0, 1.0);
    return out;
}

fragment float4 sky_fragment(SkyInOut in [[stage_in]],
                             constant FrameUniforms &frame [[buffer(0)]])
{
    // Unproject the pixel into a world ray. The renderer supplies the inverse
    // view-projection ready-made rather than inverting a matrix per pixel.
    float4 worldNear = frame.inverseViewProjection * float4(in.ndc, 1.0, 1.0);
    float4 worldFar  = frame.inverseViewProjection * float4(in.ndc, 0.0001, 1.0);
    float3 direction = normalize(worldFar.xyz / worldFar.w - worldNear.xyz / worldNear.w);

    float3 l = normalize(frame.sunDirection.xyz);
    float3 sky = preethamSky(direction, l, frame.skyParameters.x);

    // The sun's disc at its true angular size, with limb darkening. The brief's
    // definition of done is measured in solar diameters, so this is not
    // decoration — it is the ruler.
    float cosAngle = dot(direction, l);
    float angle = acos(clamp(cosAngle, -1.0, 1.0));
    float radius = frame.sunRadiance.w;
    if (angle < radius && l.y > -0.1) {
        float r = angle / radius;
        float mu = sqrt(max(1.0 - r * r, 0.0));
        float limb = 0.3 + 0.7 * pow(mu, 0.55);   // Eddington-like darkening
        sky += frame.sunRadiance.rgb * 12.0 * limb;
    }

    // ── the moon ────────────────────────────────────────────────────────────
    //
    // Lit properly rather than pasted on: the disc is treated as the sphere it
    // is, and each point on it is shaded by the real angle between its own
    // surface normal and the direction to the sun. The terminator then falls
    // out as the curve where that dot product crosses zero — which is why a
    // half moon is straight-edged and a crescent is not, and why the horns
    // always point away from the sun without anyone aiming them.
    float3 m = normalize(frame.moonDirection.xyz);
    float moonRadius = frame.moonDirection.w;
    float moonAngle = acos(clamp(dot(direction, m), -1.0, 1.0));

    if (moonAngle < moonRadius && m.y > -0.15) {
        // A frame on the moon's disc: u toward the sun, v across it.
        float3 u = normalize(l - m * dot(l, m));
        float3 v = cross(m, u);

        // Where on the disc this pixel falls, in units of the moon's radius.
        float3 offset = direction / max(dot(direction, m), 1e-4) - m;
        float2 disc = float2(dot(offset, u), dot(offset, v)) / moonRadius;
        float r2 = clamp(disc.x * disc.x + disc.y * disc.y, 0.0, 1.0);

        // The surface normal of the sphere at that point, facing us.
        float3 normal = disc.x * u + disc.y * v + sqrt(1.0 - r2) * m;
        float lit = max(dot(normal, l), 0.0);

        // Lambert, softened at the limb the way a dusty regolith actually
        // scatters, plus earthshine: the dark side is not black, it is lit by
        // a gibbous Earth hanging in its sky.
        float3 surface = frame.moonLight.rgb * 26.0 * pow(lit, 0.65);
        float3 earthshine = float3(0.055, 0.062, 0.085)
                          * (1.0 - frame.moonLight.w) * 0.6;
        sky += surface + earthshine;
    }

    sky = acesToneMap(sky * frame.skyParameters.y);
    return float4(sky, 1.0);
}

// ── light shafts ────────────────────────────────────────────────────────────
//
// Crepuscular beams through the stones, drawn honestly: the view ray is
// marched through a thin ground haze and the *existing shadow cascades* are
// asked, at each step, whether the sun can see that piece of air. Where a
// trilithon blocks the light the haze goes dark, and the beams are whatever
// is left — nothing here knows where the gaps between the stones are, any
// more than the turf does.
//
// This runs as its own fullscreen pass after the scene, because it needs the
// finished depth buffer: a stone five metres away must end its ray there, or
// it would wear ninety metres of haze like a veil. The pass blends
// `inscatter + transmittance × frame`, and is skipped entirely when
// `haze.x` is zero — which is every hour outside the golden ones, so the
// shadow-agreement oracle (sun at 30°) never sees it.
//
// One tap per step, no PCSS: a beam edge is already integrated over the
// march, which softens it more honestly than filtering each tap would.
static float hazeShadow(float3 p, constant FrameUniforms &frame,
                        depth2d_array<float> shadowMap, sampler shadowSampler)
{
    float viewDepth = -(frame.view * float4(p, 1.0)).z;
    uint cascade = 2;
    if (viewDepth < frame.cascadeSplits.x)      cascade = 0;
    else if (viewDepth < frame.cascadeSplits.y) cascade = 1;

    float4 lightClip = frame.shadowMatrices[cascade] * float4(p, 1.0);
    float3 projected = lightClip.xyz / lightClip.w;
    float2 uv = projected.xy * float2(0.5, -0.5) + 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || projected.z > 1.0) {
        return 1.0;
    }
    float depth = shadowMap.sample(shadowSampler, uv, cascade);
    return (projected.z - 0.0008) <= depth ? 1.0 : 0.0;
}

fragment float4 haze_fragment(SkyInOut in [[stage_in]],
                              constant FrameUniforms &frame [[buffer(0)]],
                              depth2d_array<float> shadowMap [[texture(0)]],
                              depth2d<float> sceneDepth [[texture(1)]],
                              sampler shadowSampler [[sampler(0)]])
{
    // Nearest, never linear: averaging depths across a stone's edge would
    // invent distances that exist on neither side of it.
    constexpr sampler depthSampler(coord::normalized, address::clamp_to_edge,
                                   filter::nearest);

    float4 nearPoint = frame.inverseViewProjection * float4(in.ndc, 1.0, 1.0);
    float4 farPoint  = frame.inverseViewProjection * float4(in.ndc, 0.0001, 1.0);
    float3 origin = nearPoint.xyz / nearPoint.w;
    float3 direction = normalize(farPoint.xyz / farPoint.w - origin);

    // The ray ends at the first surface, or at the march limit for sky
    // pixels — reverse-Z clears to zero, so zero depth *is* the sky.
    float2 uv = float2(in.ndc.x * 0.5 + 0.5, 1.0 - (in.ndc.y * 0.5 + 0.5));
    float depthSample = sceneDepth.sample(depthSampler, uv);
    float maxDistance = frame.haze.y;
    bool hitsSurface = depthSample > 1e-7;
    if (hitsSurface) {
        float4 hit = frame.inverseViewProjection * float4(in.ndc, depthSample, 1.0);
        maxDistance = min(maxDistance, length(hit.xyz / hit.w - origin));
    }

    // Henyey–Greenstein forward lobe. g = 0.65 is a generic aerosol: peaked
    // enough that beams live near the sun's direction, which is where you
    // stand to watch light come through a trilithon.
    float3 l = normalize(frame.sunDirection.xyz);
    float cosTheta = dot(direction, l);
    const float g = 0.65;
    float denom = 1.0 + g * g - 2.0 * g * cosTheta;
    float phase = (1.0 - g * g) / (4.0 * M_PI_F * denom * sqrt(denom));

    const int steps = 24;
    float stepLength = maxDistance / float(steps);
    // Per-pixel start offset hides the banding 24 steps would otherwise
    // show. Deliberately static frame to frame: a time-jittered march would
    // shimmer, and every offscreen test would become time-dependent.
    float jitter = hash13(float3(in.ndc * 617.0, 9.0));

    float3 inscatter = 0.0;
    float transmittance = 1.0;
    for (int i = 0; i < steps; ++i) {
        float3 p = origin + direction * ((float(i) + jitter) * stepLength);
        // Ground mist: densest on the turf, thinning with height. The beams
        // this pass exists for happen in the bottom ten metres of air.
        float density = frame.haze.x * exp(-max(p.y, 0.0) / frame.haze.z);
        float extinction = density * stepLength;
        float sunlit = hazeShadow(p, frame, shadowMap, shadowSampler);
        // The small isotropic term is skylight scattered by the same haze —
        // without it the shadowed air would be ink rather than mist.
        inscatter += transmittance * frame.sunRadiance.rgb
                   * (phase * sunlit + 0.04) * extinction;
        transmittance *= exp(-extinction);
    }

    // Tonemapped to match the frame it lands on. Approximate — the scene was
    // tonemapped without knowing this glow was coming — but the error is a
    // slight softness in the brightest beam, which is the right way round.
    //
    // Surfaces sit behind the marched haze, so they wear its transmittance as
    // a veil. The sky does not: it is not ninety metres away, it *is* the
    // atmosphere continuing past the march, still scattering — extinguishing
    // it here double-counts what the sky model already integrated, and the
    // first calibration run showed exactly that as a sunset dimmed by its own
    // golden hour. The background keeps its light; the beams are pure gain.
    inscatter = acesToneMap(inscatter * frame.skyParameters.y);
    return float4(inscatter, hitsSurface ? transmittance : 1.0);
}

// ── individual blades ───────────────────────────────────────────────────────
//
// The shading model above is right for the middle distance: a hundred metres
// out a blade is a hundredth of a pixel and drawing it is wasted work. But near
// the viewer it reads as a pattern moving over a surface rather than as grass,
// and this app stands you on the turf at eye height. So real blades within a
// short radius, the shading model beyond, and a fade where they meet.
//
// One shared blade mesh, instanced tens of thousands of times. All the variety
// — direction, length, stiffness, colour, phase — rides on the instance.
//
// This block sits at the end of the file because MSL has no forward
// declarations and the fragment shader needs `preethamSky` and `acesToneMap`.
// Buffer indices are 1 and 2, not 30 and 31: Metal's vertex buffer arguments
// stop at 30, and 31 is a compile error rather than a silent misbinding.
struct GrassVertexIn {
    float height;            // 0 at the root, 1 at the tip
    float side;              // -1 or +1 across the width, 0 at the tip
};

struct GrassInstance {
    // `float3`, not `packed_float3`, and the difference was visible from
    // orbit. Swift's `SIMD3<Float>` is 16 bytes aligned to 16, giving this
    // struct a stride of 48; `packed_float3` is 12, giving 40. Every blade
    // after the first then read its fields from eight bytes off — heights and
    // widths came out of neighbouring blades' bit patterns, and the field grew
    // to the height of the trilithons. `GrassLayoutTests` now pins both sides.
    float3 root;
    float yaw;
    float height;
    float width;
    float stiffness;
    float phase;
    float tint;
    float pad;
};

struct GrassInOut {
    float4 clipPosition [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float  viewDepth;
    float  heightAlongBlade;
    float  tint;
    float  fade;
};

vertex GrassInOut grass_vertex(uint vertexID [[vertex_id]],
                               uint instanceID [[instance_id]],
                               constant GrassVertexIn *shape [[buffer(1)]],
                               constant GrassInstance *blades [[buffer(2)]],
                               constant FrameUniforms &frame [[buffer(0)]])
{
    GrassVertexIn v = shape[vertexID];
    GrassInstance blade = blades[instanceID];

    float t = v.height;
    float3 root = float3(blade.root);

    // The blade's own frame: `forward` is the way it leans, `across` is its
    // width. Both from the instance's yaw, so no per-blade matrix is stored.
    float sinYaw = sin(blade.yaw), cosYaw = cos(blade.yaw);
    float3 across  = float3(cosYaw, 0.0, -sinYaw);
    float3 forward = float3(sinYaw, 0.0,  cosYaw);

    // ── how far it is laid over ─────────────────────────────────────────────
    //
    // Two parts, and they are different things. The *gust* is the travelling
    // field the ground shading already uses, so blades and turf agree about
    // where the wind is. The *flutter* is this blade's own oscillation, at its
    // own phase — without it every blade inside a gust bends by exactly the
    // same amount at exactly the same moment, and a field of grass becomes a
    // vibrating carpet.
    float gust = windField(root.xz, frame);
    float speed = frame.wind.y;
    float flutter = sin(frame.wind.w * (1.1 + 0.35 * blade.stiffness) * speed * 0.55
                        + blade.phase);
    float bend = clamp(gust * (0.72 + 0.28 * flutter), 0.0, 1.4) / blade.stiffness;

    // Cantilever: a blade is anchored at the root and free at the tip, so
    // deflection grows faster than linearly along it. t² is the standard cheap
    // stand-in for the beam solution and is indistinguishable at this scale.
    float lean = bend * t * t;

    // Bending shortens a blade's reach as it curls over — a blade laid flat is
    // no taller than it is long. Without this the tips stretch as the wind
    // rises, which reads as growing rather than bending.
    float rise = blade.height * t * cos(lean * 1.35);
    float reach = blade.height * t * sin(lean * 1.35);

    float3 downwind = normalize(float3(frame.wind.x, 0.0, frame.wind.z)
                                + forward * 0.35);
    float3 spine = root + float3(0.0, rise, 0.0) + downwind * reach;

    // Taper: full width at the root, a point at the tip.
    float halfWidth = blade.width * 0.5 * (1.0 - t * 0.85);
    float3 position = spine + across * (v.side * halfWidth);

    // The normal follows the blade's face, tilted with the lean. Bowing it
    // outward across the width is what keeps a flat strip from reading as a
    // strip: it gives each blade a rounded, waxy falloff instead of a facet.
    float3 faceNormal = normalize(forward * cos(lean) + float3(0.0, sin(lean), 0.0));
    float3 normal = normalize(faceNormal + across * v.side * 0.45);

    // Fade the outermost blades into the textured ground rather than ending the
    // field at a visible circle.
    float distanceFromCentre = length(root.xz);
    float fade = 1.0 - smoothstep(frame.grass.x - frame.grass.y, frame.grass.x,
                                  distanceFromCentre);

    GrassInOut out;
    out.clipPosition = frame.viewProjection * float4(position, 1.0);
    out.worldPosition = position;
    out.worldNormal = normal;
    out.viewDepth = length(frame.cameraPosition.xyz - position);
    out.heightAlongBlade = t;
    out.tint = blade.tint;
    out.fade = fade;
    return out;
}

fragment float4 grass_fragment(GrassInOut in [[stage_in]],
                               constant FrameUniforms &frame [[buffer(0)]],
                               depth2d_array<float> shadowMap [[texture(0)]],
                               sampler shadowSampler [[sampler(0)]])
{
    float3 n = normalize(in.worldNormal);
    float3 l = normalize(frame.sunDirection.xyz);
    float3 v = normalize(frame.cameraPosition.xyz - in.worldPosition);

    // Two-sided: a blade seen from behind is still lit. Grass is thin enough
    // that which face you are looking at is close to arbitrary, and shading it
    // one-sided makes half the field black.
    float ndotl = abs(dot(n, l));

    // Darker at the root, where a blade sits in the shade of its neighbours.
    // This is doing the work an ambient-occlusion pass would, for nothing.
    float3 base = float3(0.13, 0.17, 0.07);
    float3 tipColour = float3(0.34, 0.42, 0.17);
    float3 albedo = mix(base, tipColour, in.heightAlongBlade) * in.tint
        * frame.season.rgb;
    // Parched grass loses its green from the tips down, which is why a dry
    // sward reads as straw-coloured with green still in its base.
    const float3 straw = float3(0.42, 0.36, 0.19);
    albedo = mix(albedo, straw * in.tint,
                 frame.season.w * in.heightAlongBlade * 0.75);

    float shadow = sampleShadow(shadowMap, shadowSampler, in.worldPosition,
                                frame, in.viewDepth, max(dot(n, l), 0.05));

    // Translucency. A leaf held up to the sun glows, and in a field lit from
    // behind that is most of what you see — the low-sun hours this app is about
    // are exactly when it matters. Strongest when looking into the light and
    // toward the thin tips.
    float through = pow(clamp(dot(-v, l), 0.0, 1.0), 3.0)
        * in.heightAlongBlade * 0.55;

    float3 direct = albedo / M_PI_F * frame.sunRadiance.rgb
        * (ndotl * shadow + through);

    float3 skyColour = preethamSky(float3(0, 1, 0), l, frame.skyParameters.x);
    // Only the upper part of a blade sees much sky; deeper in the sward it is
    // enclosed. Same reasoning as the root darkening, and the two together are
    // what give a field depth rather than a uniform green.
    float3 ambient = albedo * skyColour * (0.16 + 0.34 * in.heightAlongBlade);
    float nightness = 1.0 - smoothstep(-0.10, 0.06, frame.sunDirection.y);
    ambient += albedo * (frame.night.rgb + frame.night.w) * nightness;

    float distance = length(frame.cameraPosition.xyz - in.worldPosition);
    float fogAmount = 1.0 - exp(-distance * 0.0016);
    float3 fogColour = preethamSky(normalize(float3(v.x, max(v.y, 0.02), v.z) * -1.0),
                                   l, frame.skyParameters.x);

    float3 colour = mix(direct + ambient, fogColour, clamp(fogAmount, 0.0, 0.85));
    colour = acesToneMap(colour * frame.skyParameters.y);
    return float4(colour, in.fade);
}
