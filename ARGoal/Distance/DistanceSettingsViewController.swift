//
//  DistanceSettingsViewController.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import UIKit
import SafariServices

class DistanceSettingsViewController: UITableViewController, SFSafariViewControllerDelegate {
	
    // Shared settings with VirtualGoalSettingsViewController
	@IBOutlet weak var debugModeSwitch: UISwitch!
    @IBOutlet weak var ARPlanesSwitch: UISwitch!
    @IBOutlet weak var ARFeaturePointsSwitch: UISwitch!
    
    // Independent settings
    @IBOutlet weak var realTimeCalculationsSwitch: UISwitch!
    
    @IBOutlet weak var howToTableViewCell: UITableViewCell!
    @IBOutlet weak var moreInfoTableViewCell: UITableViewCell!
    @IBOutlet weak var resetTutorialTableViewCell: UITableViewCell!
    
    @IBOutlet weak var appVersionLabel: UILabel!
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        populateSettings()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        appVersionLabel.text = UtilityMethods.appVersion()
    }
    
	@IBAction func didChangeSetting(_ sender: UISwitch) {
		let defaults = UserDefaults.standard
		switch sender {
            case debugModeSwitch:
                defaults.set(sender.isOn, for: .showDetailedMessages)
            case ARPlanesSwitch:
                defaults.set(sender.isOn, for: .showOverlayARPlanes)
            case ARFeaturePointsSwitch:
                defaults.set(sender.isOn, for: .showARFeaturePoints)
            case realTimeCalculationsSwitch:
                defaults.set(sender.isOn, for: .realTimeCalculations)
            default: break
		}
	}
	
	private func populateSettings() {
		let defaults = UserDefaults.standard
		debugModeSwitch.isOn = defaults.bool(for: .showDetailedMessages)
		ARPlanesSwitch.isOn = defaults.bool(for: .showOverlayARPlanes)
        ARFeaturePointsSwitch.isOn = defaults.bool(for: .showARFeaturePoints)
		realTimeCalculationsSwitch.isOn = defaults.bool(for: .realTimeCalculations)
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
                let dismissAction = UIAlertAction(title: "OK", style: .cancel)
                showAlert(title: "Tutorial Reset", message: "Next time you load \"Goal Distance\", the tutorial will start", actions: [dismissAction])
                UserDefaults.standard.set(false, for: .distanceMarkGoal1TutorialFulfilled)
                UserDefaults.standard.set(false, for: .distanceRealTime2TutorialFulfilled)
                UserDefaults.standard.set(false, for: .distanceMarkMe3TutorialFulfilled)
                UserDefaults.standard.set(false, for: .distanceSuggestion4TutorialFulfilled)
                UserDefaults.standard.set(false, for: .distanceTapScreen5TutorialFulfilled)
                UserDefaults.standard.set(false, for: .distanceEndOfTutorial6TutorialFulfilled)
            default:
                break
            }
        }
    }
    
    func showAlert(title: String, message: String, actions: [UIAlertAction]? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let actions = actions {
            for action in actions {
                alertController.addAction(action)
            }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        self.present(alertController, animated: true, completion: nil)
    }
    
    
}
