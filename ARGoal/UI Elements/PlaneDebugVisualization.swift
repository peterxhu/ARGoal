/*
 Copyright © 2017 Apple Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
Abstract:
SceneKit node wrapper shows debug info for AR detected planes.
*/

import Foundation
import ARKit

class PlaneDebugVisualization: SCNNode {
	
	var planeAnchor: ARPlaneAnchor
	
	var planeGeometry: SCNPlane
	var planeNode: SCNNode
	
	init(anchor: ARPlaneAnchor) {
		
		self.planeAnchor = anchor
        // TODO: Toggle between grid and grass
        // let grid = UIImage(named: "Models.scnassets/plane_grid.png")
        // let grid = UIImage(named: "Models.scnassets/overlay_grid.png")
        let grid = UIImage(named: "Models.scnassets/grass.png")

		self.planeGeometry = createPlane(size: CGSize(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z)),
		                                 contents: grid)
		self.planeNode = SCNNode(geometry: planeGeometry)
		self.planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
		
		super.init()
		
		let originVisualizationNode = createAxesNode(quiverLength: 0.1, quiverThickness: 1.0)
		self.addChildNode(originVisualizationNode)
        
        self.planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: self.planeGeometry, options: nil))
        self.planeNode.physicsBody?.categoryBitMask =  PhysicsBodyType.plane.rawValue
		self.addChildNode(planeNode)
		
		self.position = SCNVector3(anchor.center.x, -0.002, anchor.center.z) // 2 mm below the origin of plane.
		
		adjustScale()
	}
	
	func update(_ anchor: ARPlaneAnchor) {
		self.planeAnchor = anchor
		
		self.planeGeometry.width = CGFloat(anchor.extent.x)
		self.planeGeometry.height = CGFloat(anchor.extent.z)
		
		self.position = SCNVector3Make(anchor.center.x, -0.002, anchor.center.z)
		
		adjustScale()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func adjustScale() {
		let scaledWidth: Float = Float(planeGeometry.width / 2.4)
		let scaledHeight: Float = Float(planeGeometry.height / 2.4)
		
		let offsetWidth: Float = -0.5 * (scaledWidth - 1)
		let offsetHeight: Float = -0.5 * (scaledHeight - 1)
		
		let material = self.planeGeometry.materials.first
		var transform = SCNMatrix4MakeScale(scaledWidth, scaledHeight, 1)
		transform = SCNMatrix4Translate(transform, offsetWidth, offsetHeight, 0)
		material?.diffuse.contentsTransform = transform
		
	}
}
