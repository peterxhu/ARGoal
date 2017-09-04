//
//  SettingsViewController.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import UIKit

enum Setting: String {
    // Bool settings with SettingsViewController switches
    case showDetailedMessages
    case showARPlanes
    case showARFeaturePoints
    case dragOnInfinitePlanes
    case use3DOFFallback
    
    // Integer state used in virtual object picker
    case selectedObjectID

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Setting.showDetailedMessages.rawValue: true,
            Setting.showARPlanes.rawValue: true,
            Setting.showARFeaturePoints.rawValue: true,
            Setting.dragOnInfinitePlanes.rawValue: true,
            Setting.use3DOFFallback.rawValue: true,
            Setting.selectedObjectID.rawValue: -1
        ])
    }
}
extension UserDefaults {
    func bool(for setting: Setting) -> Bool {
        return bool(forKey: setting.rawValue)
    }
    func set(_ bool: Bool, for setting: Setting) {
        set(bool, forKey: setting.rawValue)
    }
    func integer(for setting: Setting) -> Int {
        return integer(forKey: setting.rawValue)
    }
    func set(_ integer: Int, for setting: Setting) {
        set(integer, forKey: setting.rawValue)
    }
}

class SettingsViewController: UITableViewController {
	
	@IBOutlet weak var debugModeSwitch: UISwitch!
    @IBOutlet weak var ARPlanesSwitch: UISwitch!
    @IBOutlet weak var ARFeaturePointsSwitch: UISwitch!
    @IBOutlet weak var dragOnInfinitePlanesSwitch: UISwitch!
	@IBOutlet weak var useAuto3DOFFallbackSwitch: UISwitch!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        populateSettings()
    }

	@IBAction func didChangeSetting(_ sender: UISwitch) {
		let defaults = UserDefaults.standard
		switch sender {
            case debugModeSwitch:
                defaults.set(sender.isOn, for: .showDetailedMessages)
            case ARPlanesSwitch:
                defaults.set(sender.isOn, for: .showARPlanes)
            case ARFeaturePointsSwitch:
                defaults.set(sender.isOn, for: .showARFeaturePoints)
            case dragOnInfinitePlanesSwitch:
                defaults.set(sender.isOn, for: .dragOnInfinitePlanes)
            case useAuto3DOFFallbackSwitch:
                defaults.set(sender.isOn, for: .use3DOFFallback)
            default: break
		}
	}
	
	private func populateSettings() {
		let defaults = UserDefaults.standard
		debugModeSwitch.isOn = defaults.bool(for: Setting.showDetailedMessages)
		ARPlanesSwitch.isOn = defaults.bool(for: .showARPlanes)
        ARFeaturePointsSwitch.isOn = defaults.bool(for: .showARFeaturePoints)
		dragOnInfinitePlanesSwitch.isOn = defaults.bool(for: .dragOnInfinitePlanes)
		useAuto3DOFFallbackSwitch.isOn = defaults.bool(for: .use3DOFFallback)
	}
}
