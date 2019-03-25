//
//  ChooseMusicEditTableCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/4.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class MusicEditTableCell: UITableViewCell {
    
    var music: BackgroundMusicListResponse.Music! {
        didSet {
            update()
            updateLabel()
        }
    }
    
    var videoDuration: TimeInterval = 0
    
    var player: AVPlayer? {
        didSet {
            composeMusic()
            addPeriodicTimeObserver()
        }
    }
    
    @IBOutlet weak var unplayAudioImgView: UIImageView!
    @IBOutlet weak var playingAudioImgView: UIImageView!
    
    @IBOutlet weak var slider: DoubleSideSlider! {
        didSet {
            slider.minimumThumbImage = #imageLiteral(resourceName: "cm_slider_pink_left")
            slider.maximumThumbImage = #imageLiteral(resourceName: "cm_slider_pink_right")
            slider.thumbExtendRespondsRadius = 15
            slider.minimunTrackTintColors = [UIColor.clear]
            slider.maximunTrackTintColors = [UIColor.clear]
            slider.outsideCoverColor = UIColor.clear
            slider.topBottomLineColor = #colorLiteral(red: 1, green: 0.06274509804, blue: 0.8470588235, alpha: 1)
            slider.minimumSpacingValue = 0.05
        }
    }
    @IBOutlet weak var leftTimeLabel: UILabel!
    @IBOutlet weak var rightTimeLabel: UILabel!
    
    fileprivate lazy var unplayGradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        return gradientLayer
    }()
    
    fileprivate lazy var playingGradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        return gradientLayer
    }()
    
    fileprivate let bag = DisposeBag()
    
    fileprivate var totalDuration: TimeInterval = 0
    fileprivate var periodicTimeObserver: Any?
    
    @IBOutlet weak var constraintLeftTimeLabelLeading: NSLayoutConstraint!
    @IBOutlet weak var constraintRightTimeLabelLeading: NSLayoutConstraint!
    
    deinit {
        print("\(description) deinit")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        unplayGradientLayer.frame = unplayAudioImgView.bounds
        playingGradientLayer.frame = playingAudioImgView.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        removePeriodicTimeObserver()
    }
}

private extension MusicEditTableCell {
    
    func setup() {
        
        unplayAudioImgView.layer.mask = unplayGradientLayer
        unplayAudioImgView.image = #imageLiteral(resourceName: "ev_audio").withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        
        playingAudioImgView.layer.mask = playingGradientLayer
        playingAudioImgView.image = #imageLiteral(resourceName: "ev_audio").withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        
        updateMaskLayer(0)
        
        slider.rx.controlEvent(.touchDown)
            .subscribe(onNext: { [unowned self] (_) in
                self.player?.pause()
            })
            .disposed(by: bag)
        
        slider.rx.controlEvent([.touchUpInside, .touchUpOutside])
            .subscribe(onNext: { [unowned self] (_) in
                self.composeMusic()
            })
            .disposed(by: bag)
        
        slider.rx.minimumValue.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (leftValue) in
                self.updateMaskLayer(0)
                self.music.startValue = leftValue
                self.updateLabel(updateRight: false)
            })
            .disposed(by: bag)
        
        slider.rx.maximumValue.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (rightValue) in
                self.updateMaskLayer(0)
                self.music.endValue = rightValue
                self.updateLabel(updateLeft: false)
            })
            .disposed(by: bag)
    }
    
    func updateMaskLayer(_ value: CGFloat) {
        
        let fadeColor = UIColor.white.withAlphaComponent(0.1).cgColor
        let playingColor = #colorLiteral(red: 0.1960784314, green: 0.9568627451, blue: 0.9568627451, alpha: 1).cgColor
        let unplayColor = UIColor.white.cgColor
        let clearColor = UIColor.clear.cgColor
        
        var unplayColors: [CGColor] = []
        var unplayLocations: [NSNumber] = []
        
        var playingColors: [CGColor] = []
        var playingLocations: [NSNumber] = []
        
        let startNumber = NSNumber(value: Float(slider.minimumValue))
        
        // 0 ~ 1 -> minimumValue ~ maximumValue
        let playingNumber = NSNumber(value: Float(slider.minimumValue + value * (slider.maximumValue - slider.minimumValue)))
        let unplayNumber = NSNumber(value: Float(slider.maximumValue))
        
        // 0 -> 开始
        unplayColors.append(contentsOf: [fadeColor, fadeColor])
        unplayLocations.append(contentsOf: [NSNumber(value: 0), startNumber])
        
        playingColors.append(contentsOf: [clearColor, clearColor])
        playingLocations.append(contentsOf: [NSNumber(value: 0), startNumber])
        
        // 开始 -> 播放位置
        unplayColors.append(contentsOf: [clearColor, clearColor])
        unplayLocations.append(contentsOf: [startNumber, playingNumber])
        
        playingColors.append(contentsOf: [playingColor, playingColor])
        playingLocations.append(contentsOf: [startNumber, playingNumber])
        
        // 播放位置 -> 结束
        unplayColors.append(contentsOf: [unplayColor, unplayColor])
        unplayLocations.append(contentsOf: [playingNumber, unplayNumber])
        
        // 结束 -> 1
        unplayColors.append(contentsOf: [fadeColor, fadeColor])
        unplayLocations.append(contentsOf: [unplayNumber, NSNumber(value: 1)])
        
        playingColors.append(contentsOf: [clearColor, clearColor])
        playingLocations.append(contentsOf: [playingNumber, NSNumber(value: 1)])
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playingGradientLayer.colors = playingColors
        playingGradientLayer.locations = playingLocations
        
        unplayGradientLayer.colors = unplayColors
        unplayGradientLayer.locations = unplayLocations
        CATransaction.commit()
    }
}

