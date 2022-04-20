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
                self?.saveVideosToAlbum(videoPath: filePath)
            }
            sender.setTitle("Start", for: .normal)
            sender.tag = 100
        }
    }
    
    // MARK: - start take photo
    @objc
    func takePhotoAction(_ sender: UIButton) {
        sceneView.takePhotoResult { [weak self] (result: Result<UIImage, Swift.Error>) in
            switch result {
            case .success(let image):
                self?.saveImagesToAlbum(image: image)
            case .failure(let error):
                print(error)
            }
        }
    }
    
    // MARK: - save video to album successfully
    @objc
    func didFinishSavingVideo(videoPath: String, error: NSError?, contextInfo: UnsafeMutableRawPointer) {
        if error != nil {
            print("视频保存失败")
        } else {
            print("视频保存成功")
            self.timeLabel.text = "00:00"
        }
    }
    
    // MARK: - save image to album successfully
    @objc
    private func didFinishSavingImage(image: UIImage, error: NSError?, contextInfo: UnsafeMutableRawPointer) {
        if error != nil {
            print("照片保存失败")
        } else {
            print("照片保存成功")
        }
    }
    
    // MARK: - save videos to album
    private func saveVideosToAlbum(videoPath: String) {
        DispatchQueue.global().async {
            let videoCompatible = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoPath)
            if videoCompatible {
                UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, #selector(self.didFinishSavingVideo(videoPath:error:contextInfo:)), nil)
            } else {
                print("该文件无法保存至相册")
            }
        }
    }
    
    // MARK: - save photos to album
    private func saveImagesToAlbum(image: UIImage) {
        DispatchQueue.global().async {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.didFinishSavingImage(image:error:contextInfo:)), nil)
        }
    }
}

