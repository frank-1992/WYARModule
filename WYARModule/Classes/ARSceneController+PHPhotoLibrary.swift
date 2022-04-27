//
//  ARSceneController+Photo.swift
//  WYARModule
//
//  Created by user on 4/24/22.
//

import Photos
import XYPermission

@available(iOS 13.0, *)
extension ARSceneController: PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {

        guard let imageChanges = changeInstance.changeDetails(for: featchResult) else {
            return
        }

        DispatchQueue.main.async {
            // 获取最新的完整数据
            self.featchResult = imageChanges.fetchResultAfterChanges

            if !imageChanges.hasIncrementalChanges || imageChanges.hasMoves {
                return
            }

            // 照片新增情况
            guard let insertedIndexes = imageChanges.insertedIndexes,
                  let indexSet = insertedIndexes.first else {
                      return
                  }
            // 获取最后添加的图片资源
            let asset = self.featchResult[indexSet]
            self.showDetailViewControllerIfNeeded(asset)
        }
    }

    func showDetailViewControllerIfNeeded(_ asset: PHAsset) {
        if asset.mediaType == .image {
            let requestImageOption = PHImageRequestOptions()
            requestImageOption.deliveryMode = .highQualityFormat
            imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestImageOption) { (image: UIImage?, _) in
                self.showResultVC(with: .image(image))
            }
        } else if asset.mediaType == .video {
            let videoRequestOptions = PHVideoRequestOptions()
            videoRequestOptions.deliveryMode = .highQualityFormat
            videoRequestOptions.version = .original
            videoRequestOptions.isNetworkAccessAllowed = true
            imageManager.requestPlayerItem(forVideo: asset, options: videoRequestOptions, resultHandler: {
                result, _ in
                self.showResultVC(with: .video(result))
            })

        } else if asset.mediaType == .audio {
            // do anything for audio asset
        }
    }
    
    public func addApplicationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc
    public func willEnterForegroundNotification() {
        observePhoto()
    }

    @objc
    public func didEnterBackgroundNotification() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    public func observePhoto() {
        // 申请权限
        Permission.photos.request { status in
            if status != .authorized {
                return
            }

            // 启动后先获取目前所有照片资源
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            allPhotosOptions.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d",
                                                     PHAssetMediaType.image.rawValue,
                                                     PHAssetMediaType.video.rawValue)
            self.featchResult = PHAsset.fetchAssets(with: allPhotosOptions)

            // 监听资源改变
            PHPhotoLibrary.shared().register(self)
        }
    }
}

