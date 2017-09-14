//
//  UtilityMethods.swift
//  ARGoal
//
//  Created by Peter Hu on 6/24/17.
//  Copyright © 2017 App Doctor Hu. All rights reserved.
//

import Foundation
import UIKit

class UtilityMethods: NSObject {
    open class func showToolTip(for view: UIView, superview: UIView? = nil, text: String, position: EasyTipView.ArrowPosition = .top) -> EasyTipView? {
        guard (superview == nil || view.hasSuperview(superview!)) else {
            // Superview is not a direct or indirect superview
            // Use nil in this parameter or ensure the superview actually is one
            return nil
        }
        let superview = superview ?? UIApplication.shared.windows.first!
        var preferences = EasyTipView.globalPreferences
        preferences.drawing.foregroundColor = UIColor.white
        preferences.drawing.foregroundColor = UIColor.black
        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: -15)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -15)
        preferences.drawing.arrowPosition = position
        return EasyTipView.show(forView: view, withinSuperview: superview, text: text, preferences: preferences)
    }
    
    // E.g. ARGoal 1.0
    open class func appVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "ARGoal \(version)"
        } else {
            return ""
        }
    }
    
}

