//
//  UIView+Extensions.swift
//  ARGoal
//
//  Created by Peter Hu on 6/24/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import UIKit

public extension UIView {

    // returns true if view is related to superview either directly or indirectly
    func hasSuperview(_ superview: UIView) -> Bool{
        return viewHasSuperview(self, superview: superview)
    }
    
    fileprivate func viewHasSuperview(_ view: UIView, superview: UIView) -> Bool {
        if let sview = view.superview {
            if sview === superview {
                return true
            }else{
                return viewHasSuperview(sview, superview: superview)
            }
        } else{
            return false
        }
    }
}