private extension MusicEditTableCell {
    
    func update() {
        slider.minimumValue = music.startValue
        
        updateMaskLayer(0)
        
        if let fileUrl = music.fileUrl {
            let audioFileAsset = AVURLAsset(url: fileUrl)
            totalDuration = audioFileAsset.duration.seconds
            slider.maximumValue = CGFloat(videoDuration/totalDuration)
        } else {
            slider.maximumValue = music.endValue
        }
    }
    
    func updateLabel(updateLeft: Bool = true, updateRight: Bool = true) {
        
        if updateLeft {
            let leftTime = totalDuration * Double(slider.minimumValue)
            leftTimeLabel.ks.setFormattedColonTimeText(leftTime)
            constraintLeftTimeLabelLeading.constant = max(0, bounds.width * slider.minimumValue - leftTimeLabel.ks.width/2)
        }
        
        if updateRight {
            let rightTime = totalDuration * Double(slider.maximumValue)
            rightTimeLabel.ks.setFormattedColonTimeText(rightTime)
            let width = bounds.width
            constraintRightTimeLabelLeading.constant = min(width - rightTimeLabel.ks.width, width * slider.maximumValue - rightTimeLabel.ks.width/2)
        }
    }
    
    func addPeriodicTimeObserver() {
        let interval = CMTime(value: CMTimeValue(1), timescale: CMTimeScale(NSEC_PER_SEC))
        periodicTimeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] (time) in
            guard let `self` = self,
                self.player?.timeControlStatus == .playing else { // 暂停后可能会回调一次
                    return
            }
            let seconds = time.seconds
            if let duration = self.player?.currentItem?.duration.seconds {
                let value = CGFloat(seconds/duration)
                self.updateMaskLayer(value)
            }
        }
    }
    
    func removePeriodicTimeObserver() {
        guard let observer = periodicTimeObserver else {
            return
        }
        player?.removeTimeObserver(observer)
        periodicTimeObserver = nil
    }
    
    func composeMusic() {
        guard let fileUrl = music.fileUrl else {
            return
        }
        let audioFileAsset = AVURLAsset(url: fileUrl)
        let startTime = totalDuration * Double(slider.minimumValue)
        let endTime = totalDuration * Double(slider.maximumValue)
        let composition = EditAudioManager.createEditComposition(fileAsset: audioFileAsset, startTime: startTime, endTime: endTime)
        let playerItem = AVPlayerItem(asset: composition)
        player?.replaceCurrentItem(with: playerItem)
        player?.play()
    }
}

