//
//  SoccerGoal.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import Foundation
import SceneKit

class SoccerGoal: VirtualObject, ReactsToScale {
    
    override init() {
        super.init(modelName: "candle", fileExtension: "scn", thumbImageFilename: "soccerGoal", title: "Soccer Net (TBD)")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reactToScale() {
        // Update the size of the flame
        let flameNode = self.childNode(withName: "flame", recursively: true)
        let particleSize: Float = 0.018
        flameNode?.particleSystems?.first?.reset()
        flameNode?.particleSystems?.first?.particleSize = CGFloat(self.scale.x * particleSize)
    }
}
