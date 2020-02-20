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

    var headAnchor = AnchorEntity()
    var leftHandAnchor = AnchorEntity()
    var rightHandAnchor = AnchorEntity()
    var rightFootAnchor = AnchorEntity()
    var leftFootAnchor = AnchorEntity()


    var cellImages: [String] = ["cabeça", "mão-direita",  "pé-direito", "mão-esquerda", "pé-esquerdo"]
    var CUSTOMCELL = "CustomCollectionViewCell"
    
    var plusz: Float = 0
    var reancor = false
    var mayDraw = true
    var offset: SIMD3<Float>?
    
    let defauts = UserDefaults()
    
    @IBOutlet weak var blurView: UIView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        
        slider.value = defauts.float(forKey: "Color")
        let color = UIColor(hue: CGFloat(defauts.float(forKey: "Color")), saturation: 1, brightness: 1, alpha: 1)
        slider.tintColor = color
        
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: CUSTOMCELL, bundle: nil), forCellWithReuseIdentifier: CUSTOMCELL)
        collectionView.delegate = self

        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = blurView.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = 0.5
        blurView.addSubview(blurEffectView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(fire), userInfo: nil, repeats: true)

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
    
    @objc func fire(){
        mayDraw = true
    }
    
    func addBox(pos:  SIMD3<Float>)  {
        let color = UIColor(hue: CGFloat(UserDefaults.standard.float(forKey: "Color")), saturation: 1, brightness: 1, alpha: 1)
        let box = ModelEntity (
                    mesh: MeshResource.generateSphere(radius: 0.02),
        //            materials: [UnlitMaterial(color: .red)])
                    materials: [UnlitMaterial(color: color)])
                let transform = self.arView.cameraTransform
                let orientation = SCNVector3(x: -transform.matrix.columns.2.x, y: -transform.matrix.columns.2.y, z: -transform.matrix.columns.2.z)
                let location = SCNVector3(x: transform.matrix.columns.3.x, y: transform.matrix.columns.3.y, z: transform.matrix.columns.3.z)
                let plus =  SCNVector3Make(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
                let position = simd_make_float3(plus.x, plus.y, plus.z)
                
                if let ofset = offset {
//                    ofset.z -= plus.z
                    var aux = pos
                    aux.z = plus.z
                    box.position = aux - ofset
//                    box.position = ofset
                } else {
                    offset = pos
                    box.position = simd_make_float3(0, 0, 0)
                }
                
                if !reancor {
                    plusz = plus.z
                    boxAnchor.position = position
                    
                    reancor = true
                }
                boxAnchor.addChild(box)
        
    }

    func moveBoxToAnchor(_ anchor: AnchorEntity) {

        anchor.children.removeAll()
        for child in boxAnchor.children {
            anchor.addChild(child)
        }
        anchor.position = boxAnchor.position
        
        boxAnchor.children.removeAll()
        // boxAnchor.removeFromParent() //TESTAR
        offset = nil
        reancor = false
    }

    func setPositionOf(anchor: AnchorEntity, position: simd_float3, bodyAnchor: ARBodyAnchor) {
        anchor.anchoring = AnchoringComponent(.body)
        anchor.position = simd_make_float3(0, 0, 0) + position
        anchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

            let headPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .head)!.columns.3)
            let rightHandPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .rightHand)!.columns.3)
            let leftHandPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .leftHand)!.columns.3)
            let rightFootPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .rightFoot)!.columns.3)
            let leftFootPosition = simd_make_float3(bodyAnchor.skeleton.modelTransform(for: .leftFoot)!.columns.3)
            
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)

            characterAnchor.position = bodyPosition
            
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation

            setPositionOf(anchor: headAnchor, position: headPosition, bodyAnchor: bodyAnchor)
            setPositionOf(anchor: rightHandAnchor, position: rightHandPosition, bodyAnchor: bodyAnchor)
            setPositionOf(anchor: leftHandAnchor, position: leftHandPosition, bodyAnchor: bodyAnchor)
            setPositionOf(anchor: rightFootAnchor, position: rightFootPosition, bodyAnchor: bodyAnchor)
            setPositionOf(anchor: leftFootAnchor, position: leftFootPosition, bodyAnchor: bodyAnchor)
            if let character = character, character.parent == nil {
//                characterAnchor.addChild(character)
                characterAnchor.addChild(headAnchor)
                characterAnchor.addChild(rightHandAnchor)
                characterAnchor.addChild(leftHandAnchor)
                characterAnchor.addChild(rightFootAnchor)
                characterAnchor.addChild(leftFootAnchor)
            } else {
                characterAnchor.addChild(headAnchor)
                characterAnchor.addChild(rightHandAnchor)
                characterAnchor.addChild(leftHandAnchor)
                characterAnchor.addChild(rightFootAnchor)
                characterAnchor.addChild(leftFootAnchor)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let transform = self.arView.cameraTransform
                let orientation = SCNVector3(x: -transform.matrix.columns.2.x, y: -transform.matrix.columns.2.y, z: -transform.matrix.columns.2.z)
                let location = SCNVector3(x: transform.matrix.columns.3.x, y: transform.matrix.columns.3.y, z: transform.matrix.columns.3.z)
                let plus =  SCNVector3Make(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
                for touch in touches {
                    let p = touch.location(in: arView)
                    if mayDraw {
                        let pos = simd_make_float3(Float(p.x)/1000, Float(-p.y)/1000, plus.z)
                        addBox(pos: pos)
                        mayDraw = false
                    }
                }
    }
    
    @IBAction func changedValueSlider(_ sender: Any) {
        let color = UIColor(hue: CGFloat(slider.value), saturation: 1, brightness: 1, alpha: 1)
        slider.tintColor = color
        defauts.set(CGFloat(slider.value), forKey: "Color")
    }
    
}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CUSTOMCELL, for: indexPath) as? CustomCollectionViewCell
        cell?.image.image = UIImage(named: cellImages[indexPath.row])
        return cell ?? CustomCollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            moveBoxToAnchor(headAnchor)
        case 1:
            moveBoxToAnchor(rightHandAnchor)
        case 2:
            moveBoxToAnchor(rightFootAnchor)
        case 3:
            moveBoxToAnchor(leftHandAnchor)
        case 4:
            moveBoxToAnchor(leftFootAnchor)
        default:
            break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        UIView.animate(withDuration: 0.5) {
            if let cell = collectionView.cellForItem(at: indexPath) as? CustomCollectionViewCell {
                cell.image.transform = .init(scaleX: 0.95, y: 0.95)
                cell.contentView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        UIView.animate(withDuration: 0.5) {
            if let cell = collectionView.cellForItem(at: indexPath) as? CustomCollectionViewCell {
                cell.image.transform = .identity
                cell.contentView.backgroundColor = .clear
            }
        }
    }
    
}
