//
//  VirtualGoalViewController.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import ARKit
import Foundation
import SceneKit
import UIKit
import Photos
import ReplayKit

enum PhysicsBodyType: Int {
    case projectile = 10 // ball
    case goalFrame = 11 // goal frame (cross bar)
    case plane = 12 // ground
    case goalPlane = 13  // goal scoring plane (detect goal)
}

class VirtualGoalViewController: UIViewController, ARSCNViewDelegate, UIPopoverPresentationControllerDelegate, SCNPhysicsContactDelegate,  VirtualObjectSelectionViewControllerDelegate, RPScreenRecorderDelegate, RPPreviewViewControllerDelegate {
    
    let cheerView = CheerView()
    var timer: Timer = Timer()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cheerView.frame = view.bounds
    }
    
    // MARK: - Main Setup & View Controller methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cheerView.config.particle = .confetti
        view.addSubview(cheerView)
        
        circlePowerMeter.isHidden = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(triggerNormalTap(_:)))
        let longGesture = TimedLongPressGesture(target: self, action: #selector(triggerLongTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        triggerButton.addGestureRecognizer(tapGesture)
        triggerButton.addGestureRecognizer(longGesture)

        Setting.registerDefaults()
        setupScene()
        setupDebug()
        setupUIControls()
		setupFocusSquare()
		updateSettings()
		resetVirtualObject()
        
        // TODO: work on a step by step tutorial
        // TODO: work on making the goal detection node dynamic and allowing physics to bounce off
        // _ = UtilityMethods.showToolTip(for: addObjectButton, superview: view, text: "Start here! Add a goal!", position: .bottom)

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
        self.sceneView.scene.physicsWorld.contactDelegate = self
        
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
			self.updateFocusSquare()
            self.enableEnvironmentMapWithIntensity(1000)
		}
	}
	
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
				self.addPlane(node: node, anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
	
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.updatePlane(anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
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
        textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended. If issues still persist, please use the \"X\" button to close and reopen the session.")
        restartExperience(self)

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

    // MARK: - Gesture Recognizers
	
	var currentGesture: Gesture?
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let object = virtualObject else {
			return
		}
		
		if currentGesture == nil {
			currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, object)
		} else {
			currentGesture = currentGesture!.updateGestureFromTouches(touches, .touchBegan)
		}
		
		displayVirtualObjectTransform()
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if virtualObject == nil {
			return
		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchMoved)
		displayVirtualObjectTransform()
	}
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		if virtualObject == nil {
			chooseObject(addObjectButton)
			return
		}
		
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchEnded)
	}
	
	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		if virtualObject == nil {
			return
		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchCancelled)
	}
	
	// MARK: - Virtual Object Manipulation
	
	func displayVirtualObjectTransform() {
		
		guard let object = virtualObject, let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}
		
		// Output the current translation, rotation & scale of the virtual object as text.
		
		let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
		let vectorToCamera = cameraPos - object.position
		
		let distanceToUser = vectorToCamera.length()
		
		var angleDegrees = Int(((object.eulerAngles.y) * 180) / Float.pi) % 360
		if angleDegrees < 0 {
			angleDegrees += 360
		}
		
		let distance = String(format: "%.2f", distanceToUser)
		let scale = String(format: "%.2f", object.scale.x)
		textManager.showDebugMessage("Distance: \(distance) m\nRotation: \(angleDegrees)°\nScale: \(scale)x")
	}
	
	func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {
		
		guard let newPosition = pos else {
			textManager.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
			// Reset the content selection in the menu only if the content has not yet been initially placed.
			if virtualObject == nil {
				resetVirtualObject()
			}
			return
		}
		
		if instantly {
			setNewVirtualObjectPosition(newPosition)
		} else {
			updateVirtualObjectPosition(newPosition, filterPosition)
		}
	}
	
	var dragOnInfinitePlanesEnabled = false
	
	func worldPositionFromScreenPosition(_ position: CGPoint,
	                                     objectPos: SCNVector3?,
	                                     infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
		
		// -------------------------------------------------------------------------------
		// 1. Always do a hit test against exisiting plane anchors first.
		//    (If any such anchors exist & only within their extents.)
		
		let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
		if let result = planeHitTestResults.first {
			
			let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
			let planeAnchor = result.anchor
			
			// Return immediately - this is the best possible outcome.
			return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
		}
		
		// -------------------------------------------------------------------------------
		// 2. Collect more information about the environment by hit testing against
		//    the feature point cloud, but do not return the result yet.
		
		var featureHitTestPosition: SCNVector3?
		var highQualityFeatureHitTestResult = false
		
		let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
		
		if !highQualityfeatureHitTestResults.isEmpty {
			let result = highQualityfeatureHitTestResults[0]
			featureHitTestPosition = result.position
			highQualityFeatureHitTestResult = true
		}
		
		// -------------------------------------------------------------------------------
		// 3. If desired or necessary (no good feature hit test result): Hit test
		//    against an infinite, horizontal plane (ignoring the real world).
		
		if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
			
			let pointOnPlane = objectPos ?? SCNVector3Zero
			
			let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
			if pointOnInfinitePlane != nil {
				return (pointOnInfinitePlane, nil, true)
			}
		}
		
		// -------------------------------------------------------------------------------
		// 4. If available, return the result of the hit test against high quality
		//    features if the hit tests against infinite planes were skipped or no
		//    infinite plane was hit.
		
		if highQualityFeatureHitTestResult {
			return (featureHitTestPosition, nil, false)
		}
		
		// -------------------------------------------------------------------------------
		// 5. As a last resort, perform a second, unfiltered hit test against features.
		//    If there are no features in the scene, the result returned here will be nil.
		
		let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
		if !unfilteredFeatureHitTestResults.isEmpty {
			let result = unfilteredFeatureHitTestResults[0]
			return (result.position, nil, false)
		}
		
		return (nil, nil, false)
	}
	
	// Use average of recent virtual object distances to avoid rapid changes in object scale.
	var recentVirtualObjectDistances = [CGFloat]()
	
    func setNewVirtualObjectPosition(_ pos: SCNVector3) {
	
		guard let object = virtualObject, let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}
		
		recentVirtualObjectDistances.removeAll()
		
		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		
		// Limit the distance of the object from the camera to a maximum of 10 meters.
		cameraToPosition.setMaximumLength(10)

		object.position = cameraWorldPos + cameraToPosition
		
		if object.parent == nil {
            if let goalPlane = object.childNode(withName: "goalPlane", recursively: true) {
                if enableGoalDetection {
                    goalPlane.opacity = 0.5
                } else {
                    goalPlane.removeFromParentNode()
                }
                goalPlane.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: goalPlane, options: nil))
                goalPlane.physicsBody?.categoryBitMask = PhysicsBodyType.goalPlane.rawValue
            }
			sceneView.scene.rootNode.addChildNode(object)
		}
    }

	func resetVirtualObject() {
		virtualObject?.unloadModel()
		virtualObject?.removeFromParentNode()
		virtualObject = nil
        DispatchQueue.main.async {
            self.triggerButton.isHidden = true
            self.triggerIconImageView.isHidden = true
        }
		addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
		addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])
		
		// Reset selected object id for row highlighting in object selection view controller.
		UserDefaults.standard.set(-1, for: .selectedObjectID)
	}
	
	func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
		guard let object = virtualObject else {
			return
		}
		
		guard let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}
		
		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		
		// Limit the distance of the object from the camera to a maximum of 10 meters.
		cameraToPosition.setMaximumLength(10)
		
		// Compute the average distance of the object from the camera over the last ten
		// updates. If filterPosition is true, compute a new position for the object
		// with this average. Notice that the distance is applied to the vector from
		// the camera to the content, so it only affects the percieved distance of the
		// object - the averaging does _not_ make the content "lag".
		let hitTestResultDistance = CGFloat(cameraToPosition.length())

		recentVirtualObjectDistances.append(hitTestResultDistance)
		recentVirtualObjectDistances.keepLast(10)
		
		if filterPosition {
			let averageDistance = recentVirtualObjectDistances.average!
			
			cameraToPosition.setLength(Float(averageDistance))
			let averagedDistancePos = cameraWorldPos + cameraToPosition

			object.position = averagedDistancePos
		} else {
			object.position = cameraWorldPos + cameraToPosition
		}
    }
	
	func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
		guard let object = virtualObject, let planeAnchorNode = sceneView.node(for: anchor) else {
			return
		}
		
		// Get the object's position in the plane's coordinate system.
		let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)
		
		if objectPos.y == 0 {
			return; // The object is already on the plane - nothing to do here.
		}
		
		// Add 10% tolerance to the corners of the plane.
		let tolerance: Float = 0.1
		
		let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
		let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
		let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
		let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
		
		if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
			return
		}
		
		// Drop the object onto the plane if it is near it.
		let verticalAllowance: Float = 0.03
		if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
			textManager.showDebugMessage("OBJECT MOVED\nSurface detected nearby")
			
			SCNTransaction.begin()
			SCNTransaction.animationDuration = 0.5
			SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
			object.position.y = anchor.transform.columns.3.y
			SCNTransaction.commit()
		}
	}
	
    // MARK: - Virtual Object Loading
	
	var virtualObject: VirtualObject?
	var isLoadingObject: Bool = false {
		didSet {
			DispatchQueue.main.async {
				self.settingsButton.isEnabled = !self.isLoadingObject
				self.addObjectButton.isEnabled = !self.isLoadingObject
				self.screenshotButton.isEnabled = !self.isLoadingObject
				self.restartExperienceButton.isEnabled = !self.isLoadingObject
			}
		}
	}
	
    // MARK: - Projectile Launching

    @IBOutlet weak var triggerButton: UIButton!
    @IBOutlet weak var triggerIconImageView: UIImageView!
    
    var lastContactNode: SCNNode!

    @IBOutlet weak var circlePowerMeter: CircleProgressView!
    @IBOutlet weak var powerMeterLabel: UILabel!

    @objc func triggerNormalTap(_ sender: UIGestureRecognizer) {
        shootObject(longPressMultiplier: 0.5)
    }
    
    @objc func triggerLongTap(_ gesture: TimedLongPressGesture) {
        if gesture.state == .ended {
            let duration = NSDate().timeIntervalSince(gesture.startTime! as Date)
            print(duration.description)
            shootObject(longPressMultiplier: Float(circlePowerMeter.progress))
            circlePowerMeter.isHidden = true
            timer.invalidate()
        } else if gesture.state == .began {
            gesture.startTime = NSDate()
            circlePowerMeter.progress = 0
            powerMeterLabel.text = "0"
            circlePowerMeter.isHidden = false
            timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(increaseProgressBar), userInfo: nil, repeats: true)
        }
    }
    
    @objc func increaseProgressBar() {
        if circlePowerMeter.progress < 1 {
            let newProgress = circlePowerMeter.progress + 0.01
            circlePowerMeter.progress = newProgress
            powerMeterLabel.text = String(format: "%.2f", newProgress)
        }
    }
    
    func shootObject(longPressMultiplier: Float = 1) {
        
        guard let currentFrame = self.sceneView.session.currentFrame else {
            return
        }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.3
        
        if let footballObjectScene = SCNScene(named: "football.scn", inDirectory: "Models.scnassets/football"), self.virtualObject is FieldGoal {
            guard let footballNode = footballObjectScene.rootNode.childNode(withName: "football", recursively: true)
                else {
                    fatalError("Node not found!")
            }
            let projectileNode: SCNNode = SCNNode()
            projectileNode.addChildNode(footballNode)
            projectileNode.name = "Projectile"
            projectileNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: projectileNode, options: nil))
            projectileNode.physicsBody?.isAffectedByGravity = true
            projectileNode.physicsBody?.categoryBitMask = PhysicsBodyType.projectile.rawValue
            projectileNode.physicsBody?.contactTestBitMask = PhysicsBodyType.goalFrame.rawValue
            projectileNode.physicsBody?.contactTestBitMask = PhysicsBodyType.goalPlane.rawValue
            projectileNode.physicsBody?.contactTestBitMask = PhysicsBodyType.plane.rawValue
            
            projectileNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
            let forceVector = SCNVector3(projectileNode.worldFront.x * 1,10 * longPressMultiplier, projectileNode.worldFront.z)
            projectileNode.physicsBody?.applyForce(forceVector, asImpulse: true)
            self.sceneView.scene.rootNode.addChildNode(projectileNode)
        } else if let soccerObjectScene = SCNScene(named: "soccerBall.scn", inDirectory: "Models.scnassets/soccerBall"), self.virtualObject is SoccerGoal {
            guard let soccerNode = soccerObjectScene.rootNode.childNode(withName: "ball", recursively: true)
                else {
                    fatalError("Node not found!")
            }
            let projectileNode: SCNNode = SCNNode()
            projectileNode.addChildNode(soccerNode)
            projectileNode.name = "Projectile"
            projectileNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: projectileNode, options: nil))
            projectileNode.physicsBody?.isAffectedByGravity = false
            projectileNode.physicsBody?.categoryBitMask = PhysicsBodyType.projectile.rawValue
            projectileNode.physicsBody?.contactTestBitMask = PhysicsBodyType.goalFrame.rawValue
            projectileNode.physicsBody?.contactTestBitMask = PhysicsBodyType.goalPlane.rawValue
            projectileNode.physicsBody?.contactTestBitMask = PhysicsBodyType.plane.rawValue
            projectileNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
            let forceMultiplier = 10 * longPressMultiplier
            let forceVector = SCNVector3(projectileNode.worldFront.x * forceMultiplier, projectileNode.worldFront.y * forceMultiplier, projectileNode.worldFront.z * forceMultiplier)
            projectileNode.physicsBody?.applyForce(forceVector, asImpulse: true)
            self.sceneView.scene.rootNode.addChildNode(projectileNode)
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        let contactNode: SCNNode!
        
        // Make sure we set the contact node to what we suspect to be the projectile
        if contact.nodeA.name == "Projectile" {
            contactNode = contact.nodeB
        } else {
            contactNode = contact.nodeA
        }
        // Validate that that the collision is what we wanted
        if let hitObjectCategory = contactNode.physicsBody?.categoryBitMask {
            if hitObjectCategory == PhysicsBodyType.goalFrame.rawValue {
                textManager.showDebugMessage("HIT THE FRAME! SO CLOSE!!!")
            } else if hitObjectCategory == PhysicsBodyType.goalPlane.rawValue {
                // Collision has occurred, hit the confetti
                textManager.showDebugMessage("NICE SHOT!!!")
                if (showGoalConfetti) {
                    launchConfetti()
                }
            }
        }
    }
    
    // MARK: - Cheerview

    func launchConfetti() {
        DispatchQueue.main.async {
            self.cheerView.start()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.cheerView.stop()
        }
    }
    
    @IBOutlet weak var addObjectButton: UIButton!
	
	func loadVirtualObject(at index: Int) {
		resetVirtualObject()
		
		// Show progress indicator
		let spinner = UIActivityIndicatorView()
		spinner.center = addObjectButton.center
		spinner.bounds.size = CGSize(width: addObjectButton.bounds.width - 5, height: addObjectButton.bounds.height - 5)
		addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
		sceneView.addSubview(spinner)
		spinner.startAnimating()
		
		// Load the content asynchronously.
		DispatchQueue.global().async {
			self.isLoadingObject = true
			let object = VirtualObject.availableObjects[index]
			object.viewController = self
			self.virtualObject = object
            DispatchQueue.main.async {
                self.triggerButton.isHidden = false
                self.triggerIconImageView.isHidden = false
                if self.virtualObject is FieldGoal {
                    self.triggerIconImageView.image = #imageLiteral(resourceName: "footballLaunch")
                } else if self.virtualObject is SoccerGoal {
                    self.triggerIconImageView.image = #imageLiteral(resourceName: "soccerBallLaunch")
                }
            }
            
			object.loadModel()
			
			DispatchQueue.main.async {
				// Immediately place the object in 3D space.
				if let lastFocusSquarePos = self.focusSquare?.lastPosition {
					self.setNewVirtualObjectPosition(lastFocusSquarePos)
				} else {
					self.setNewVirtualObjectPosition(SCNVector3Zero)
				}
				
				// Remove progress indicator
				spinner.removeFromSuperview()
				
				// Update the icon of the add object button
				let buttonImage = UIImage.composeButtonImage(from: object.thumbImage)
				let pressedButtonImage = UIImage.composeButtonImage(from: object.thumbImage, alpha: 0.3)
				self.addObjectButton.setImage(buttonImage, for: [])
				self.addObjectButton.setImage(pressedButtonImage, for: [.highlighted])
				self.isLoadingObject = false
			}
		}
    }
	
	@IBAction func chooseObject(_ button: UIButton) {
		// Abort if we are about to load another object to avoid concurrent modifications of the scene.
		if isLoadingObject { return }
		
		textManager.cancelScheduledMessage(forType: .contentPlacement)
		
		let rowHeight = 45
		let popoverSize = CGSize(width: 250, height: rowHeight * VirtualObject.availableObjects.count)
		
		let objectViewController = VirtualObjectSelectionViewController(size: popoverSize)
		objectViewController.delegate = self
		objectViewController.modalPresentationStyle = .popover
		objectViewController.popoverPresentationController?.delegate = self
		self.present(objectViewController, animated: true, completion: nil)
		
		objectViewController.popoverPresentationController?.sourceView = button
		objectViewController.popoverPresentationController?.sourceRect = button.bounds
    }
	
	// MARK: - VirtualObjectSelectionViewControllerDelegate
	
	func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didSelectObjectAt index: Int) {
		loadVirtualObject(at: index)
	}
	
	func virtualObjectSelectionViewControllerDidDeselectObject(_: VirtualObjectSelectionViewController) {
		resetVirtualObject()
	}
	
    // MARK: - Planes
	
	var planes = [ARPlaneAnchor: Plane]()
	
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
		
		let pos = SCNVector3.positionFromTransform(anchor.transform)
		textManager.showDebugMessage("NEW SURFACE DETECTED AT \(pos.friendlyString())")
        
		let plane = Plane(anchor, showARPlanes, true, false)
		
		planes[anchor] = plane
		node.addChildNode(plane)
		
		textManager.cancelScheduledMessage(forType: .planeEstimation)
		textManager.showMessage("SURFACE DETECTED")
		if virtualObject == nil {
			textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
		}
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
		
		textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT",
		                            inSeconds: 7.5,
		                            messageType: .planeEstimation)
	}

    // MARK: - Focus Square
    var focusSquare: FocusSquare?
	
    func setupFocusSquare() {
		focusSquare?.isHidden = true
		focusSquare?.removeFromParentNode()
		focusSquare = FocusSquare()
		sceneView.scene.rootNode.addChildNode(focusSquare!)
		
		textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
    }
	
	func updateFocusSquare() {
		guard let screenCenter = screenCenter else { return }
		
		if virtualObject != nil && sceneView.isNode(virtualObject!, insideFrustumOf: sceneView.pointOfView!) {
			focusSquare?.hide()
		} else {
			focusSquare?.unhide()
		}
		let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
		if let worldPos = worldPos {
			focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
			textManager.cancelScheduledMessage(forType: .focusSquare)
		}
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
            planes.values.forEach { $0.showARPlaneVisualizations(showARPlanes, true, false) }
    
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
    
    var enableGoalDetection: Bool = UserDefaults.standard.bool(for: .enableGoalDetection) {
        didSet {
            self.restartExperience(self)
            // save pref
            UserDefaults.standard.set(enableGoalDetection, for: .enableGoalDetection)
        }
    }
    
    var showGoalConfetti: Bool = UserDefaults.standard.bool(for: .showGoalConfetti) {
        didSet {
            // save pref
            UserDefaults.standard.set(showGoalConfetti, for: .showGoalConfetti)
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
	
	var textManager: VirtualGoalTextManager!
	
    func setupUIControls() {
		textManager = VirtualGoalTextManager(viewController: self)
        
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
		
		guard restartExperienceButtonIsEnabled, !isLoadingObject else {
			return
		}
		
		DispatchQueue.main.async {
			self.restartExperienceButtonIsEnabled = false
			self.textManager.cancelAllScheduledMessages()
			self.textManager.dismissPresentedAlert()
			self.textManager.showMessage("STARTING A NEW SESSION")
			self.use3DOFTracking = false
			
			self.setupFocusSquare()
			self.resetVirtualObject()
			self.restartPlaneDetection()
			
			self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
			
            self.textManager.unblurBackground()

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
    
    // MARK: - Screen Recording (Not implemented yet)

    fileprivate let recorder = RPScreenRecorder.shared()
    
    @IBOutlet weak var screenRecordingLabel: UILabel!
    @IBOutlet weak var screenRecordButton: UIButton!
    @IBOutlet weak var stopRecordButton: UIButton!
    
    @IBAction func screenRecordButtonPressed(_ sender: UIButton) {
        // start recording
        recorder.startRecording(handler: { [unowned self] error in
            if let error = error {
                NSLog("Failed start recording: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async { [unowned self] in
                self.screenRecordButton.isHidden = true
                self.stopRecordButton.isHidden = false
                self.screenRecordingLabel.isHidden = false
            }
            NSLog("Start recording")
            
        })
    }
    
    @IBAction func stopRecordButtonPressed(_ sender: Any) {
        // end recording
        recorder.stopRecording(handler: { [unowned self] (previewViewController, error) in
            if let error = error {
                NSLog("Failed stop recording: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self.screenRecordButton.isHidden = false
                self.stopRecordButton.isHidden = true
                self.screenRecordingLabel.isHidden = true
            }
            NSLog("Stop recording")
            
            previewViewController?.previewControllerDelegate = self
            DispatchQueue.main.async { [unowned self] in
                // show preview window
                self.present(previewViewController!, animated: true, completion: nil)
            }
        })
    }
    
    
    // =========================================================================
    // MARK: - RPScreenRecorderDelegate
    
    // called after stopping the recording
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: Error, previewViewController: RPPreviewViewController?) {
        DispatchQueue.main.async { [unowned self] in
            self.screenRecordButton.setImage(UIImage(named: "startRecord"), for: .normal)
        }
        NSLog("Stop recording")
    }
    
    // called when the recorder availability has changed
    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        let availability = screenRecorder.isAvailable
        NSLog("Availablility: \(availability)")
    }
    
    
    // =========================================================================
    // MARK: - RPPreviewViewControllerDelegate
    
    // called when preview is finished
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        NSLog("Preview finish")
        
        DispatchQueue.main.async { [unowned previewController] in
            // close preview window
            previewController.dismiss(animated: true, completion: nil)
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
        enableGoalDetection = defaults.bool(for: .enableGoalDetection)
        showGoalConfetti = defaults.bool(for: .showGoalConfetti)

		dragOnInfinitePlanesEnabled = defaults.bool(for: .dragOnInfinitePlanes)
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

class TimedLongPressGesture: UILongPressGestureRecognizer {
    var startTime: NSDate?
}