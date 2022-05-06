//
//  CoachingOverlay.swift
//  XYARKit
//
//  Created by user on 4/7/22.
//

import UIKit
import ARKit

@available(iOS 13.0, *)
extension ARSceneController: ARCoachingOverlayViewDelegate {
    
    public func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        if !isDownloading {
            planDetectionView.playAnimation()
            planDetectionView.isHidden = false
        }
    }
    
    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        planDetectionView.pauseAnimation()
        planDetectionView.isHidden = true
    }

    // StartOver
    public func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        // restartExperience()
    }

    func setupCoachingOverlay() {
        coachingOverlay.session = sceneView.session
        coachingOverlay.delegate = self
        
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(coachingOverlay)
        coachingOverlay.alpha = 0
        
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.goal = .horizontalPlane
    }
}

