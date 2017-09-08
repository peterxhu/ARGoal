/*
 Copyright © 2017 Apple Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
Abstract:
Wrapper SceneKit node for virtual objects placed into the AR scene.
*/

import Foundation
import SceneKit
import ARKit

class VirtualObject: SCNNode {
	
	var modelName: String = ""
	var fileExtension: String = ""
	var thumbImage: UIImage!
	var title: String = ""
	var modelLoaded: Bool = false
	
	var viewController: VirtualGoalViewController?
	
	override init() {
		super.init()
		self.name = "Virtual object root node"
	}
	
	init(modelName: String, fileExtension: String, thumbImageFilename: String, title: String) {
		super.init()
		self.name = "Virtual object root node"
		self.modelName = modelName
		self.fileExtension = fileExtension
		self.thumbImage = UIImage(named: thumbImageFilename)
		self.title = title
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func loadModel() {
		guard let virtualObjectScene = SCNScene(named: "\(modelName).\(fileExtension)", inDirectory: "Models.scnassets/\(modelName)") else {
			return
		}
		
		let wrapperNode = SCNNode()
		
		for child in virtualObjectScene.rootNode.childNodes {
			child.geometry?.firstMaterial?.lightingModel = .physicallyBased
			child.movabilityHint = .movable
			wrapperNode.addChildNode(child)
		}
		self.addChildNode(wrapperNode)
		
		modelLoaded = true
	}
	
	func unloadModel() {
		for child in self.childNodes {
			child.removeFromParentNode()
		}
		
		modelLoaded = false
	}
	
	func translateBasedOnScreenPos(_ pos: CGPoint, instantly: Bool, infinitePlane: Bool) {
		
		guard let controller = viewController else {
			return
		}
		
		let result = controller.worldPositionFromScreenPosition(pos, objectPos: self.position, infinitePlane: infinitePlane)

		controller.moveVirtualObjectToPosition(result.position, instantly, !result.hitAPlane)
	}
}

extension VirtualObject {
	
	static func isNodePartOfVirtualObject(_ node: SCNNode) -> Bool {
		if node.name == "Virtual object root node" {
			return true
		}
		
		if node.parent != nil {
			return isNodePartOfVirtualObject(node.parent!)
		}
		
		return false
	}
	
	static let availableObjects: [VirtualObject] = [
        SoccerGoal(),
        FieldGoal()]
}

// MARK: - Protocols for Virtual Objects

protocol ReactsToScale {
	func reactToScale()
}

extension SCNNode {
	
	func reactsToScale() -> ReactsToScale? {
		if let canReact = self as? ReactsToScale {
			return canReact
		}
		
		if parent != nil {
			return parent!.reactsToScale()
		}
		
		return nil
	}
}
