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
    func setupARRecord() {
        self.sceneView.prepareForRecording()
    }
    
    // MARK: - start record video
    @objc
    func recordingAction(_ sender: UIButton) {
        if sender.tag == 100 {
            do {
                let videoRecording = try sceneView.startVideoRecording()
                videoRecording.$duration.observe(on: .main) { [weak self] duration in
                    self?.timeLabel.text = String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60)
                }
            } catch {
                
            }
            sender.setTitle("Stop", for: .normal)
            sender.tag = 200
        } else {
            sceneView.finishVideoRecording { [weak self] videoRecording in
                let filePath = videoRecording.url.path
                self?.saveToAlbum(filePath: filePath)
            }
            sender.setTitle("Start", for: .normal)
            sender.tag = 100
        }
    }
    
    // MARK: - save videos to album successfully
    @objc
    func didFinishSavingVideo(videoPath: String, error: NSError?, contextInfo: UnsafeMutableRawPointer?) {
        if error != nil {
            print("保存失败")
        } else {
            self.timeLabel.text = "00:00"
        }
    }
    
    // MARK: - start take photo
    private func startTakePhoto() {
        sceneView.takePhotoResult { [weak self] (result: Result<UIImage, Swift.Error>) in
            
        }
    }
    
    // MARK: - save to album
    private func saveToAlbum(filePath: String) {
        DispatchQueue.global().async {
            let videoCompatible = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath)
            if videoCompatible {
                UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(self.didFinishSavingVideo(videoPath:error:contextInfo:)), nil)
            } else {
                print("该文件无法保存至相册")
            }
        }
    }
}

