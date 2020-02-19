//
//  SettingsViewController.swift
//  BodyTracking
//
//  Created by Zewu Chen on 19/02/20.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet weak var slider: UISlider!
    let defauts = UserDefaults()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        
        slider.value = defauts.float(forKey: "Color")
        let color = UIColor(hue: CGFloat(defauts.float(forKey: "Color")), saturation: 1, brightness: 1, alpha: 1)
        slider.tintColor = color
    }
    
    @IBAction func changedValueSlider(_ sender: Any) {
        let color = UIColor(hue: CGFloat(slider.value), saturation: 1, brightness: 1, alpha: 1)
        slider.tintColor = color
        
        defauts.set(CGFloat(slider.value), forKey: "Color")
    }
    
}
