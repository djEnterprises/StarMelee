import SpriteKit
import CoreGraphics

/// A Quantum Torpedo planted on a target ship after a successful Transporter Beam.
///
/// **Plan reference:** Section 6 — "TRANSPORTER BEAM + QUANTUM TORPEDO" mechanic.
///
/// 10-second countdown visible to both ships (the node is added as a child of the host so
/// it tracks position automatically). On detonation: catastrophic damage to host + spawn of
/// the Quantum Singularity Event in the arena.
final class QuantumTorpedo: SKNode {

    /// The ship currently hosting the torpedo. Set by `transport(to:)` so it can change owners
    /// when defended back to the original attacker.
    weak var host: Ship?

    /// The side that originally fired the torpedo — used to credit the FATALITY on kill.
    var originalFirer: Ship.Side

    private(set) var secondsRemaining: TimeInterval = 10
    static let detonationSeconds: TimeInterval = 10

    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let pulseRing: SKShapeNode

    init(originalFirer: Ship.Side) {
        self.originalFirer = originalFirer
        self.pulseRing = SKShapeNode(circleOfRadius: 26)
        super.init()

        // Pulsing magenta ring
        pulseRing.fillColor = .clear
        pulseRing.strokeColor = SKColor(red: 1.0, green: 0.0, blue: 0.85, alpha: 1)
        pulseRing.lineWidth = 2
        pulseRing.glowWidth = 8
        addChild(pulseRing)

        // Central icon
        let core = SKShapeNode(circleOfRadius: 10)
        core.fillColor = SKColor(red: 1.0, green: 0.0, blue: 0.85, alpha: 0.6)
        core.strokeColor = .white
        core.lineWidth = 1
        core.glowWidth = 4
        addChild(core)

        // Countdown label
        timerLabel.text = "10"
        timerLabel.fontSize = 22
        timerLabel.fontColor = .white
        timerLabel.verticalAlignmentMode = .center
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.position = CGPoint(x: 0, y: -38)
        addChild(timerLabel)

        // Position above the host ship
        position = CGPoint(x: 0, y: 44)
        zPosition = 80

        // Pulse animation
        let p1 = SKAction.scale(to: 1.18, duration: 0.45)
        let p2 = SKAction.scale(to: 1.00, duration: 0.45)
        pulseRing.run(SKAction.repeatForever(.sequence([p1, p2])))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    /// Tick the timer down. Returns true while still counting; false when it's time to detonate.
    func tick(dt: TimeInterval) -> Bool {
        secondsRemaining -= dt
        timerLabel.text = "\(max(0, Int(ceil(secondsRemaining))))"
        // Color shift as we approach detonation
        if secondsRemaining < 3 {
            timerLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)
        }
        return secondsRemaining > 0
    }

    /// Move the torpedo to a new host (defense option 2 — transport it back to the attacker).
    func transport(to newHost: Ship) {
        removeFromParent()
        host = newHost
        newHost.addChild(self)
        position = CGPoint(x: 0, y: 44)
    }
}
