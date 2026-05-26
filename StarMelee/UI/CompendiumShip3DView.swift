import SwiftUI
import SceneKit
import UIKit

/// 3D ship viewer for the Compendium (Section 11).
///
/// Extrudes the polygon silhouette from `ShipHullDesigner` into a low-poly 3D mesh using
/// `SCNShape`. Idle auto-rotation showcases the model; user can drag to orbit and pinch to zoom
/// via `SCNView.allowsCameraControl`.
///
/// Mac Catalyst note: `UIViewRepresentable` works on Catalyst — `SCNView` is a UIView there.
struct CompendiumShip3DView: UIViewRepresentable {
    let shipID: String
    let isAlliance: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = buildScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Rebuild scene if shipID changed (when reused in a list).
        if context.coordinator.lastShipID != shipID {
            uiView.scene = buildScene()
            context.coordinator.lastShipID = shipID
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(shipID: shipID) }

    final class Coordinator {
        var lastShipID: String
        init(shipID: String) { self.lastShipID = shipID }
    }

    // MARK: - Scene builder

    private func buildScene() -> SCNScene {
        let scene = SCNScene()

        let hullNode = buildHullNode()
        scene.rootNode.addChildNode(hullNode)

        // Subtle idle rotation around the y axis so the ship reveals depth even without user input.
        let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 9)
        hullNode.runAction(SCNAction.repeatForever(spin))

        // Lighting — key, fill, and an emissive ambient so the silhouette glows like the in-game hull.
        let key = SCNLight()
        key.type = .omni
        key.intensity = 800
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(2, 3, 4)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 350
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-3, -2, 2)
        scene.rootNode.addChildNode(fillNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 240
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 35
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.5)
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    private func buildHullNode() -> SCNNode {
        // Convert normalized polygon points to a closed UIBezierPath.
        let points = ShipHullDesigner.normalizedPoints(for: shipID)
        let scale: CGFloat = 1.0   // SceneKit units
        let path = UIBezierPath()
        guard let first = points.first else { return SCNNode() }
        path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
        for p in points.dropFirst() {
            path.addLine(to: CGPoint(x: p.x * scale, y: p.y * scale))
        }
        path.close()
        path.flatness = 0.02

        // Extrude into z.
        let shape = SCNShape(path: path, extrusionDepth: 0.35)
        shape.chamferRadius = 0.04

        // Materials — faction-themed.
        let factionColorVec: (CGFloat, CGFloat, CGFloat) = isAlliance
            ? (0.0, 1.0, 0.84)      // alliance cyan
            : (1.0, 0.20, 0.40)     // dominion red

        let bodyMaterial = SCNMaterial()
        bodyMaterial.lightingModel = .blinn
        bodyMaterial.diffuse.contents = UIColor(red: factionColorVec.0,
                                                green: factionColorVec.1,
                                                blue: factionColorVec.2,
                                                alpha: 0.35)
        bodyMaterial.specular.contents = UIColor.white
        bodyMaterial.emission.contents = UIColor(red: factionColorVec.0,
                                                 green: factionColorVec.1,
                                                 blue: factionColorVec.2,
                                                 alpha: 0.50)
        bodyMaterial.isDoubleSided = true
        bodyMaterial.transparency = 0.85

        let edgeMaterial = SCNMaterial()
        edgeMaterial.lightingModel = .constant
        edgeMaterial.diffuse.contents = UIColor(red: factionColorVec.0,
                                                green: factionColorVec.1,
                                                blue: factionColorVec.2,
                                                alpha: 1.0)
        edgeMaterial.emission.contents = UIColor(red: factionColorVec.0,
                                                 green: factionColorVec.1,
                                                 blue: factionColorVec.2,
                                                 alpha: 1.0)

        // SCNShape exposes three material slots: 0 = front face, 1 = back face, 2 = side/edge.
        shape.materials = [bodyMaterial, bodyMaterial, edgeMaterial]

        let node = SCNNode(geometry: shape)
        // Recenter — extrusion creates depth along +z, shift back by half so it pivots around origin.
        node.position = SCNVector3(0, 0, -0.175)
        // Slight initial tilt so the player sees depth immediately on first frame.
        node.eulerAngles = SCNVector3(Float.pi / 12, Float.pi / 5, 0)
        return node
    }
}

#Preview {
    CompendiumShip3DView(shipID: "crimson_tyrant", isAlliance: false)
        .frame(height: 240)
        .background(Color.black)
}
