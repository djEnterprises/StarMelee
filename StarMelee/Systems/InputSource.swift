import Foundation
import CoreGraphics
#if canImport(GameController)
import GameController
#endif

/// Clean abstraction over the different input sources Star Melee supports.
///
/// **Plan reference:** SuperGrok Section 16.6 — Game Controller support is required for v1.0.
///
/// Today's wiring:
///   - `TouchInputSource` and `KeyboardInputSource` already write to `InputState` directly
///     via the SwiftUI views — they don't need an explicit conformance here.
///   - `GamepadInputSource` is the new addition. It listens for `GCController` connect
///     events and mirrors the gamepad's left thumbstick + button presses into the same
///     `InputState` that the touch + keyboard layers write to.
///
/// Ship + weapon code stays input-agnostic because everything funnels into `InputState`.
@MainActor
protocol InputSource: AnyObject {
    var isActive: Bool { get }
}

@MainActor
final class GamepadInputSource: InputSource {
    private(set) var isActive: Bool = false
    private weak var inputState: InputState?

    init(inputState: InputState) {
        self.inputState = inputState
        #if canImport(GameController)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidConnect),
                                               name: .GCControllerDidConnect,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(controllerDidDisconnect),
                                               name: .GCControllerDidDisconnect,
                                               object: nil)
        // Pick up controllers already paired at app launch.
        if let connected = GCController.controllers().first {
            attach(to: connected)
        }
        #endif
    }

    deinit {
        #if canImport(GameController)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    #if canImport(GameController)

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        attach(to: controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        isActive = false
        inputState?.stickX = 0
        inputState?.stickY = 0
        inputState?.aPressed = false
        inputState?.bPressed = false
        inputState?.cPressed = false
        inputState?.xPressed = false
        inputState?.yPressed = false
        inputState?.zPressed = false
    }

    private func attach(to controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        isActive = true

        // Section 16.6 button map:
        //   Left stick → stickX/stickY
        //   Cross (X on PS5) / A (Xbox) → A (primary fire)
        //   Square / X → B (secondary fire)
        //   Triangle / Y → C (special weapon)
        //   R2 → Z (speed boost)
        //   L2 → Y (brake)
        //   ButtonA on extendedGamepad maps to Cross / A
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            Task { @MainActor in
                self?.inputState?.stickX = CGFloat(xValue)
                self?.inputState?.stickY = CGFloat(yValue)
            }
        }
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.inputState?.aPressed = pressed }
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.inputState?.bPressed = pressed }
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.inputState?.cPressed = pressed }
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.inputState?.zPressed = pressed }
        }
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.inputState?.yPressed = pressed }
        }
        // X (thrust) on the touch cluster is held; with a controller you usually thrust via
        // pushing the stick forward, so map up-on-left-stick to xPressed automatically.
        // Plan-pure mapping prefers an explicit thrust trigger — Phase 4 polish can refine this.
    }

    #endif
}
