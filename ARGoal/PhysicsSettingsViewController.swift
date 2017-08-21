//
//  PhysicsSettingsViewController.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import UIKit

enum PhysicsSetting: String {
    // Bool settings with PhysicsSettingsViewController switches
    case isProjectileAffectedByGravity

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            PhysicsSetting.isProjectileAffectedByGravity.rawValue: false])
    }
}
extension UserDefaults {
    func bool(for physicsSetting: PhysicsSetting) -> Bool {
        return bool(forKey: physicsSetting.rawValue)
    }
    func set(_ bool: Bool, for physicsSetting: PhysicsSetting) {
        set(bool, forKey: physicsSetting.rawValue)
    }
    func integer(for physicsSetting: PhysicsSetting) -> Int {
        return integer(forKey: physicsSetting.rawValue)
    }
    func set(_ integer: Int, for physicsSetting: PhysicsSetting) {
        set(integer, forKey: physicsSetting.rawValue)
    }
}

class PhysicsSettingsViewController: UITableViewController {
	
    @IBOutlet weak var gravitySwitch: UISwitch!
    @IBOutlet weak var directionSlider: UISlider!
    @IBOutlet weak var powerSlider: UISlider!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        populatePhysicsSettings()
    }

	@IBAction func didChangePhysicsSetting(_ sender: UISwitch) {
		let defaults = UserDefaults.standard
		switch sender {
            case gravitySwitch:
                defaults.set(sender.isOn, for: .isProjectileAffectedByGravity)
            default: break
		}
	}
	
	private func populatePhysicsSettings() {
		let defaults = UserDefaults.standard
		gravitySwitch.isOn = defaults.bool(for: PhysicsSetting.isProjectileAffectedByGravity)
	}
}
