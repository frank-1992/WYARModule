//
//  ARResultController.swift
//  WYARModule
//
//  Created by user on 4/19/22.
//

import UIKit
import AVKit
import SnapKit
import XYUITheme
import XYRouter
import XYAnalytics
import XYAlertCenter

enum ARResultMediaType {
    case none
    case image(UIImage?)
    case video(URL?)
}

final class ARResultController: UIViewController {

    public var model: AR3DModel?

    public var mediaType: ARResultMediaType = .none

    init(mediaType: ARResultMediaType) {
        super.init(nibName: nil, bundle: nil)
        self.mediaType = mediaType
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var backButton: UIButton = {
        let backButton = UIButton()
        backButton.setImage(Theme.icon.back_center_b.size(24).color(Theme.color.whitePatch1).image, for: .normal)
        backButton.layer.zPosition = 1000
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        return backButton
    }()
    
    private lazy var saveButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "save", in: ARUtil.bundle, compatibleWith: nil), for: .normal)
        button.addTarget(self, action: #selector(saveButtonClicked), for: .touchUpInside)
        return button
    }()

    private lazy var publishButton: UIButton = {
        let publishButton = UIButton()
        publishButton.backgroundColor = Theme.color.red
        publishButton.layer.cornerRadius = 24
        publishButton.setTitle("发布笔记", for: .normal)
        publishButton.layer.zPosition = 1000
        publishButton.translatesAutoresizingMaskIntoConstraints = false
        publishButton.addTarget(self, action: #selector(publishButtonClicked), for: .touchUpInside)
        publishButton.titleLabel?.font = Theme.fontXLarge
        return publishButton
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        definesPresentationContext = true

        switch mediaType {
        case .image(let image):
            imageView.image = image
            initImageView()
        case .video(let videoURL):
            NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.playBackIfNeeded()
            }
            guard let url = videoURL else { return }
            let playerItem = AVPlayerItem(url: url)
            initPlayer(with: playerItem)
        case .none:
            break
        }

        initSubviews()

        excuteImpression()
    }

    private func excuteImpression() {
        XYAnalyticsOrganizer._
            .page.pageInstance(.rnftPicturePreviewPage)
            .event.action(.pageview).pointId(11049)
            .send()
    }

    private func playBackIfNeeded() {
        if player == nil { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        playBackIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }

    private func initSubviews() {
        let statusHeight: CGFloat
        if #available(iOS 13.0, *) {
            statusHeight = UIApplication.shared.keyWindow?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        } else {
            // Fallback on earlier versions
            statusHeight = UIApplication.shared.statusBarFrame.height
        }

        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(10)
            make.top.equalTo(view.snp.top).offset(statusHeight + 10)
        }

        let bottomPadding: CGFloat
        if #available(iOS 11.0, *) {
            let window = UIApplication.shared.keyWindow
            bottomPadding = window?.safeAreaInsets.bottom ?? 0
        } else {
            bottomPadding = 0
        }

        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.left.equalTo(view).offset(20)
            make.bottom.equalTo(-34 - bottomPadding)
            make.size.equalTo(CGSize(width: 48, height: 48))
        }
        saveButton.setImage(UIImage(named: "save", in: ARUtil.bundle, compatibleWith: nil), for: .normal)

        
        view.addSubview(publishButton)
        publishButton.snp.makeConstraints { make in
            make.left.equalTo(saveButton.snp.right).offset(20)
            make.right.equalTo(view).offset(-20)
            make.height.equalTo(48)
            make.bottom.equalTo(-34 - bottomPadding)
        }
    }
    
    @objc
    private func saveButtonClicked() {
        saveMediaToAlbum()
    }

    @objc
    private func publishButtonClicked() {
        saveMediaToAlbum()
        
        if let model = model {
            JLRoutes.routeURL(URL(string: model.capaLink))

            XYAnalyticsOrganizer._
                .index.contentId(model.bizId)
                .page.pageInstance(.rnftPicturePreviewPage)
                .event.targetType(.noteComposeTarget).action(.click).pointId(11051)
                .send()
        }
    }
    
    private func saveMediaToAlbum() {
        switch mediaType {
        case .image(let image):
            DispatchQueue.global().async {
                guard let image = image else {
                    return
                }
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.didFinishSavingImage(_:error:contextInfo:)), nil)
            }
        case .video(let videoURL):
            DispatchQueue.global().async {
                guard let url = videoURL else {
                    return
                }
                let filePath = url.path
                let videoCompatible = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath)
                if videoCompatible {
                    UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(self.didFinishSavingVideo(videoPath:error:contextInfo:)), nil)
                } else {
                    self.showAlert(with: "该视频无法保存至相册")
                }
            }
        case .none:
            break
        }
    }
    
    @objc
    private func didFinishSavingVideo(videoPath: String, error: NSError?, contextInfo: UnsafeMutableRawPointer?) {
        if error != nil {
            showAlert(with: "保存失败")
        } else {
            showAlert(with: "保存成功")
        }
    }
    
    @objc
    func didFinishSavingImage(_ image: UIImage, error: NSError?, contextInfo: UnsafeMutableRawPointer?) {
        if let err = error {
            print(err)
            return
        }
        showAlert(with: "保存成功")
    }
    
    private func showAlert(with message: String) {
        let alert = XYAlert.createTextItemWithText(onMiddle: message)
        alert?.show()
    }
    
    

    func initImageView() {
        view.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func initPlayer(with playerItem: AVPlayerItem?) {
        guard let playerItem = playerItem else {
            return
        }
        let videoPlayer = AVQueuePlayer(playerItem: playerItem)
        videoPlayer.actionAtItemEnd = .none
        videoPlayer.rate = 1.0 // 播放速度 播放前设置
        self.player = videoPlayer

        playerLooper = AVPlayerLooper(player: videoPlayer, templateItem: playerItem)
        let playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
    }

    @objc
    func backButtonClicked() {
        dismiss(animated: false, completion: nil)

        XYAnalyticsOrganizer._
            .index.contentId(model?.bizId ?? "")
            .page.pageInstance(.rnftPicturePreviewPage)
            .event.action(.backToPrevious).pointId(11050)
            .send()
    }

}
