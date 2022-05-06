//
//  ARLoadingView.swift
//  XYARKit
//
//  Created by user on 5/5/22.
//

import UIKit
import Lottie

class ARLoadingView: UIView {
    
    private lazy var animationView: AnimationView = {
        let animationView = AnimationView(name: "ar_loading", bundle: ARUtil.bundle)
        animationView.loopMode = .loop
        return animationView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.8)
        
        addSubview(animationView)
        animationView.frame = self.bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func playAnimation() {
        self.isHidden = false
        animationView.play()
    }
    
    func pauseAnimation() {
        animationView.pause()
        self.isHidden = true
    }
}
