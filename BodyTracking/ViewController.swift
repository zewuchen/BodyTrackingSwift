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
    var leftHandAnchor = AnchorEntity()
    var rightHandAnchor = AnchorEntity()
    var rightFootAnchor = AnchorEntity()
    var leftFootAnchor = AnchorEntity()
    var cells: [String] = ["cabeça", "mão-direita", "mão-esquerda", "pé-direito", "pé-esquerdo"]
    var CUSTOMCELL = "CustomCollectionViewCell"
    
    var plusz: Float = 0
    var reancor = false
    
    let defauts = UserDefaults()
    
    @IBOutlet weak var slider: UISlider!
    
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        
        slider.value = defauts.float(forKey: "Color")
        let color = UIColor(hue: CGFloat(defauts.float(forKey: "Color")), saturation: 1, brightness: 1, alpha: 1)
        slider.tintColor = color
        
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: CUSTOMCELL, bundle: nil), forCellWithReuseIdentifier: CUSTOMCELL)
        collectionView.delegate = self
    }
    
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
        arView.scene.addAnchor(leftFootAnchor)
        arView.scene.addAnchor(rightFootAnchor)
        arView.scene.addAnchor(leftHandAnchor)
        arView.scene.addAnchor(rightHandAnchor)
        
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
    
    func moveBoxToAnchor(_ anchor: AnchorEntity) {
        for child in boxAnchor.children {
            anchor.addChild(child)
        }
        anchor.position = boxAnchor.position
        boxAnchor.children.removeAll()
    }
    
    
    func addBox()  {
        let color = UIColor(hue: CGFloat(UserDefaults.standard.float(forKey: "Color")), saturation: 1, brightness: 1, alpha: 1)
        let box = ModelEntity (
            mesh: MeshResource.generateBox(size: 0.1),
            materials: [SimpleMaterial(color: color, isMetallic: false)])
        
        let transform = self.arView.cameraTransform
        let orientation = SCNVector3(x: -transform.matrix.columns.2.x, y: -transform.matrix.columns.2.y, z: -transform.matrix.columns.2.z)
        let location = SCNVector3(x: transform.matrix.columns.3.x, y: transform.matrix.columns.3.y, z: transform.matrix.columns.3.z)
        let plus =  SCNVector3Make(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
        box.position = simd_make_float3(plus.x, plus.y, plus.z)
        if !reancor {
            plusz = plus.z
            boxAnchor.position = simd_make_float3(plus.x, plus.y, plus.z)
            reancor = true
        }
        boxAnchor.addChild(box)
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            
            // Update the position of the character anchor's position.
            let rightPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .rightHand)!.columns.3)
            let headPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .head)!.columns.3)
            
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            characterAnchor.position = bodyPosition
            
            characterAnchor.addChild(headAnchor)
            headAnchor.position = bodyPosition + headPosition
            headAnchor.position.z += plusz
            
            
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            headAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            
            if let character = character, character.parent == nil {
                characterAnchor.addChild(character)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        addBox()
    }
    
    @IBAction func changedValueSlider(_ sender: Any) {
        let color = UIColor(hue: CGFloat(slider.value), saturation: 1, brightness: 1, alpha: 1)
        slider.tintColor = color
        
        defauts.set(CGFloat(slider.value), forKey: "Color")
    }
    
}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cells.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CUSTOMCELL, for: indexPath) as? CustomCollectionViewCell
        cell?.image.image = UIImage(named: cells[indexPath.row])
        return cell ?? CustomCollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            moveBoxToAnchor(headAnchor)
        case 1:
            moveBoxToAnchor(rightHandAnchor)
        case 2:
            moveBoxToAnchor(leftHandAnchor)
        case 3:
            moveBoxToAnchor(rightFootAnchor)
        case 4:
            moveBoxToAnchor(leftFootAnchor)
        default:
            break
        }
    }
    
}
