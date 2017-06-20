//
//  SoccerGoal.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import Foundation
import SceneKit

class SoccerGoal: VirtualObject {
    
    override init() {
        super.init(modelName: "net", fileExtension: "scn", thumbImageFilename: "soccerGoal", title: "Soccer Net")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
