//
//  ARSceneController.swift
//  
//
//  Created by user on 4/6/22.
//

import UIKit
import SceneKit
import ARKit
import SCNRecorder
import AVKit
import XYAlertCenter
import Photos
import XYAnalytics
import XYUITheme

public enum CameraMode: CaseIterable {
    case picture
    case video
    
    var title: String {
        switch self {
        case .picture:
            return "拍照"
        case .video:
            return "拍视频"
        }
    }
}

public enum Capture {
    static let limitedTime: Double = 60.00
}

public enum FixValue {
    // solve the problem of plane flickering, the tilt angle is required
    static let lightNodeAngleFix: Float = 0.01
    // single pan gesture rotation sensitivity
    static let objectRotationFix: CGFloat = 100.0
    // correction of initial display model position relative to camera position Y
    static let cameraTranslationYFix: Float = 1.0
    // correction of initial display model position relative to camera position Z
    static let cameraTranslationZFix: Float = 2.0
}
@available(iOS 13.0, *)
public final class ARSceneController: UIViewController {
    
    // download usdz
    private lazy var previewDataSource: ARPreviewDataSource = {
        let previewDataSource = ARPreviewDataSource()
        return previewDataSource
    }()
    
    public var parameter: ARModuleServiceParameter?
    
    public var model: AR3DModel?

    public lazy var sceneView: ARView = {
        let sceneView = ARView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        return sceneView
    }()
    
    public lazy var session: ARSession = {
        return sceneView.session
    }()
    
    let coachingOverlay = ARCoachingOverlayView()
    
    private let updateQueue = DispatchQueue(label: "armodule.serialSceneKitQueue")
    
    /// about virtual object
    private var loadedVirtualObject: VirtualObject?
    private var placedObject: VirtualObject?
    public var isDownloading: Bool = false
    
    /// the flag about place object
    private var canPlaceObject: Bool = false
    
    private var placedObjectOnPlane: Bool = false
    
    /// the latest screen touch position when a pan gesture is active
    private var lastPanTouchPosition: CGPoint?
    
    // camera buttons UI
    private var currentCameraMode: CameraMode = .video

