import Foundation
import Metal
import MetalKit

/// The three maps that make a surface: colour, normal, roughness.
///
/// Loaded from the bundle's CC0 material set — see `SECURITY.md` for the
/// provenance. Every field is non-optional here, but the *loading* is
/// failable and the renderer treats a missing set as "draw it flat". That is
/// deliberate: this app's claim is about where the sun is, and it should still
/// make that claim on a machine where a texture failed to decode.
/// Not `Sendable`: `MTLTexture` is not, and pretending otherwise would be a
/// lie the Swift 6 checker is right to reject. These live on the renderer,
/// which is `@MainActor`, and never cross an isolation boundary.
public struct SurfaceTextures {

    public let albedo: MTLTexture
    public let normal: MTLTexture
    public let roughness: MTLTexture

    /// Which slot in the renderer's array this occupies. Stones sample the
    /// first, the ground the second.
    public enum Kind: Int, CaseIterable, Sendable {
        case rock = 0
        case grass = 1

        var prefix: String {
            switch self {
            case .rock: "rock"
            case .grass: "grass"
            }
        }

        /// Metres covered by one tile.
        ///
        /// Set from the thing being photographed rather than from taste: the
        /// ambientCG rock scan covers about a metre and a half of face, and the
        /// grass about two-thirds of a metre. Getting this wrong is the
        /// difference between weathered sarsen and gravel.
        public var metresPerTile: Float {
            switch self {
            case .rock: 1.5
            case .grass: 0.65
            }
        }

        public var normalStrength: Float {
            switch self {
            // Sarsen is genuinely lumpy; the mesh already carries the large
            // shapes, so the map only has to supply grain and pitting.
            case .rock: 0.8
            // Turf is close to flat at this scale. Pushed further it reads as
            // corrugated iron under a low sun, which is exactly the hour that
            // matters most here.
            case .grass: 0.45
            }
        }
    }

    /// Load one material set. Returns nil rather than throwing — see above.
    @MainActor
    public static func load(_ kind: Kind, device: MTLDevice) -> SurfaceTextures? {
        let loader = MTKTextureLoader(device: device)

        func texture(_ suffix: String, sRGB: Bool) -> MTLTexture? {
            guard let url = Bundle.module.url(forResource: "\(kind.prefix)-\(suffix)",
                                              withExtension: "jpg") else { return nil }
            return try? loader.newTexture(URL: url, options: [
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .generateMipmaps: NSNumber(value: true),
                // Colour is authored in sRGB; normals and roughness are data
                // and must not be gamma-decoded. Getting this backwards is the
                // classic way to end up with washed-out albedo and normals that
                // bend the wrong amount.
                .SRGB: NSNumber(value: sRGB)
            ])
        }

        guard let albedo = texture("albedo", sRGB: true),
              let normal = texture("normal", sRGB: false),
              let roughness = texture("roughness", sRGB: false) else { return nil }

        return SurfaceTextures(albedo: albedo, normal: normal, roughness: roughness)
    }
}
