import CoreGraphics
import Foundation

/// Tunable physics & world constants.
///
/// **Plan reference:** Section 4 (Arena Dimensions & Camera) and Section 23 (mockup fixes).
/// These live in one file so playtesting tweaks are a one-line change.
enum WorldConstants {

    // MARK: - Arena

    /// World is N × N viewport-screens. Section 4 DECISION POINT — try 16, drop to 12 or 8 if matches feel like chase scenes.
    static let worldScaleFactor: CGFloat = 16

    /// Camera lerp factor per frame (Section 4: "smoothly follows the player's ship, lerp factor ~0.08").
    /// Multiplied by `dt × 60` so framerate independent.
    static let cameraLerp: CGFloat = 0.08

    /// Ships lose this fraction of their velocity component when bouncing off the world boundary.
    /// Section 4: "Ships bounce softly off the outer walls with ~45% velocity loss" → keep 0.55.
    static let wallBounceRetention: CGFloat = 0.55

    /// Enemy-ship spawn distance from player, expressed in viewport widths.
    /// Section 4 specifies ~3 viewport-widths for v1.0. With an AI opponent in Phase 2 this is fine —
    /// the AI closes distance aggressively and the off-screen indicator points the way.
    static let enemySpawnViewports: CGFloat = 3.0

    // MARK: - Physics conversion
    //
    // Ship stats in `Ships.json` are expressed in classic Star Control units/frame at 60 FPS.
    // We render in points/second to stay framerate-independent in SpriteKit.

    /// Multiplier converting "units per frame at 60 FPS" → points per second.
    static let speedFrameToSecond: CGFloat = 60

    /// Multiplier converting "units per frame²" → points per second² (acceleration).
    static let accelFrameToSecond: CGFloat = 3600

    /// Multiplier converting "radians per frame" → radians per second.
    static let turnFrameToSecond: CGFloat = 60

    // MARK: - Input

    /// Joystick deadzone (Section 9: 0.18).
    static let stickDeadzone: CGFloat = 0.18

    /// Brake strength applied while holding the Y button — fraction of velocity removed per second.
    static let brakeStrengthPerSecond: CGFloat = 1.6

    // MARK: - Damage

    /// Section 6 damage formula: shield strength multiplier (1.0 = full shield absorbs `shieldModifier × 100`%).
    /// Tuned so a fresh shield blocks ~70% of incoming damage.
    static let shieldDamageModifier: CGFloat = 0.7

    /// Section 6 — per-ship offensive modifier baseline. Phase 2 will move this onto the ship definition.
    static let baselineOffensiveModifier: CGFloat = 1.0
}

/// SpriteKit physics categories. Pairs that should collide are set via contactTestBitMask.
enum PhysicsCategory {
    static let none:        UInt32 = 0
    static let playerShip:  UInt32 = 1 << 0
    static let enemyShip:   UInt32 = 1 << 1
    static let playerShot:  UInt32 = 1 << 2
    static let enemyShot:   UInt32 = 1 << 3
    static let planet:      UInt32 = 1 << 4
    static let powerUp:     UInt32 = 1 << 5
    static let worldBound:  UInt32 = 1 << 6
}