    lazy var videoButton: UIButton = {
        let button = UIButton()
        button.setTitle(CameraMode.video.title, for: .normal)
        button.setTitleColor(Theme.color.white.light().withAlphaComponent(0.5), for: .normal)
        button.setTitleColor(Theme.color.white.light(), for: .selected)
        button.titleLabel?.font = UIFont(name: "PingFang-SC-Medium", size: 16)
        button.isSelected = true
        button.addTarget(self, action: #selector(switchVideoMode), for: .touchUpInside)
        return button
    }()
    
    lazy var pictureButton: UIButton = {
        let button = UIButton()
        button.setTitle(CameraMode.picture.title, for: .normal)
        button.setTitleColor(Theme.color.white.light().withAlphaComponent(0.5), for: .normal)
        button.setTitleColor(Theme.color.white.light(), for: .selected)
        button.titleLabel?.font = UIFont(name: "PingFang-SC-Medium", size: 16)
        button.isSelected = false
        button.addTarget(self, action: #selector(switchPictureMode), for: .touchUpInside)
        return button
    }()
    
    lazy var cameraTabView: CameraButtonView = {
        let view = CameraButtonView(frame: .zero)
        view.delegate = self
        return view
    }()
    private lazy var backButton: UIButton = {
        let backButton = UIButton()
        backButton.setImage(Theme.icon.back_center_b.size(24).color(Theme.color.whitePatch1).image, for: .normal)
        backButton.layer.zPosition = 1000
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        return backButton
    }()
    
    private lazy var loadingView: ARLoadingView = {
        let view = ARLoadingView(frame: view.bounds)
        view.playAnimation()
        return view
    }()
    
    lazy var planDetectionView: PlanDetectionView = {
        let view = PlanDetectionView(frame: view.bounds)
        view.playAnimation()
        view.isHidden = true
        return view
    }()
    
    private lazy var rotateTipView: RotateTipView = {
        let view = RotateTipView(frame: view.bounds)
        view.playAnimation()
        return view
    }()
    
    @objc
    func backButtonClicked() {
        dismiss(animated: false, completion: nil)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupCoachingOverlay()
        view.addSubview(loadingView)
        view.addSubview(planDetectionView)
        
        DispatchQueue.global().async {
            self.downloadUsdzFile()
        }
        excuteImpression()
    }
    
    public func present(with vc: UIViewController) {
        modalPresentationStyle = .fullScreen
        vc.present(self, animated: true, completion: nil)
    }
    
    private func downloadUsdzFile() {
        isDownloading = true
        guard let parameter = parameter else {
            return
        }

        previewDataSource.downloadUsdzFile(with: parameter) { [weak self] result in
            self?.isDownloading = false
            self?.loadingView.pauseAnimation()
            switch result {
            case .success(let (url, model)):
                self?.model = model
                self?.loadVirtualObject(with: url)
            case .failure(let error):
                XYAlert.createTextItemWithText(onMiddle: "下载失败，请稍后重试")?.show()
                print(error)
            }
        }
    }
    
    private func excuteImpression() {
        XYAnalyticsOrganizer._
            .index.contentId(model?.bizId ?? "")
            .page.pageInstance(.rnftCameraShootPage)
            .event.action(.pageview).pointId(11048)
            .send()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTracking()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - show the capture result
    func showResultVC(with mediaType: ARResultMediaType) {
        let resultVC = ARResultController(mediaType: mediaType)
        resultVC.model = model
        resultVC.modalPresentationStyle = .custom
        present(resultVC, animated: false, completion: nil)
    }
    
    func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
       
        // add people occlusion
        // WARNING: - CPU High
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else {
            fatalError("People occlusion is not supported on this device.")
        }
        switch configuration.frameSemantics {
        case [.personSegmentationWithDepth]:
            configuration.frameSemantics.remove(.personSegmentationWithDepth)
        default:
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func loadVirtualObject(with url: URL) {
        let virtualObject = VirtualObject(url: url)
        loadedVirtualObject = virtualObject
        addGestures()
        displayVirtualObject()
        // custom coachingoverlay
        planDetectionView.isHidden = false
    }
    
    // MARK: - setup ARSceneView
    private func setupSceneView() {
        let statusHeight = UIApplication.shared.keyWindow?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        
        view.backgroundColor = .white
        view.addSubview(sceneView)
        
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(10)
            make.top.equalTo(view.snp.top).offset(statusHeight + 10)
        }

        // tap to place object
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showVirtualObject(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // about video record
        setupARRecord()
        setupCameraUI()
    }
    
    // MARK: - display virtual object
    private func displayVirtualObject() {
        guard let virtualObject = loadedVirtualObject else {
            return
        }
        // setup standard height and scale
        let boundingBox = virtualObject.boundingBox
        let height = boundingBox.max.y - boundingBox.min.y
        let standardHeight: Float = 1.0
        let scale = standardHeight / height
        sceneView.scene.rootNode.addChildNode(virtualObject)
        virtualObject.simdScale = simd_float3(x: scale, y: scale, z: scale)
        virtualObject.simdWorldPosition = simd_float3(x: 0, y: -1, z: -2)
        placedObject = virtualObject
    }
    
    @objc
    private func showVirtualObject(_ gesture: UITapGestureRecognizer) {
        guard canPlaceObject else { return }
        let touchLocation = gesture.location(in: sceneView)
        guard let hitTestResult = sceneView.smartHitTest(touchLocation),
              let planeAnchor = hitTestResult.anchor as? ARPlaneAnchor  else { return }
        setupShadows(with: planeAnchor.alignment)
        if let object = placedObject {
            /// reset rotation
            object.simdRotation.w = 0
            /// set position
            object.simdWorldPosition = hitTestResult.worldTransform.translation
            /// set orientation
            object.simdOrientation = hitTestResult.worldTransform.orientation
            /// rotate the orientation for vertical plane, make the model looks normal
            if planeAnchor.alignment == .vertical {
                let orientation = object.orientation
                var glQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
                let multiplier = GLKQuaternionMakeWithAngleAndAxis(-.pi / 2, 1, 0, 0)
                glQuaternion = GLKQuaternionMultiply(glQuaternion, multiplier)

                object.orientation = SCNQuaternion(x: glQuaternion.x, y: glQuaternion.y, z: glQuaternion.z, w: glQuaternion.w)
            }
        } else {
            // add virtual object
            guard let virtualObject = loadedVirtualObject else {
                return
            }
            
            sceneView.scene.rootNode.addChildNode(virtualObject)
            virtualObject.simdWorldPosition = hitTestResult.worldTransform.translation
            placedObject = virtualObject
            
            virtualObject.shouldUpdateAnchor = true
            if virtualObject.shouldUpdateAnchor {
                virtualObject.shouldUpdateAnchor = false
                self.updateQueue.async {
                    self.sceneView.addOrUpdateAnchor(for: virtualObject)
                }
            }
        }
    }
    
    // MARK: - add gestures
    private func addGestures() {
        // pan and rotate
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        // scale
        let scaleGesture = UIPinchGestureRecognizer(target: self, action: #selector(didScale(_:)))
        sceneView.addGestureRecognizer(scaleGesture)
    }
    
    @objc
    func didPan(_ gesture: UIPanGestureRecognizer) {
        guard placedObject != nil else { return }
        switch gesture.state {
        case .changed:
            if let object = objectInteracting(with: gesture, in: sceneView) {

                let translation = gesture.translation(in: sceneView)
                let previousPosition = lastPanTouchPosition ?? CGPoint(sceneView.projectPoint(object.position))
                // calculate the new touch position
                let currentPosition = CGPoint(x: previousPosition.x + translation.x, y: previousPosition.y + translation.y)
                if let hitTestResult = sceneView.smartHitTest(currentPosition),
                   let planeAnchor = hitTestResult.anchor as? ARPlaneAnchor {
                    
                    setupShadows(with: planeAnchor.alignment)

                    object.simdPosition = hitTestResult.worldTransform.translation
                    
                    object.shouldUpdateAnchor = true
                    if object.shouldUpdateAnchor {
                        object.shouldUpdateAnchor = false
                        self.updateQueue.async {
                            self.sceneView.addOrUpdateAnchor(for: object)
                        }
                    }
                }
                lastPanTouchPosition = currentPosition
                // reset the gesture's translation
                gesture.setTranslation(.zero, in: sceneView)
            } else {
                // rotate
                let translation = gesture.translation(in: sceneView)
                guard let placedObject = placedObject else {
                    return
                }
                
                if placedObject.currentPlaneAlignment == .vertical {
                    // vertical rotate
                    let orientation = placedObject.orientation
                    var glQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
                    let multiplier = GLKQuaternionMakeWithAngleAndAxis(Float(translation.x / FixValue.objectRotationFix), 0, 0, 1)
                    glQuaternion = GLKQuaternionMultiply(glQuaternion, multiplier)

                    placedObject.orientation = SCNQuaternion(x: glQuaternion.x, y: glQuaternion.y, z: glQuaternion.z, w: glQuaternion.w)
                } else {
                    placedObject.simdRotation = simd_float4(x: 0, y: 1, z: 0, w: placedObject.simdRotation.w + Float(translation.x / FixValue.objectRotationFix))
                }
                
                // hide rotate tip
                rotateTipView.isHidden = true
                
                placedObject.shouldUpdateAnchor = true
                if placedObject.shouldUpdateAnchor {
                    placedObject.shouldUpdateAnchor = false
                    self.updateQueue.async {
                        self.sceneView.addOrUpdateAnchor(for: placedObject)
                    }
                }
                gesture.setTranslation(.zero, in: sceneView)
            }
        default:
            // clear the current position tracking.
            lastPanTouchPosition = nil
        }
    }
    
    @objc
    private func didScale(_ gesture: UIPinchGestureRecognizer) {
        guard let object = placedObject, gesture.state == .changed
            else { return }
        let newScale = object.simdScale * Float(gesture.scale)
        object.simdScale = newScale
        gesture.scale = 1.0
    }
    
    private func objectInteracting(with gesture: UIGestureRecognizer, in view: ARSCNView) -> VirtualObject? {
        for index in 0..<gesture.numberOfTouches {
            let touchLocation = gesture.location(ofTouch: index, in: view)
            
            if let object = sceneView.virtualObject(at: touchLocation) {
                return object
            }
        }
        
        if let center = gesture.center(in: view) {
            return sceneView.virtualObject(at: center)
        }
        return nil
    }
    
    private func setupShadows(with alignment: ARPlaneAnchor.Alignment) {
        if alignment == .horizontal {
            placedObject?.currentPlaneAlignment = .horizontal
        } else {
            placedObject?.currentPlaneAlignment = .vertical
        }
    }
}

@available(iOS 13.0, *)
// MARK: - ARSCNViewDelegate
extension ARSceneController: ARSCNViewDelegate {
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        guard let placeObject = placedObject, let pointOfView = sceneView.pointOfView else { return }
//        if let virtualNode = renderer.nodesInsideFrustum(of: pointOfView).first {
//            if placeObject.simdWorldPosition == virtualNode.simdWorldPosition {
//                print("找到")
//
//            } else {
//
//
//            }
//        } else {
//
//        }
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // add plane
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        if planeAnchor.alignment == .horizontal {
            canPlaceObject = true
            DispatchQueue.main.async {
                self.planDetectionView.isHidden = true
                
                guard let placeObject = self.placedObject, self.placedObjectOnPlane == false else { return }
                let touchLocation = self.sceneView.screenCenter
                guard let hitTestResult = self.sceneView.smartHitTest(touchLocation) else { return }
                placeObject.simdWorldPosition = hitTestResult.worldTransform.translation
                self.placedObjectOnPlane = true
                
                // the object's location (whether horizontal plane or vertical plane)
                self.setupShadows(with: planeAnchor.alignment)
                
                // show the rotate tip
                if !UserDefaults.hasShowTheRotateTip {
                    self.view.addSubview(self.rotateTipView)
                    UserDefaults.hasShowTheRotateTip = true
                }
            }
        }
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    }
}

// MARK: - ARSessionDelegate
@available(iOS 13.0, *)
extension ARSceneController: ARSessionDelegate {
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .limited(.initializing):
            print("初始化")
        case .limited(.excessiveMotion):
            print("过度移动")
        case .limited(.insufficientFeatures):
            print("缺少特征点")
        case .limited(.relocalizing):
            print("再次本地化")
        case .limited(_):
            print("未知原因")
        case .notAvailable:
            print("Tracking不可用")
        case .normal:
            print("正常")
    
        }
    }
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // load then show the model right away
//        let transform = frame.camera.transform
//        guard let placeObject = self.placedObject, self.placedObjectOnPlane == false else { return }
//        placeObject.simdWorldPosition = simd_float3(x: transform.translation.x, y: transform.translation.y - FixValue.cameraTranslationYFix, z: -FixValue.cameraTranslationZFix)
        
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        // Hide content before going into the background.
        
    }
    
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}
