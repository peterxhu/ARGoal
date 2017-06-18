//
//  FieldGoal.swift
//  ARGoal
//
//  Created by Peter Hu on 6/17/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import Foundation
import SceneKit

class FieldGoal: VirtualObject {
    
    override init() {
        super.init(modelName: "cup", fileExtension: "scn", thumbImageFilename: "fieldGoal", title: "Field Goal (TBD)")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
