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
};

struct DrawUniforms {
    float4x4 model;
    float4x4 normalMatrix;
    float4   albedo;         // rgb albedo, w = roughness
    float4   surface;        // x: 0 stone / 1 ground, y: metres per texture tile,
                             // z: normal strength, w: 1 textured / 0 flat
    float4   weather;        // x: world Y of the stone's foot, y: lichen amount,
                             // z: damp rise in metres, w: per-stone seed
};

struct Vertex {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct SceneInOut {
    float4 clipPosition [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float  viewDepth;
};

// ── depth-only pass, for the shadow cascades ────────────────────────────────

vertex float4 shadow_vertex(Vertex in [[stage_in]],
                            constant DrawUniforms &draw [[buffer(1)]],
                            constant float4x4 &lightViewProjection [[buffer(2)]])
{
    float4 world = draw.model * float4(in.position, 1.0);
    return lightViewProjection * world;
}

// ── main scene pass ─────────────────────────────────────────────────────────

vertex SceneInOut scene_vertex(Vertex in [[stage_in]],
                               constant FrameUniforms &frame [[buffer(0)]],
                               constant DrawUniforms &draw [[buffer(1)]])
{
    SceneInOut out;
    float4 world = draw.model * float4(in.position, 1.0);
    out.worldPosition = world.xyz;
    out.worldNormal = normalize((draw.normalMatrix * float4(in.normal, 0.0)).xyz);
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
    float scale = 1.0 / max(draw.surface.y, 0.01);
    float3 w = triplanarWeights(n);

    float2 uvX = worldPosition.zy * scale;
    float2 uvY = worldPosition.xz * scale;
    float2 uvZ = worldPosition.xy * scale;

    float3 cx = albedoMap.sample(surfaceSampler, uvX).rgb;
    float3 cy = albedoMap.sample(surfaceSampler, uvY).rgb;
    float3 cz = albedoMap.sample(surfaceSampler, uvZ).rgb;
    float3 colour = cx * w.x + cy * w.y + cz * w.z;

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

static Surface sampleGround(float3 worldPosition, float3 n,
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

    float3 t = normalMap.sample(surfaceSampler, uv).xyz * 2.0 - 1.0;
    float strength = draw.surface.z;
    float3 bent = normalize(n + float3(t.x, 0.0, t.y) * strength);

    Surface out;
    out.albedo = draw.albedo.rgb * (colour / kGrassMean);
    out.normal = bent;
    out.roughness = clamp(draw.albedo.w
                          * roughnessMap.sample(surfaceSampler, uv).r * 2.0, 0.2, 1.0);
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
    float patch = smoothstep(0.40, 0.72, fbm(p * 1.7));
    float lichen = lichenAmount * clamp(up * 0.9 + sheltered * 0.7, 0.0, 1.0) * patch;

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

    float roughness = surface.roughness;
    roughness = mix(roughness, 0.96, clamp(lichen, 0.0, 1.0) * 0.85);  // lichen is matte
    roughness = mix(roughness, roughness * 0.70, damp * 0.60);         // wet is glossier
    roughness = mix(roughness, min(roughness * 1.2, 1.0), scour * 0.5);

    // Lichen sits proud of the rock. A small crust in the surface normal is
    // what stops it reading as a decal printed on the stone.
    float3 crust = float3(fbm(p * 9.0) - 0.5, fbm(p * 9.0 + 17.0) - 0.5,
                          fbm(p * 9.0 + 43.0) - 0.5);
    float3 normal = normalize(surface.normal + crust * lichen * 0.35);

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
            surface = sampleGround(in.worldPosition, geometricNormal, draw,
                                   albedoMap, normalMap, roughnessMap, surfaceSampler);
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
    float3 specular = (ndf * g * f) / max(4.0 * max(dot(n, v), 0.0) * ndotl, 1e-4);
    float3 diffuse = (1.0 - f) * albedo / M_PI_F;

    float3 direct = (diffuse + specular) * frame.sunRadiance.rgb * ndotl * shadow;

    // Moonlight. Unshadowed for now — giving the moon its own cascades is M5
    // work — so it is kept dim enough that the missing shadows do not read as
    // a mistake. A gibbous moon on a clear night is about a four-hundred
    // thousandth of the sun, and the eye's own adaptation does the rest.
    float3 l2 = normalize(frame.moonDirection.xyz);
    float moonNdotL = max(dot(n, l2), 0.0);
    direct += albedo / M_PI_F * frame.moonLight.rgb * moonNdotL;

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
