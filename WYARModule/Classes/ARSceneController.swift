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

public enum FixValue {
    // set loaded object's scale
    static let originObjectScale: Float = 0.01
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
    
    /// the flag about place object
    private var canPlaceObject: Bool = false
    
    private var placedObjectOnPlane: Bool = false
    
    /// the latest screen touch position when a pan gesture is active
    private var lastPanTouchPosition: CGPoint?
    
    private lazy var startRecordButton: UIButton = {
        let button = UIButton()
        button.setTitle("Start", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.layer.cornerRadius = 40
        button.tag = 100
        button.addTarget(self, action: #selector(recordingAction(_:)), for: .touchUpInside)
//        button.addTarget(self, action: #selector(takePhotoAction(_:)), for: .touchUpInside)
        return button
    }()
    
    public lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.text = "00:00"
        return label
    }()
    
    private lazy var light: SCNLight = {
        let light = SCNLight()
        light.type = .directional
        return light
    }()
    
    // about assets (photo, video)
    public var featchResult = PHFetchResult<PHAsset>()

    public lazy var imageManager: PHCachingImageManager = {
        let imageManager = PHCachingImageManager()
        return imageManager
    }()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
//        setupCoachingOverlay()
        DispatchQueue.global().async {
            self.downloadUsdzFile()
        }
        addApplicationObservers()
        observePhoto()
        excuteImpression()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    public func present(with vc: UIViewController) {
        modalPresentationStyle = .fullScreen
        vc.present(self, animated: true, completion: nil)
    }
    
    private func downloadUsdzFile() {
        guard let parameter = parameter else {
            return
        }

        previewDataSource.downloadUsdzFile(with: parameter) { [weak self] result in
            switch result {
            case .success(let (url, model)):
                print(url)
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
    
    // MARK: - loadVirtualObject
//    private func loadVirtualObject(with sourceName: String) {
//        let virtualObject = VirtualObject(resourceName: sourceName)
//        self.loadedVirtualObject = virtualObject
//        print("模型加载成功")
//        addGestures()
//    }
    
    private func loadVirtualObject(with url: URL) {
        let virtualObject = VirtualObject(url: url)
        loadedVirtualObject = virtualObject
        print("模型加载成功")
        addGestures()
        
        displayVirtualObject()
    }
    
    // MARK: - setup ARSceneView
    private func setupSceneView() {
        view.backgroundColor = .white
        view.addSubview(sceneView)
        
        // light for scene
        addLight()
        
        // tap to place object
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showVirtualObject(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // add record buttons
        view.addSubview(startRecordButton)
        startRecordButton.snp.makeConstraints { make in
            make.centerX.equalTo(view)
            make.bottom.equalTo(view).offset(-50)
            make.size.equalTo(CGSize(width: 80, height: 80))
        }
        
        // about video record
        setupARRecord()

        // show record time
        showRecordTime()
    }
    
    // MARK: - record time
    func showRecordTime() {
        view.addSubview(timeLabel)
        timeLabel.snp.makeConstraints { make in
            make.bottom.equalTo(startRecordButton.snp.top).offset(-6)
            make.centerX.equalTo(startRecordButton)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
    }
    
    // MARK: - display virtual object
    private func displayVirtualObject() {
        guard let virtualObject = loadedVirtualObject else {
            return
        }
        sceneView.scene.rootNode.addChildNode(virtualObject)
        virtualObject.scale = SCNVector3(FixValue.originObjectScale, FixValue.originObjectScale, FixValue.originObjectScale)
        virtualObject.simdWorldPosition = simd_float3(x: 0, y: -1, z: -2)
        placedObject = virtualObject
    }
    
    
    // MARK: - add light to scene
    private func addLight() {
        let light = SCNLight()
        light.type = .directional
        light.shadowColor = UIColor.black.withAlphaComponent(0.2)
        light.shadowRadius = 5
        light.shadowSampleCount = 5
        light.castsShadow = true
        light.shadowMode = .forward

        let shadowLightNode = SCNNode()
        shadowLightNode.light = light
        /// - Tag: 此处取值为2的话会出现plane闪烁的问题,需要灯光有一定的斜角
        shadowLightNode.eulerAngles = SCNVector3(x: -.pi / (2 + FixValue.lightNodeAngleFix), y: 0, z: 0)
        sceneView.scene.rootNode.addChildNode(shadowLightNode)
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
            object.rotation.w = 0
            /// set position
            object.simdPosition = hitTestResult.worldTransform.translation
            /// set orientation
            object.simdOrientation = hitTestResult.worldTransform.orientation
            /// rotate the orientation for vertical plane, make the model looks normal
            if planeAnchor.alignment == .vertical {
                let orientation = object.orientation
                var glQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
                let multiplier = GLKQuaternionMakeWithAngleAndAxis(-.pi/2, 1, 0, 0)
                glQuaternion = GLKQuaternionMultiply(glQuaternion, multiplier)

                object.orientation = SCNQuaternion(x: glQuaternion.x, y: glQuaternion.y, z: glQuaternion.z, w: glQuaternion.w)
            }
        } else {
            // add virtual object
            guard let virtualObject = loadedVirtualObject else {
                return
            }
            
            sceneView.scene.rootNode.addChildNode(virtualObject)
            virtualObject.scale = SCNVector3(FixValue.originObjectScale, FixValue.originObjectScale, FixValue.originObjectScale)
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
                
                if placedObject.currentPlaneAlignment == .horizontal {
                    placedObject.rotation = SCNVector4(x: 0, y: 1, z: 0, w: placedObject.rotation.w + Float(translation.x / FixValue.objectRotationFix))
                } else {
                    // vertical rotate
                    let orientation = placedObject.orientation
                    var glQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
                    let multiplier = GLKQuaternionMakeWithAngleAndAxis(Float(translation.x / FixValue.objectRotationFix), 0, 0, 1)
                    glQuaternion = GLKQuaternionMultiply(glQuaternion, multiplier)

                    placedObject.orientation = SCNQuaternion(x: glQuaternion.x, y: glQuaternion.y, z: glQuaternion.z, w: glQuaternion.w)
                }
                
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
        }
        
        DispatchQueue.main.async {
            guard let placeObject = self.placedObject, self.placedObjectOnPlane == false else { return }
            let touchLocation = self.sceneView.screenCenter
            guard let hitTestResult = self.sceneView.smartHitTest(touchLocation) else { return }
            placeObject.simdWorldPosition = hitTestResult.worldTransform.translation
            self.placedObjectOnPlane = true
            
            // the object's location (whether horizontal plane or vertical plane)
            self.setupShadows(with: planeAnchor.alignment)
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
