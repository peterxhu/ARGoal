//
//  SettingsViewController.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import UIKit
import SafariServices

enum Setting: String {
    // Bool settings with SettingsViewController switches
    case showDetailedMessages
    case showARPlanes
    case showARFeaturePoints
    case showGoalOverlay
    case showGoalConfetti
    case dragOnInfinitePlanes
    case use3DOFFallback
    
    // Integer state used in virtual object picker
    case selectedObjectID

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Setting.showDetailedMessages.rawValue: true,
            Setting.showARPlanes.rawValue: true,
            Setting.showARFeaturePoints.rawValue: true,
            Setting.showGoalOverlay.rawValue: true,
            Setting.showGoalConfetti.rawValue: true,
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

class VirtualGoalSettingsViewController: UITableViewController, SFSafariViewControllerDelegate {
	
	@IBOutlet weak var debugModeSwitch: UISwitch!
    @IBOutlet weak var ARPlanesSwitch: UISwitch!
    @IBOutlet weak var ARFeaturePointsSwitch: UISwitch!
    @IBOutlet weak var goalDetectionOverlaySwitch: UISwitch!
    @IBOutlet weak var goalConfettiSwitch: UISwitch!
    
    @IBOutlet weak var dragOnInfinitePlanesSwitch: UISwitch!
	@IBOutlet weak var useAuto3DOFFallbackSwitch: UISwitch!
    
    @IBOutlet weak var howToTableViewCell: UITableViewCell!
    @IBOutlet weak var moreInfoTableViewCell: UITableViewCell!
    @IBOutlet weak var resetTutorialTableViewCell: UITableViewCell!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        populateSettings()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
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
            case goalDetectionOverlaySwitch:
                defaults.set(sender.isOn, for: .showGoalOverlay)
            case goalConfettiSwitch:
                defaults.set(sender.isOn, for: .showGoalConfetti)
            case dragOnInfinitePlanesSwitch:
                defaults.set(sender.isOn, for: .dragOnInfinitePlanes)
            case useAuto3DOFFallbackSwitch:
                defaults.set(sender.isOn, for: .use3DOFFallback)
            default: break
		}
	}
	
	private func populateSettings() {
		let defaults = UserDefaults.standard
		debugModeSwitch.isOn = defaults.bool(for: .showDetailedMessages)
		ARPlanesSwitch.isOn = defaults.bool(for: .showARPlanes)
        ARFeaturePointsSwitch.isOn = defaults.bool(for: .showARFeaturePoints)
        goalDetectionOverlaySwitch.isOn = defaults.bool(for: .showGoalOverlay)
        goalConfettiSwitch.isOn = defaults.bool(for: .showGoalConfetti)
		dragOnInfinitePlanesSwitch.isOn = defaults.bool(for: .dragOnInfinitePlanes)
		useAuto3DOFFallbackSwitch.isOn = defaults.bool(for: .use3DOFFallback)
	}
    
    /// MARK - Safari View Controller
    func loadHowToPage() {
        if let infoURL = URL(string: "https://github.com/peterxhu/ARGoal/wiki/ARGoal:-How-To-Guide") {
            let safariVC = SFSafariViewController(url: infoURL)
            self.present(safariVC, animated: true, completion: nil)
            safariVC.delegate = self
        }
    }
    
    func loadMoreInfoPage() {
        if let infoURL = URL(string: "https://github.com/peterxhu/ARGoal/blob/master/README.md") {
            let safariVC = SFSafariViewController(url: infoURL)
            self.present(safariVC, animated: true, completion: nil)
            safariVC.delegate = self
        }
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    /// MARK - Table View Delegate
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.selectionStyle = .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            switch selectedCell {
            case howToTableViewCell:
                loadHowToPage()
            case moreInfoTableViewCell:
                loadMoreInfoPage()
            case resetTutorialTableViewCell:
                loadMoreInfoPage()
                // TODO: create alert saying next time the app starts up, tips will be enabled
            default:
                break
            }
        }
    }
    
    
}
