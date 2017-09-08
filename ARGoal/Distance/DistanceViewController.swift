//
//  DistanceViewController.swift
//  ARGoal
//
//  Created by Peter Hu on 9/7/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import ARKit
import Foundation
import SceneKit
import UIKit
import Photos

class DistanceViewController: UIViewController, ARSCNViewDelegate, UIPopoverPresentationControllerDelegate, SCNPhysicsContactDelegate {
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    // MARK: - Main Setup & View Controller methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Setting.registerDefaults()
        setupScene()
        setupDebug()
        setupUIControls()
		updateSettings()
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed after a while.
		UIApplication.shared.isIdleTimerDisabled = true
		
		// Start the ARSession.
		restartPlaneDetection()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		session.pause()
	}
	
    // MARK: - ARKit / ARSCNView
    let session = ARSession()
    var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
	var use3DOFTracking = false {
		didSet {
			if use3DOFTracking {
                sessionConfig = AROrientationTrackingConfiguration()
			}
			sessionConfig.isLightEstimationEnabled = true
			session.run(sessionConfig)
		}
	}
	var use3DOFTrackingFallback = false
    @IBOutlet var sceneView: ARSCNView!
	var screenCenter: CGPoint?
    
    func setupScene() {
        // set up sceneView
        sceneView.delegate = self
        sceneView.session = session
		sceneView.antialiasingMode = .multisampling4X
		sceneView.automaticallyUpdatesLighting = true
        self.sceneView.autoenablesDefaultLighting = true
        
		sceneView.preferredFramesPerSecond = 60
		sceneView.contentScaleFactor = 1.3
        
		enableEnvironmentMapWithIntensity(25.0)
		
		DispatchQueue.main.async {
			self.screenCenter = self.sceneView.bounds.mid
		}
		
		if let camera = sceneView.pointOfView?.camera {
			camera.wantsHDR = true
			camera.wantsExposureAdaptation = true
			camera.exposureOffset = -1
			camera.minimumExposure = -1
		}
    }
	
	func enableEnvironmentMapWithIntensity(_ intensity: CGFloat) {
         let estimate: ARLightEstimate? = self.session.currentFrame?.lightEstimate
         if estimate == nil {
            return
         }
         // A value of 1000 is considered neutral, lighting environment intensity normalizes
         // 1.0 to neutral so we need to scale the ambientIntensity value
         let intensity: CGFloat? = (estimate?.ambientIntensity)! / 1000.0
         sceneView.scene.lightingEnvironment.intensity = intensity!
	}
	
    // MARK: - ARSCNViewDelegate
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		refreshFeaturePoints()
		
		DispatchQueue.main.async {
            self.enableEnvironmentMapWithIntensity(1000)
		}
	}
	
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
				self.addPlane(node: node, anchor: planeAnchor)
            }
        }
    }
	
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.updatePlane(anchor: planeAnchor)
            }
        }
    }
	
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.removePlane(anchor: planeAnchor)
            }
        }
    }
	
	var trackingFallbackTimer: Timer?

	func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: !self.showDetailedMessages)

        switch camera.trackingState {
        case .notAvailable:
            textManager.escalateFeedback(for: camera.trackingState, inSeconds: 5.0)
        case .limited:
            if use3DOFTrackingFallback {
                // After 10 seconds of limited quality, fall back to 3DOF mode.
                // 3DOF tracking maintains an AR illusion when the the device pivots
                // but not when the device's position moves
                trackingFallbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { _ in
                    self.use3DOFTracking = true
                    self.trackingFallbackTimer?.invalidate()
                    self.trackingFallbackTimer = nil
                })
            } else {
                textManager.escalateFeedback(for: camera.trackingState, inSeconds: 10.0)
            }
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
            if use3DOFTrackingFallback && trackingFallbackTimer != nil {
                trackingFallbackTimer!.invalidate()
                trackingFallbackTimer = nil
            }
        }
	}
	
    func session(_ session: ARSession, didFailWithError error: Error) {

        guard let arError = error as? ARError else { return }

        let nsError = error as NSError
		var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
		if let recoveryOptions = nsError.localizedRecoveryOptions {
			for option in recoveryOptions {
				sessionErrorMsg.append("\(option).")
			}
		}

        let isRecoverable = (arError.code == .worldTrackingFailed)
		if isRecoverable {
			sessionErrorMsg += "\nYou can try resetting the session or quit the application."
		} else {
			sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
		}
		
		displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
	}
	
	func sessionWasInterrupted(_ session: ARSession) {
		textManager.blurBackground()
		textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
	}
		
	func sessionInterruptionEnded(_ session: ARSession) {
		textManager.unblurBackground()
		session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
		restartExperience(self)
		textManager.showMessage("RESETTING SESSION")
	}
	
    // MARK: - Ambient Light Estimation
	
	func toggleAmbientLightEstimation(_ enabled: Bool) {
		
        if enabled {
			if !sessionConfig.isLightEstimationEnabled {
				// turn on light estimation
				sessionConfig.isLightEstimationEnabled = true
				session.run(sessionConfig)
			}
        } else {
			if sessionConfig.isLightEstimationEnabled {
				// turn off light estimation
				sessionConfig.isLightEstimationEnabled = false
				session.run(sessionConfig)
			}
        }
    }

	
	
    // MARK: - Planes
	
	var planes = [ARPlaneAnchor: Plane]()
	
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
		
		let pos = SCNVector3.positionFromTransform(anchor.transform)
		textManager.showDebugMessage("NEW SURFACE DETECTED AT \(pos.friendlyString())")
        
		let plane = Plane(anchor, showDetailedMessages)
		
		planes[anchor] = plane
		node.addChildNode(plane)
		
		textManager.cancelScheduledMessage(forType: .planeEstimation)
		textManager.showMessage("SURFACE DETECTED")
	}
		
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
			plane.update(anchor)
		}
	}
			
    func removePlane(anchor: ARPlaneAnchor) {
		if let plane = planes.removeValue(forKey: anchor) {
			plane.removeFromParentNode()
        }
    }
	
	func restartPlaneDetection() {
		
		// configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingConfiguration {
			worldSessionConfig.planeDetection = .horizontal
			session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
		}
		
		// reset timer
		if trackingFallbackTimer != nil {
			trackingFallbackTimer!.invalidate()
			trackingFallbackTimer = nil
		}
		
		textManager.scheduleMessage("FIND A SURFACE TO PLACE YOUR FIRST REFERENCE MARKER",
		                            inSeconds: 7.5,
		                            messageType: .planeEstimation)
	}

 
    // MARK: - Debug Visualizations
	
    @IBOutlet var featurePointCountLabel: UILabel!
	
    func refreshFeaturePoints() {
        guard showARFeaturePoints else {
            return
        }
        
        // retrieve cloud
        guard let cloud = session.currentFrame?.rawFeaturePoints else {
            return
        }
        
        DispatchQueue.main.async {
            self.featurePointCountLabel.text = "Features: \(cloud.__count)".uppercased()
        }
    }
	
    var showDetailedMessages: Bool = UserDefaults.standard.bool(for: .showDetailedMessages) {
        didSet {
            // Message Panel
            featurePointCountLabel.isHidden = !showDetailedMessages
            debugMessageLabel.isHidden = !showDetailedMessages
            messagePanel.isHidden = !showDetailedMessages
            // save pref
            UserDefaults.standard.set(showDetailedMessages, for: .showDetailedMessages)
        }
    }
    
    var showARPlanes: Bool = UserDefaults.standard.bool(for: .showARPlanes) {
        didSet {
            // Update Plane Visuals
            planes.values.forEach { $0.showARPlaneVisualizations(showARPlanes) }
    
            // save pref
            UserDefaults.standard.set(showARPlanes, for: .showARPlanes)
        }
    }
    
    var showARFeaturePoints: Bool = UserDefaults.standard.bool(for: .showARFeaturePoints) {
        didSet {
            // SceneView Visuals
            if showARFeaturePoints {
                sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
            } else {
                sceneView.debugOptions = []
            }
            // save pref
            UserDefaults.standard.set(showARFeaturePoints, for: .showARFeaturePoints)
        }
    }
    
    func setupDebug() {
        // Set appearance of debug output panel
        messagePanel.layer.cornerRadius = 3.0
        messagePanel.clipsToBounds = true
    }
       
    // MARK: - UI Elements and Actions
	
	@IBOutlet weak var messagePanel: UIView!
	@IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var debugMessageLabel: UILabel!
	
	var textManager: DistanceTextManager!
	
    func setupUIControls() {
		textManager = DistanceTextManager(viewController: self)
        
        // hide debug message view
        debugMessageLabel.isHidden = true
        
        featurePointCountLabel.text = ""
        debugMessageLabel.text = ""
		messageLabel.text = ""
    }
	
    
    @IBOutlet weak var closeExperienceButton: UIButton!
    
    @IBAction func closeExperience(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
	@IBOutlet weak var restartExperienceButton: UIButton!
	var restartExperienceButtonIsEnabled = true
	
	@IBAction func restartExperience(_ sender: Any) {
		
		guard restartExperienceButtonIsEnabled else {
			return
		}
		
		DispatchQueue.main.async {
			self.restartExperienceButtonIsEnabled = false
			self.textManager.cancelAllScheduledMessages()
			self.textManager.dismissPresentedAlert()
			self.textManager.showMessage("STARTING A NEW SESSION")
			self.use3DOFTracking = false
			
			self.restartPlaneDetection()
			self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
			
			// Disable Restart button for five seconds in order to give the session enough time to restart.
			DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
				self.restartExperienceButtonIsEnabled = true
			})
		}
	}
	
	@IBOutlet weak var screenshotButton: UIButton!
	
	@IBAction func takeScreenshot() {
		guard screenshotButton.isEnabled else {
			return
		}
		
		let takeScreenshotBlock = {
			UIImageWriteToSavedPhotosAlbum(self.sceneView.snapshot(), nil, nil, nil)
			DispatchQueue.main.async {
				// Briefly flash the screen.
				let flashOverlay = UIView(frame: self.sceneView.frame)
				flashOverlay.backgroundColor = UIColor.white
				self.sceneView.addSubview(flashOverlay)
				UIView.animate(withDuration: 0.25, animations: {
					flashOverlay.alpha = 0.0
				}, completion: { _ in
					flashOverlay.removeFromSuperview()
				})
			}
		}
		
		switch PHPhotoLibrary.authorizationStatus() {
		case .authorized:
			takeScreenshotBlock()
		case .restricted, .denied:
			let title = "Photos access denied"
			let message = "Please enable Photos access for this application in Settings > Privacy to allow saving screenshots."
			textManager.showAlert(title: title, message: message)
		case .notDetermined:
			PHPhotoLibrary.requestAuthorization({ (authorizationStatus) in
				if authorizationStatus == .authorized {
					takeScreenshotBlock()
				}
			})
		}
	}
    
    // MARK: - Settings
	@IBOutlet weak var settingsButton: UIButton!
	
	@IBAction func showSettings(_ button: UIButton) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		guard let settingsViewController = storyboard.instantiateViewController(withIdentifier: "settingsViewController") as? VirtualGoalSettingsViewController else {
			return
		}
		
		let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSettings))
		settingsViewController.navigationItem.rightBarButtonItem = barButtonItem
		settingsViewController.title = "Options"
		
		let navigationController = UINavigationController(rootViewController: settingsViewController)
		navigationController.modalPresentationStyle = .popover
		navigationController.popoverPresentationController?.delegate = self
		navigationController.preferredContentSize = CGSize(width: sceneView.bounds.size.width - 20, height: sceneView.bounds.size.height - 50)
		self.present(navigationController, animated: true, completion: nil)
		
		navigationController.popoverPresentationController?.sourceView = settingsButton
		navigationController.popoverPresentationController?.sourceRect = settingsButton.bounds
	}
    
    @objc
    func dismissSettings() {
		self.dismiss(animated: true, completion: nil)
		updateSettings()
	}
	
	private func updateSettings() {
		let defaults = UserDefaults.standard
        showDetailedMessages = defaults.bool(for: .showDetailedMessages)
        showARPlanes = defaults.bool(for: .showARPlanes)
        showARFeaturePoints = defaults.bool(for: .showARFeaturePoints)
		use3DOFTrackingFallback = defaults.bool(for: .use3DOFFallback)
	}

	// MARK: - Error handling
	
	func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
		// Blur the background.
		textManager.blurBackground()
		
		if allowRestart {
			// Present an alert informing about the error that has occurred.
			let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
				self.textManager.unblurBackground()
				self.restartExperience(self)
			}
			textManager.showAlert(title: title, message: message, actions: [restartAction])
		} else {
			textManager.showAlert(title: title, message: message, actions: [])
		}
	}
	
	// MARK: - UIPopoverPresentationControllerDelegate
	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}
	
	func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		updateSettings()
	}
}
