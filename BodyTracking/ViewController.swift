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
    var counter = 0
    let boxAnchor = AnchorEntity()
    var headAnchor = AnchorEntity()
    
    var plusz: Float = 0
    var reancor = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        let transform = self.arView.cameraTransform
        headAnchor.transform = transform

        
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        arView.scene.addAnchor(boxAnchor)
        arView.scene.addAnchor(characterAnchor)
        arView.scene.addAnchor(headAnchor)
//        arView.scene.addAnchor(boxAnchor)

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
    
    @IBAction func didTapButton(_ sender: Any) {
        for child in boxAnchor.children {
            headAnchor.addChild(child)
        }
//        headAnchor = boxAnchor.clone(recursive: true)
        headAnchor.position = boxAnchor.position
//        headAnchor = boxAnchor
//        headAnchor = boxAnchor.clone(recursive: true)
//        headAnchor.transform = boxAnchor.transform
        boxAnchor.children.removeAll()
    }
    
    
    func addBox()  {
//        boxAnchor = AnchorEntity()
        let box = ModelEntity (
            mesh: MeshResource.generateBox(size: 0.1),
            materials: [SimpleMaterial(color: .red, isMetallic: false)])
        
        let transform = self.arView.cameraTransform
        let orientation = SCNVector3(x: -transform.matrix.columns.2.x, y: -transform.matrix.columns.2.y, z: -transform.matrix.columns.2.z)
        let location = SCNVector3(x: transform.matrix.columns.3.x, y: transform.matrix.columns.3.y, z: transform.matrix.columns.3.z)
        let plus =  SCNVector3Make(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
        box.position = simd_make_float3(plus.x, plus.y, plus.z)
//        self.arView.scene.anchors.append(box)
//        boxAnchor.position = self.arView.cameraTransform.translation
//        boxAnchor.position.z  -= 1
//        arView.scene.anchors.append(box)
//        arView.scene.addAnchor(box)
        if !reancor {
            plusz = plus.z
            boxAnchor.position = simd_make_float3(plus.x, plus.y, plus.z)
            reancor = true
        }
        boxAnchor.addChild(box)
//        return boxAnchor
    }
    
//    func add(box: ModelEntity) {
//
//    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

            // Update the position of the character anchor's position.
            let rightPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .rightHand)!.columns.3)
            let headPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .head)!.columns.3)

            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
//            headAnchor.anchoring = .init(<#T##target: AnchoringComponent.Target##AnchoringComponent.Target#>)
            characterAnchor.position = bodyPosition
//            headAnchor.setParent(character)
//            headAnchor.setPosition(bodyPosition + headPosition, relativeTo: character)
//          let tr = Transform(scale: [1.0, 1.0, 1.0], rotation: Transform(matrix: bodyAnchor.transform).rotation, translation: Transform(matrix: bodyAnchor.transform).translation)
//            headAnchor.transform = .init(matrix: float4x4(columns: ))
            
            characterAnchor.addChild(headAnchor)
            headAnchor.position = bodyPosition + headPosition
            headAnchor.position.z += plusz

//            headAnchor.transform = Transform(matrix: float4x4.ze)
//            if boxAnchor.position == SIMD3<Float>.zero {
//                boxAnchor.position = simd_make_float3(self.arView.cameraTransform.translation.x, self.arView.cameraTransform.translation.y, self.arView.cameraTransform.translation.z - 1)
//            }
            

            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            headAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            //            rightPosition.z *= characterAnchor.orientation.imag.y

            //            boxAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation

            if let character = character, character.parent == nil {
                characterAnchor.addChild(character)
//                headAnchor.position = headAnchor.convert(position: bodyPosition + headPosition, to: character)
//                boxAnchor.addChild(box)
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        addBox()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//            self.arView.scene.addAnchor(addBox())
        addBox()
    }
    

    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        counter += 1
    }
    
}



func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}
