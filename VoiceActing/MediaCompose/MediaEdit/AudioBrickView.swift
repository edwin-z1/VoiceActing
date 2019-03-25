//
//  AudioBrickView.swift
//  Kuso
//
//  Created by blurryssky on 2018/10/31.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class AudioBrickView: UIView {
    
    var videoBrick: MediaBrick!
    var audioBrick: MediaBrick! {
        didSet {
            update()
        }
    }

    @IBOutlet weak var darkColorView: UIView!
    @IBOutlet weak var lightColorView: UIView!
    @IBOutlet weak var waterImgView: UIImageView! {
        didSet {
            waterImgView.image = #imageLiteral(resourceName: "ev_color_water").withRenderingMode(.alwaysTemplate)
        }
    }
    @IBOutlet weak var waterFrameImgView: UIImageView!
    @IBOutlet weak var iconImgView: UIImageView!
    @IBOutlet weak var editBgView: UIView!
    lazy var editView: MediaEditComponentView = {
        let view = MediaEditComponentView.ks.instantiateFromNib
        return view
    }()
    
    fileprivate lazy var audioInputReplicatorLayer: CAReplicatorLayer = {
        let inputLayer = CAReplicatorLayer()
        let inputImg = #imageLiteral(resourceName: "ev_audio")
        inputLayer.instanceTransform = CATransform3DMakeTranslation(inputImg.size.width + 4, 0, 0)
        inputLayer.masksToBounds = true
        inputLayer.addSublayer(audioInputLayer)
        return inputLayer
    }()
    fileprivate lazy var audioInputLayer: CALayer = {
        let layer = CALayer()
        let inputImg = #imageLiteral(resourceName: "ev_audio")
        layer.frame = CGRect(origin: .zero, size: inputImg.size)
        layer.contents = inputImg.cgImage
        layer.contentsScale = UIScreen.main.scale
        layer.contentsGravity = "left"
        return layer
    }()
    
    @IBOutlet weak var constraintDarkColorViewHeight: NSLayoutConstraint!
    @IBOutlet weak var constraintLightColorViewHeight: NSLayoutConstraint!

    fileprivate let bag = DisposeBag()
    
    deinit {
        print("\(description) deinit")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        
        let editRect = editBgView.frame
        let rightBottomRect = CGRect(x: waterImgView.ks.width, y: waterImgView.ks.origin.y,
                                   width: ks.width - waterImgView.ks.width, height: waterImgView.ks.height)
        
        if audioBrick.isFoldVariable.value {
            if editRect.contains(point) || rightBottomRect.contains(point) {
                return false
            } else {
                return super.point(inside: point, with: event)
            }
        } else {
            
            if rightBottomRect.contains(point) {
                return false
            } else {
                return super.point(inside: point, with: event)
            }
        }
    }
}

private extension AudioBrickView {
    
    func setup() {
        let tap = UITapGestureRecognizer()
        tap.rx.event
            .subscribe(onNext: { [unowned self] (tap) in
                self.audioBrick.isSelectedVariable.value = !self.audioBrick.isSelectedVariable.value
            })
            .disposed(by: bag)
        addGestureRecognizer(tap)
        
        let centerPan = UIPanGestureRecognizer()
        centerPan.rx.event
            .subscribe(onNext: { [unowned self] (centerPan) in
                
                if !self.audioBrick.isSelectedVariable.value {
                    self.audioBrick.isSelectedVariable.value = true
                }
                
                struct PanInfo {
                    static var copyAudioBrick: MediaBrick!
                }
                
                var isEnd = false
                switch centerPan.state {
                case .began:
                    PanInfo.copyAudioBrick = self.audioBrick.copy()
                    self.audioBrick.beganModifyTimeSubject.onNext(())
                case .cancelled:fallthrough
                case .ended:
                    self.audioBrick.isNeedCompose = true
                    isEnd = true
                default:
                    break
                }
                let audioDuration = self.audioBrick.modifiedEndTimeVarible.value - self.audioBrick.modifiedStartTimeVarible.value
                let limitStartTime = self.videoBrick.modifiedStartTimeVarible.value
                let limitEndTime = self.videoBrick.modifiedEndTimeVarible.value + audioDuration
                
                var timeInterval = self.editView.caculateChangedTimeInterval(pan: centerPan)
                
                var modifiedStartTime = PanInfo.copyAudioBrick.modifiedStartTimeVarible.value + timeInterval
                if modifiedStartTime < limitStartTime {
                    timeInterval += limitStartTime - modifiedStartTime
                    modifiedStartTime = PanInfo.copyAudioBrick.modifiedStartTimeVarible.value + timeInterval
                }
                
                var modifiedEndTime = PanInfo.copyAudioBrick.modifiedEndTimeVarible.value + timeInterval
                if modifiedEndTime > limitEndTime {
                    timeInterval += limitEndTime - modifiedEndTime
                    modifiedStartTime = PanInfo.copyAudioBrick.modifiedStartTimeVarible.value + timeInterval
                    modifiedEndTime = PanInfo.copyAudioBrick.modifiedEndTimeVarible.value + timeInterval
                }
                
                let startTime = PanInfo.copyAudioBrick.startTime + timeInterval
                let endTime = PanInfo.copyAudioBrick.endTime + timeInterval
                self.audioBrick.startTime = startTime
                self.audioBrick.endTime = endTime
                self.audioBrick.modifiedStartTimeVarible.value = modifiedStartTime
                self.audioBrick.modifiedEndTimeVarible.value = modifiedEndTime
                
                if isEnd {
                    self.audioBrick.endModifyTimeSubject.onNext(())
                }
            })
            .disposed(by: bag)
        addGestureRecognizer(centerPan)
        
        layer.addSublayer(audioInputReplicatorLayer)
        
        editBgView.addSubview(editView)
        editView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
    }
    
