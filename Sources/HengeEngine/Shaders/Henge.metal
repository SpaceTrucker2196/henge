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
};

struct DrawUniforms {
    float4x4 model;
    float4x4 normalMatrix;
    float4   albedo;         // rgb albedo, w = roughness
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

// Percentage-closer filtering over a 3×3 tap. M2 replaces this with PCSS whose
// penumbra widens to match the sun's real 0.53° — the widening is deliberate,
// and the shadow-agreement test is calibrated against this hard edge first.
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
    float sum = 0.0;
    for (int dx = -1; dx <= 1; ++dx) {
        for (int dy = -1; dy <= 1; ++dy) {
            float2 offset = float2(dx, dy) * texel;
            float depth = shadowMap.sample(shadowSampler, uv + offset, cascade);
            sum += (projected.z - bias) <= depth ? 1.0 : 0.0;
        }
    }
    return sum / 9.0;
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
                               sampler shadowSampler [[sampler(0)]])
{
    float3 n = normalize(in.worldNormal);
    float3 v = normalize(frame.cameraPosition.xyz - in.worldPosition);
    float3 l = normalize(frame.sunDirection.xyz);
    float3 h = normalize(v + l);

    float ndotl = max(dot(n, l), 0.0);
    float3 albedo = draw.albedo.rgb;
    float roughness = clamp(draw.albedo.w, 0.05, 1.0);

    float shadow = ndotl > 0.0
        ? sampleShadow(shadowMap, shadowSampler, in.worldPosition, frame, in.viewDepth, ndotl)
        : 1.0;

    float3 f0 = float3(0.04);
    float3 f = fresnelSchlick(max(dot(h, v), 0.0), f0);
    float ndf = distributionGGX(n, h, roughness);
    float g = geometrySmith(n, v, l, roughness);
    float3 specular = (ndf * g * f) / max(4.0 * max(dot(n, v), 0.0) * ndotl, 1e-4);
    float3 diffuse = (1.0 - f) * albedo / M_PI_F;

    float3 direct = (diffuse + specular) * frame.sunRadiance.rgb * ndotl * shadow;

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
    out.clipPosition = float4(positions[vertexID], 1.0, 1.0);
    return out;
}

fragment float4 sky_fragment(SkyInOut in [[stage_in]],
                             constant FrameUniforms &frame [[buffer(0)]])
{
    // Unproject the pixel into a world ray. The renderer supplies the inverse
    // view-projection ready-made rather than inverting a matrix per pixel.
    float4 worldNear = frame.inverseViewProjection * float4(in.ndc, 0.0, 1.0);
    float4 worldFar  = frame.inverseViewProjection * float4(in.ndc, 1.0, 1.0);
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

    sky = acesToneMap(sky * frame.skyParameters.y);
    return float4(sky, 1.0);
}
