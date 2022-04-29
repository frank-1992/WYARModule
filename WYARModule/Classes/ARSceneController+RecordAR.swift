//
//  ARSceneController+RecordAR.swift
//  XYARKit
//
//  Created by user on 4/8/22.
//

import UIKit
import ARKit
import SceneKit
import SCNRecorder
import Photos
import AVKit

@available(iOS 13.0, *)
public extension ARSceneController {
    func setupCameraUI() {
        view.addSubview(videoButton)
        videoButton.snp.makeConstraints { make in
            make.centerX.equalTo(view)
            make.bottom.equalTo(view).offset(-180)
            make.size.equalTo(CGSize(width: 48, height: 13))
        }
        
        view.addSubview(pictureButton)
        pictureButton.snp.makeConstraints { make in
            make.centerY.equalTo(videoButton)
            make.left.equalTo(videoButton.snp.right).offset(32)
            make.size.equalTo(CGSize(width: 32, height: 13))
        }
        
        let window = UIApplication.shared.keyWindow
        let bottomPadding = window?.safeAreaInsets.bottom ?? 0
        
        view.addSubview(cameraTabView)
        cameraTabView.snp.makeConstraints { make in
            make.centerX.equalTo(view)
            make.bottom.equalTo(view).offset(-34 - bottomPadding)
            make.size.equalTo(CGSize(width: 80, height: 80))
        }
    }
    
    func setupARRecord() {
        sceneView.prepareForRecording()
    }
    
//    @objc
//    func recordingAction(_ sender: UIButton) {
//        if sender.tag == 100 {
//            do {
//                let videoRecording = try sceneView.startVideoRecording()
//
//
//            } catch {
//
//            }
//            sender.setTitle("Stop", for: .normal)
//            sender.tag = 200
//        } else {
//            sceneView.finishVideoRecording { (videoRecording) in
//
//                DispatchQueue.global().async {
//                    let filePath = videoRecording.url.path
//                    let videoCompatible = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath)
//                    if videoCompatible {
//                        UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(self.didFinishSavingVideo(videoPath:error:contextInfo:)), nil)
//                    } else {
//                        print("该视频无法保存至相册")
//                    }
//                }
//
//                /* Process the captured video. Main thread. */
//                let controller = AVPlayerViewController()
//                controller.player = AVPlayer(url: videoRecording.url)
//                controller.modalPresentationStyle = .overFullScreen
//                self.present(controller, animated: true)
//            }
//            sender.setTitle("Start", for: .normal)
//            sender.tag = 100
//        }
//    }
//
//    @objc
//    func didFinishSavingVideo(videoPath: String, error: NSError?, contextInfo: UnsafeMutableRawPointer?) {
//        if error != nil{
//            print("保存失败")
//        }else{
//            print(videoPath)
//            print("保存成功，请到相册中查看")
//        }
//    }
    
    @objc
    func switchPictureMode() {
        UIView.animate(withDuration: 0.25) {
            self.pictureButton.transform = CGAffineTransform(translationX: -72, y: 0)
            self.videoButton.transform = CGAffineTransform(translationX: -72, y: 0)
            self.cameraTabView.currentCameraMode = .picture
        } completion: { _ in
            self.pictureButton.isSelected = true
            self.videoButton.isSelected = false
        }
    }
    
    @objc
    func switchVideoMode() {
        UIView.animate(withDuration: 0.25) {
            self.pictureButton.transform = CGAffineTransform.identity
            self.videoButton.transform = CGAffineTransform.identity
            self.cameraTabView.currentCameraMode = .video
        } completion: { _ in
            self.pictureButton.isSelected = false
            self.videoButton.isSelected = true
        }
    }
}

@available(iOS 13.0, *)
extension ARSceneController: CameraButtonViewDelegate {
    func startCaptureVideo() {
        videoButton.isHidden = true
        pictureButton.isHidden = true
        do {
            let videoRecording = try sceneView.startVideoRecording()
            videoRecording.$duration.observe(on: .main) { [weak self] duration in
                if duration < Capture.limitedTime {
                    self?.cameraTabView.timeLabel.text = String(format: "%.1f", duration)
                } else {
                    self?.stopCaptureVideo()
                }
            }
        } catch {
        }
    }
    
    func stopCaptureVideo() {
        videoButton.isHidden = false
        pictureButton.isHidden = false
        sceneView.finishVideoRecording { [weak self] videoRecording in
            self?.previewResult(with: .video(videoRecording.url))
        }
    }
    
    func takePhoto() {
        sceneView.takePhotoResult { [weak self] (result: Result<UIImage, Swift.Error>) in
            switch result {
            case .success(let image):
                self?.previewResult(with: .image(image))
            case .failure(let error):
                print(error)
            }
        }
    }
    
    private func previewResult(with resource: ARResultMediaType) {
        let controller = ARResultController(mediaType: resource)
        controller.model = self.model
        controller.modalPresentationStyle = .overFullScreen
        self.present(controller, animated: true)
    }
}