    func update() {
        
        editView.videoBrick = videoBrick
        editView.mediaBrick = audioBrick
        
        switch audioBrick.type! {
        case .video:
            return
        case .record:
            break
        case .music:
            
            darkColorView.backgroundColor = #colorLiteral(red: 0.0431372549, green: 0.8862745098, blue: 1, alpha: 1)
            lightColorView.backgroundColor = #colorLiteral(red: 0.0431372549, green: 0.8862745098, blue: 1, alpha: 0.4)
            waterImgView.tintColor = #colorLiteral(red: 0.0431372549, green: 0.8862745098, blue: 1, alpha: 1)
            iconImgView.image = #imageLiteral(resourceName: "ev_audio_music")
            
        case .soundEffect:
            
            darkColorView.backgroundColor = #colorLiteral(red: 0.662745098, green: 0.2784313725, blue: 1, alpha: 1)
            lightColorView.backgroundColor = #colorLiteral(red: 0.662745098, green: 0.2784313725, blue: 1, alpha: 0.4)
            waterImgView.tintColor = #colorLiteral(red: 0.662745098, green: 0.2784313725, blue: 1, alpha: 1)
            audioBrick.soundEffectIconUrlVariable
                .asObservable()
                .subscribe(onNext: { [weak self] (url) in
                    guard let `self` = self else { return }
                    self.iconImgView.kf.setImage(with: url)
                })
                .disposed(by: bag)
        }
        
        audioBrick.modifiedStartTimeVarible.asObservable()
            .distinctUntilChanged()
            .subscribe(onNext: { [unowned self] (_) in
                self.updateOriginX()
                self.updateWidth()
            })
            .disposed(by: bag)
        
        audioBrick.modifiedEndTimeVarible.asObservable()
            .distinctUntilChanged()
            .subscribe(onNext: { [unowned self] (_) in
                self.updateWidth()
            })
            .disposed(by: bag)
        
        audioBrick.isFoldVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (isFold) in
                UIView.animate(withDuration: 0.15, delay: 0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                    if isFold {
                        self.constraintDarkColorViewHeight.constant = 7
                        self.constraintLightColorViewHeight.constant = 2
                        self.audioInputReplicatorLayer.opacity = 0
                    } else {
                        self.constraintDarkColorViewHeight.constant = 65
                        self.constraintLightColorViewHeight.constant = 60
                        self.audioInputReplicatorLayer.opacity = 1
                    }
                    self.layoutIfNeeded()
                }, completion: nil)
            })
            .disposed(by: bag)
        
        audioBrick.isSelectedVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (isSelected) in
                self.audioBrick.isFoldVariable.value = !isSelected
                self.waterFrameImgView.isHidden = !isSelected
                UIView.animate(withDuration: 0.15, delay: 0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                    self.editBgView.alpha = isSelected ? 1 : 0
                }, completion: nil)
            })
            .disposed(by: bag)
        
        audioBrick.deleteSubject
            .subscribe(onNext: { [unowned self] (_) in
                UIView.animate(withDuration: 0.15, delay: 0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                    self.alpha = 0
                }) { _ in
                    self.removeFromSuperview()
                }
            })
            .disposed(by: bag)
    }
    
    func updateOriginX() {
        let startValue = CGFloat(audioBrick.modifiedStartTimeVarible.value/audioBrick.videoDuration)
        let leading = startValue * audioBrick.collectionViewContentWidth
        ks.origin.x = leading - MediaEditComponentView.spacing
    }
    
    func updateWidth() {
        let startTime = audioBrick.modifiedStartTimeVarible.value
        let endTime = audioBrick.modifiedEndTimeVarible.value
        let widthValue = CGFloat((endTime - startTime)/audioBrick.videoDuration)
        let width = widthValue * audioBrick.collectionViewContentWidth
        ks.width = width + 2 * MediaEditComponentView.spacing
        
        let layerWidth = width - 1
        let inputImg = #imageLiteral(resourceName: "ev_audio")
        let count = ceil(layerWidth/inputImg.size.width)
        audioInputReplicatorLayer.instanceCount = Int(count)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        audioInputReplicatorLayer.frame = CGRect(x: 15 + 1, y: 25 + (60 - inputImg.size.height)/2, width: layerWidth, height: inputImg.size.height)
        CATransaction.commit()
        
    }
}
