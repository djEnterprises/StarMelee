import SpriteKit
import CoreGraphics

/// Code-only particle VFX for the vector-neon art direction (premium-polish Phase 2).
///
/// Every emitter uses **additive blending** so particles read as glowing light on the dark navy
/// background — turning the game's all-vector look into a deliberate neon style (no sprite art or
/// `.sks` files needed; the soft-dot texture is generated procedurally once).
///
/// All spawns are gated by a `motionScale` (0 = Reduce Motion fully off) supplied by the caller,
/// which sources it from `JuiceSystem.motionScale`, so accessibility settings are honored without
/// each call hitting `UserDefaults`.
enum VFX {

    // MARK: - Palette

    /// The two faction neon colors, shared with Ship / Projectile literals.
    static func neonColor(for side: Ship.Side) -> SKColor {
        side == .player
            ? SKColor(red: 0,   green: 1.0, blue: 0.84, alpha: 1.0)   // teal
            : SKColor(red: 1.0, green: 0.2, blue: 0.4,  alpha: 1.0)   // red
    }

    // MARK: - Glow halo (localized "bloom")
    //
    // A true post-process CIBloom would require wrapping the world in an SKEffectNode — but this
    // game's world is ~screen×16 (≈13k px), so rasterizing it each frame is a non-starter. Instead
    // we fake bloom the way shipped neon games do: an additive-blended soft-dot sprite placed
    // *behind* a bright object, so its edges blow out into a glow. Cheap, scales to any world size,
    // and no per-frame cost. Parent it behind the object's core (negative zPosition).
    static func makeGlow(color: SKColor, radius: CGFloat, alpha: CGFloat = 0.55) -> SKSpriteNode {
        let glow = SKSpriteNode(texture: softDot)
        glow.size = CGSize(width: radius * 2, height: radius * 2)
        glow.color = color
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = alpha
        return glow
    }

    // MARK: - Procedural soft-dot texture (built once)

    /// A radial-gradient "soft dot" — bright center fading to transparent. Used for every
    /// emitter so additive blending produces a glow rather than a hard square.
    static let softDot: SKTexture = {
        let dim = 32
        let size = CGSize(width: dim, height: dim)
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: dim, height: dim, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let colors = [SKColor.white.cgColor,
                      SKColor.white.withAlphaComponent(0).cgColor] as CFArray
        let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
        let c = CGPoint(x: dim / 2, y: dim / 2)
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                               endCenter: c, endRadius: CGFloat(dim) / 2,
                               options: [])
        let tex = SKTexture(cgImage: ctx.makeImage()!)
        tex.filteringMode = .linear
        return tex
    }()

    // MARK: - Burst spawning

    /// Add a one-shot emitter to `world`, then auto-remove once its particles have died.
    private static func spawnBurst(_ emitter: SKEmitterNode, at position: CGPoint,
                                   zPosition: CGFloat, in world: SKNode) {
        emitter.position = position
        emitter.zPosition = zPosition
        world.addChild(emitter)
        let life = Double(emitter.particleLifetime + emitter.particleLifetimeRange)
        emitter.run(.sequence([.wait(forDuration: life + 0.15), .removeFromParent()]))
    }

    private static func baseEmitter(color: SKColor) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softDot
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add          // glow
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -1.6
        return e
    }

    // MARK: - Muzzle flash (on weapon fire)

    static func spawnMuzzleFlash(at position: CGPoint, heading: CGFloat, color: SKColor,
                                 scale: CGFloat, in world: SKNode) {
        guard scale > 0 else { return }
        let e = baseEmitter(color: color)
        e.numParticlesToEmit = Int(10 * scale)
        e.particleBirthRate = 1200
        e.particleLifetime = 0.16
        e.particleLifetimeRange = 0.08
        e.emissionAngle = heading
        e.emissionAngleRange = 0.5
        e.particleSpeed = 220
        e.particleSpeedRange = 90
        e.particleScale = 0.28
        e.particleScaleRange = 0.12
        e.particleScaleSpeed = -0.6
        spawnBurst(e, at: position, zPosition: 45, in: world)
    }

    // MARK: - Impact sparks (on projectile hit)

    static func spawnImpactSparks(at position: CGPoint, color: SKColor,
                                  scale: CGFloat, in world: SKNode) {
        guard scale > 0 else { return }
        let e = baseEmitter(color: color)
        e.numParticlesToEmit = Int(14 * scale)
        e.particleBirthRate = 2000
        e.particleLifetime = 0.30
        e.particleLifetimeRange = 0.15
        e.emissionAngle = 0
        e.emissionAngleRange = .pi * 2       // radial
        e.particleSpeed = 160
        e.particleSpeedRange = 110
        e.particleScale = 0.22
        e.particleScaleRange = 0.10
        e.particleScaleSpeed = -0.5
        spawnBurst(e, at: position, zPosition: 56, in: world)
    }

    // MARK: - Explosion debris + sparks (on ship destruction)

    static func spawnExplosion(at position: CGPoint, color: SKColor,
                               scale: CGFloat, in world: SKNode) {
        guard scale > 0 else { return }

        // Fast white spark shower.
        let sparks = baseEmitter(color: .white)
        sparks.numParticlesToEmit = Int(40 * scale)
        sparks.particleBirthRate = 4000
        sparks.particleLifetime = 0.45
        sparks.particleLifetimeRange = 0.25
        sparks.emissionAngleRange = .pi * 2
        sparks.particleSpeed = 320
        sparks.particleSpeedRange = 180
        sparks.particleScale = 0.30
        sparks.particleScaleRange = 0.15
        sparks.particleScaleSpeed = -0.5
        spawnBurst(sparks, at: position, zPosition: 58, in: world)

        // Slower, color-tinted glowing debris that drifts and fades.
        let debris = baseEmitter(color: color)
        debris.numParticlesToEmit = Int(24 * scale)
        debris.particleBirthRate = 2200
        debris.particleLifetime = 0.9
        debris.particleLifetimeRange = 0.5
        debris.emissionAngleRange = .pi * 2
        debris.particleSpeed = 120
        debris.particleSpeedRange = 90
        debris.particleScale = 0.45
        debris.particleScaleRange = 0.2
        debris.particleScaleSpeed = -0.35
        debris.particleAlphaSpeed = -0.9
        spawnBurst(debris, at: position, zPosition: 57, in: world)
    }

    // MARK: - Projectile trail (attached, world-space)

    /// A continuous trail to attach as a child of a projectile. `targetNode` must be set to the
    /// world after the projectile is added, so emitted particles stay in world space and trail
    /// behind the shot rather than riding along with it. `intensity` keeps rapid primary-fire
    /// trails light while letting heavier shots stream more.
    static func makeProjectileTrail(color: SKColor, intensity: CGFloat) -> SKEmitterNode {
        let e = baseEmitter(color: color)
        e.particleBirthRate = 90 * intensity
        e.particleLifetime = 0.28
        e.particleLifetimeRange = 0.10
        e.emissionAngleRange = 0.3
        e.particleSpeed = 12
        e.particleSpeedRange = 8
        e.particleScale = 0.18 * intensity
        e.particleScaleRange = 0.06
        e.particleScaleSpeed = -0.5
        e.particleAlpha = 0.7
        e.particleAlphaSpeed = -2.4
        e.zPosition = -1                     // behind the projectile's bright core
        return e
    }
}
