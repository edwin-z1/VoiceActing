//
//  AudioEditView.swift
//  VoiceActing
//
//  Created by blurryssky on 2018/10/31.
//  Copyright © 2018 blurryssky. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class AudioEditView: UIView {
    
    var viewModel: MediaComposeViewModel!
    var audioItem: MediaComposeItem! {
        didSet {
            update()
        }
    }
    
    let bag = DisposeBag()

    @IBOutlet weak var darkColorView: UIView!
    @IBOutlet weak var lightColorView: UIView!
    @IBOutlet weak var waterImgView: UIImageView! {
        didSet {
            waterImgView.image = #imageLiteral(resourceName: "ev_color_water").withRenderingMode(.alwaysTemplate)
        }
    }
    @IBOutlet weak var waterFrameImgView: UIImageView!
    @IBOutlet weak var iconImgView: UIImageView!
    
    private lazy var editView: MediaEditComponentView = {
        let editView = MediaEditComponentView.bs.instantiateFromNib
        editView.alpha = 0
        return editView
    }()
    
    private lazy var audioInputReplicatorLayer: CAReplicatorLayer = {
        let audioLayer = CALayer()
        let inputImg = #imageLiteral(resourceName: "ev_audio")
        audioLayer.frame = CGRect(origin: .zero, size: inputImg.size)
        audioLayer.contents = inputImg.cgImage
        audioLayer.contentsScale = UIScreen.main.scale
        audioLayer.contentsGravity = .left
        
        let inputLayer = CAReplicatorLayer()
        inputLayer.instanceTransform = CATransform3DMakeTranslation(inputImg.size.width + 4, 0, 0)
        inputLayer.masksToBounds = true
        inputLayer.addSublayer(audioLayer)
        return inputLayer
    }()
    
    @IBOutlet weak var constraintDarkColorViewHeight: NSLayoutConstraint!
    @IBOutlet weak var constraintLightColorViewHeight: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        
        let editRect = editView.frame
        let rightBottomRect = CGRect(x: waterImgView.frame.maxX, y: waterImgView.frame.minY,
                                   width: bs.width - waterImgView.bs.width, height: waterImgView.bs.height)
        
        if !audioItem.isSelectedVariable.value {
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

private extension AudioEditView {
    
    func setup() {
        let tap = UITapGestureRecognizer()
        tap.rx.event
            .subscribe(onNext: { [unowned self] (tap) in
                let isSelected = !self.audioItem.isSelectedVariable.value
                self.viewModel.updateItemSelected(self.audioItem, isSelected: isSelected)
            })
            .disposed(by: bag)
        addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer()
        pan.rx.event
            .subscribe(onNext: { [unowned self] (pan) in
                
                self.viewModel.updateItemSelected(self.audioItem, isSelected: true)
                
                switch pan.state {
                case .began:
                    self.viewModel.copyAudioItemBeforeEditAudio()
                case .changed:
                    let timeInterval = self.viewModel.timeIntervalForPan(pan)
                    self.viewModel.offsetAudioItemTimes(self.audioItem, timeInterval: timeInterval)
                case .cancelled:fallthrough
                case .ended:
                    break
                default: break
                }
            })
            .disposed(by: bag)
        addGestureRecognizer(pan)
        
        layer.addSublayer(audioInputReplicatorLayer)
        
        addSubview(editView)
        editView.snp.makeConstraints { (maker) in
            maker.top.equalToSuperview()
            maker.left.equalToSuperview()
            maker.right.equalToSuperview()
            maker.height.equalTo(VideoControlView.collectionViewInsetTop + VideoControlView.itemHeight)
        }
        
    }
    
    func update() {
        
        editView.viewModel = viewModel
        editView.mediaItem = audioItem
        
        switch audioItem.type! {
        case .soundEffect:
            
            darkColorView.backgroundColor = #colorLiteral(red: 0.662745098, green: 0.2784313725, blue: 1, alpha: 1)
            lightColorView.backgroundColor = #colorLiteral(red: 0.662745098, green: 0.2784313725, blue: 1, alpha: 0.4)
            waterImgView.tintColor = #colorLiteral(red: 0.662745098, green: 0.2784313725, blue: 1, alpha: 1)
            audioItem.soundEffectImgVariable
                .asDriver()
                .drive(iconImgView.rx.image)
                .disposed(by: bag)
        default:
            break
        }
        
        audioItem.editedStartTimeVariable.asObservable()
            .subscribe(onNext: { [unowned self] (_) in
                self.updateOriginX()
                self.updateWidth()
            })
            .disposed(by: bag)
        
        audioItem.editedEndTimeVariable.asObservable()
            .subscribe(onNext: { [unowned self] (_) in
                self.updateWidth()
            })
            .disposed(by: bag)
        
        audioItem.isSelectedVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (isSelected) in
                self.waterFrameImgView.isHidden = !isSelected
                UIView.bs.animate(content: {
                    self.editView.alpha = isSelected ? 1 : 0
                })
                UIView.bs.animate(duration: 0.15, content: {
                    if !isSelected {
                        self.constraintDarkColorViewHeight.constant = 7
                        self.constraintLightColorViewHeight.constant = 2
                        self.audioInputReplicatorLayer.opacity = 0
                    } else {
                        self.constraintDarkColorViewHeight.constant = 65
                        self.constraintLightColorViewHeight.constant = 60
                        self.audioInputReplicatorLayer.opacity = 1
                    }
                    self.layoutIfNeeded()
                })
            })
            .disposed(by: bag)
        
        viewModel.deleteItemSubject
            .filter{ [unowned self] in
                self.audioItem == $0
            }
            .subscribe(onNext: { [unowned self] (item) in
                UIView.bs.animate(content: {
                    self.alpha = 0
                }, completion: { (_) in
                    self.removeFromSuperview()
                })
            })
            .disposed(by: bag)
    }
    
    func updateOriginX() {

        let startValue = audioItem.editedStartTimeVariable.value/viewModel.videoDuration
        let leading = CGFloat(startValue) * viewModel.collectionViewContentWidth
        bs.origin.x = leading - MediaEditComponentView.handleWidth
    }
    
    func updateWidth() {
        
        let startValue = audioItem.editedStartTimeVariable.value/viewModel.videoDuration
        let endValue = audioItem.editedEndTimeVariable.value/viewModel.videoDuration
        
        let widthValue = endValue - startValue
        if widthValue < 0 {
            return;
        }
        let width = CGFloat(widthValue) * viewModel.collectionViewContentWidth
        bs.width = width + 2 * MediaEditComponentView.handleWidth
        
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
