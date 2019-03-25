//
//  MediaComposeViewController.swift
//  Dubbing
//
//  Created by blurryssky on 2019/3/20.
//  Copyright © 2019 blurryssky. All rights reserved.
//

import UIKit
import AVKit

import RxSwift
import RxCocoa
import SnapKit

class MediaComposeViewController: UIViewController {

    var videoAsset: AVAsset!
    
    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var constraintPlayerViewHeight: NSLayoutConstraint!
    @IBOutlet weak var playImgView: UIImageView!
    @IBOutlet weak var videoDurationLabel: UILabel!
    
    private let viewModel = MediaComposeViewModel()
    private var playerLayer: AVPlayerLayer!
    private var periodicObserver: Any?
    private var boundryObserver: Any?
    private var playControlObservation: NSKeyValueObservation?
    
    private let videoControlView = VideoControlView.bs.instantiateFromNib
    
    private let bag = DisposeBag()
    
    deinit {
        playControlObservation?.invalidate()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setup()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer?.frame = playerView.bounds
        CATransaction.commit()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        playerLayer?.player?.pause()
        AVAudioSession.bs.setAudioSession(category: .playback)
    }
}

private extension MediaComposeViewController {
    
    func setup() {
        setupViewModel()
        setupCloseBarButtonItem()
        setupPlayerView()
        setupPlayer()
        setupVideoEditView()
    }
    
    func setupViewModel() {
        viewModel.videoAsset = videoAsset
    }
    
    func setupCloseBarButtonItem() {
        closeBarButtonItem.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.dismiss(animated: true, completion: nil)
            })
            .disposed(by: bag)
    }
}

// MARK : - 播放器区域
private extension MediaComposeViewController {
    
    func setupPlayerView() {
        
        constraintPlayerViewHeight.constant = viewModel.playerViewHeightWithWidth(playerView.bs.width)
        
        viewModel.durationTextVariable.asObservable()
            .bind(to: videoDurationLabel.rx.text)
            .disposed(by: bag)

        let tap = UITapGestureRecognizer()
        tap.rx.event
            .subscribe(onNext: { [unowned self] (_) in
                self.viewModel.handlePlayerViewTap()
            })
            .disposed(by: bag)
        playerView.addGestureRecognizer(tap)
        
        viewModel.isPlayVariable.asObservable()
            .map { $0 ? #imageLiteral(resourceName: "ev_pause") : #imageLiteral(resourceName: "ev_play") }
            .bind(to: playImgView.rx.image)
            .disposed(by: bag)
    }
    
    var player: AVPlayer? {
        return playerLayer.player
    }
    
    func setupPlayer() {
        
        viewModel.playerItemVariable.asObservable()
            .subscribe(onNext: { [unowned self] (playerItem) in
                if self.playerLayer == nil {
                    let player = AVPlayer(playerItem: playerItem)
                    self.playerLayer = AVPlayerLayer(player: player)
                    self.playerView.layer.insertSublayer(self.playerLayer, at: 0)
                } else if let player = self.player {
                    player.replaceCurrentItem(with: playerItem)
                }
            })
            .disposed(by: bag)
        
        viewModel.isPlayVariable.asObservable()
            .subscribe(onNext: { [unowned self] (isPlay) in
                if isPlay {
                    AVAudioSession.bs.setAudioSession(category: .playback)
                    self.player?.play()
                } else {
                    self.player?.pause()
                }
            })
            .disposed(by: bag)
        
        Observable.merge([viewModel.previewProgressVariable.asObservable(), viewModel.playProgressVariable.asObservable()])
            .filter { [unowned self] _ in
                !self.viewModel.isPlayVariable.value
            }
            .subscribe(onNext: { [unowned self] (progress) in
                let timeSeconds = self.viewModel.videoDuration * progress
                let time = CMTime(seconds: timeSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                let tolerance = CMTime.zero
                self.player?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
            })
            .disposed(by: bag)
        
        viewModel.endBoundaryObservable
            .subscribe(onNext: { [unowned self] (endTimeValue) in
                if let observer = self.boundryObserver {
                    self.player?.removeTimeObserver(observer)
                    self.boundryObserver = nil
                }

                self.boundryObserver = self.player?.addBoundaryTimeObserver(forTimes: [endTimeValue], queue: nil, using: { [weak self] in
                    guard let `self` = self else { return }
                    self.viewModel.endPlayAndRecord()
                })
            })
            .disposed(by: bag)
        
        addPlayerObservation()
    }
    
    func addPlayerObservation() {
        playControlObservation = player?.observe(\.timeControlStatus) { [weak self] (player, change) in
            guard let `self` = self else {
                return
            }
            DispatchQueue.main.async(execute: {
                switch player.timeControlStatus {
                case .playing:
                    self.addPeriodicTimeObserver()
                case .paused:
                    self.removePeriodicTimeObserver()
                case .waitingToPlayAtSpecifiedRate:
                    return
                }
            })
        }
    }
    
    func addPeriodicTimeObserver() {
        removePeriodicTimeObserver()
        let interval = CMTime(value: CMTimeValue(1), timescale: CMTimeScale(NSEC_PER_SEC))
        periodicObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] (time) in
            guard let `self` = self,
                self.player?.timeControlStatus == .playing else { // 暂停后可能会回调一次
                    return
            }
            self.viewModel.updatePlayProgressByPlayerWithTime(time.seconds)
        }
    }
    
    func removePeriodicTimeObserver() {
        guard let observer = periodicObserver else {
            return
        }
        player?.removeTimeObserver(observer)
        periodicObserver = nil
    }
    
}

// MARK : - 音视频编辑区域
private extension MediaComposeViewController {
    
    func setupVideoEditView() {
        
        videoControlView.viewModel = viewModel
        view.addSubview(videoControlView)
        videoControlView.snp.makeConstraints { (maker) in
            maker.top.equalTo(playerView.snp.bottom)
            maker.left.equalToSuperview()
            maker.right.equalToSuperview()
            maker.bottom.equalToSuperview()
        }
    }
}
