//
//  ViewController.swift
//  BodyTracking
//
//  Created by Zewu Chen on 14/02/20.
//

import UIKit
import RealityKit
import ARKit
import Combine

class ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet var arView: ARView!
    
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [0, 1, 0]
    let characterAnchor = AnchorEntity()
    let boxAnchor = AnchorEntity()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        arView.scene.addAnchor(characterAnchor)
        arView.scene.addAnchor(boxAnchor)

        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "character/robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
        }, receiveValue: { (character: Entity) in
            if let character = character as? BodyTrackedEntity {
                // Scale the character to human size
                character.scale = [1.0, 1.0, 1.0]
                self.character = character
                cancellable?.cancel()
            } else {
                print("Error: Unable to load model as BodyTrackedEntity")
            }
        })
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

            let box = ModelEntity (
                mesh: MeshResource.generateBox(size: 0.2),
                materials: [SimpleMaterial(color: .red, isMetallic: false)])
            
            // Update the position of the character anchor's position.
            let rightPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .rightHand)!.columns.3)

            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            characterAnchor.position = bodyPosition
            if boxAnchor.position == SIMD3<Float>.zero {
                boxAnchor.position = bodyPosition + rightPosition + characterOffset
            }

            let physicsBody = PhysicsBodyComponent()
            box.physicsBody = physicsBody

            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            //            rightPosition.z *= characterAnchor.orientation.imag.y

            //            boxAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation

            if let character = character, character.parent == nil {
                characterAnchor.addChild(character)
                boxAnchor.addChild(box)
            }
        }
    }
}
