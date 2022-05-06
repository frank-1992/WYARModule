//
//  CoachingOverlayView.swift
//  XYARKit
//
//  Created by user on 5/5/22.
//

import UIKit
import Lottie

class PlanDetectionView: UIView {

    private lazy var animationView: AnimationView = {
        let animationView = AnimationView(name: "find_plane", bundle: ARUtil.bundle)
        animationView.loopMode = .autoReverse
        return animationView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        addSubview(animationView)
        animationView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            let scale = 2.19
            let width = 360.0
            let height = width / scale
            make.size.equalTo(CGSize(width: width, height: height))
        }
    }
    
    func playAnimation() {
        animationView.play()
    }
    
    func pauseAnimation() {
        animationView.pause()
    }
}
