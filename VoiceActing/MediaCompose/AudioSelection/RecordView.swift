//
//  AudioRecordView.swift
//  Kuso
//
//  Created by blurryssky on 2018/10/31.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class RecordView: UIView {
    
    var viewModel: MediaComposeViewModel! {
        didSet {
            update()
        }
    }
    
    fileprivate(set) var recorder: AVAudioRecorder?

    fileprivate let bag = DisposeBag()
    // MARK: - Record Animation
    fileprivate var animationViews: [UIView] = []
    fileprivate var animationBag = DisposeBag()
    fileprivate let animationDuration: TimeInterval = 4
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
}

private extension RecordView {
    
    func setup() {
        let longPressGesture = UILongPressGestureRecognizer()
        longPressGesture.minimumPressDuration = 0.2
        let isLongPressStart = longPressGesture.rx.event
            .filter{ [unowned self] (longPress) -> Bool in
                
                switch longPress.state {
                case .began:
                    // 过滤由tap开始录音中再长按
                    if self.viewModel.isRecordVariable.value {
                        return false
                    } else {
                        return true
                    }
                case .ended: fallthrough
                case .cancelled:
                    return true
                default:
                    return false
                }
            }
            .map { longPress -> Bool in
                switch longPress.state {
                case .began:
                    return true
                default:
                    return false
                }
        }
        
        let tapGesture = UITapGestureRecognizer()
        let isTapStart = tapGesture.rx.event
            .map { [unowned self] _ in
                !self.viewModel.isRecordVariable.value
        }
        
        let startRecord = Observable.merge([isTapStart, isLongPressStart]).share()
        
        startRecord
            .filter { $0 }
            .flatMap { _ in
                AuthorizationManager.requestCaptureDeviceAuthorization(type: .audio)
            }
            .filter { $0 }
            .subscribe(onNext: { [unowned self] (isGranted) in
                self.startRecord()
            })
            .disposed(by: bag)
        
        startRecord
            .filter { !$0 }
            .subscribe(onNext: { [unowned self] (_) in
                self.endRecord()
            })
            .disposed(by: bag)
        
        addGestureRecognizer(tapGesture)
        addGestureRecognizer(longPressGesture)
        
        tapGesture.require(toFail: longPressGesture)
    }
    
    func startRecord() {
        AVAudioSession.bs.setAudioSession(category: .playAndRecord)
        let url = FileManager.bs.newRecordAudioUrl
        let settings = [AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: RecordAttributes.sampleRate,
                        AVNumberOfChannelsKey: RecordAttributes.numberOfChannels] as [String : Any]
        guard let recorder = try? AVAudioRecorder(url: url, format: AVAudioFormat(settings: settings)!),
            recorder.prepareToRecord(),
            recorder.record() else {
                return
        }
        self.recorder = recorder
        viewModel.isRecordVariable.value = true
    }
    
    func endRecord() {
        guard let recorder = self.recorder else { return }
        recorder.stop()
        viewModel.isRecordVariable.value = false
    }
    
    func update() {
        observeViewModel()
    }
    
    func observeViewModel() {
        viewModel.isRecordVariable.asObservable()
            .subscribe(onNext: { [unowned self] (isRecord) in
                if isRecord {
                    self.addRecordingAnimation()
                    self.viewModel.addRecordItem()
                } else {
                    
                    guard let recorder = self.recorder else { return }
                    self.removeRecordingAnimation()
                    self.viewModel.finishAddRecordItem(fileUrl: recorder.url)
                }
            })
            .disposed(by: bag)
    }
}

private extension RecordView {
    
    func addRecordingAnimation() {
        
        addRecordViewScaleAnimation(isEnding: false)
        let count = 5
        Observable<Int>.interval(animationDuration/Double(count), scheduler: MainScheduler.instance)
            .take(count)
            .subscribe(onNext: { [weak self] (idx) in
                guard let `self` = self else { return }
                
                var animationView: UIView!
                if self.animationViews.count < count {
                    animationView = UIView(frame: self.bounds)
                    animationView.isUserInteractionEnabled = false
                    animationView.layer.opacity = 0
                    self.addSubview(animationView)
                    self.animationViews.append(animationView)
                    
                    let fromPath = UIBezierPath(roundedRect: animationView.bounds, cornerRadius: animationView.bs.width/2)
                    
                    let shapeLayer = CAShapeLayer()
                    shapeLayer.path = fromPath.cgPath
                    shapeLayer.lineDashPattern = [NSNumber(value: 2)]
                    shapeLayer.strokeColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.4)
                    shapeLayer.fillColor = UIColor.clear.cgColor
                    animationView.layer.addSublayer(shapeLayer)
                    
                } else {
                    animationView = self.animationViews[idx]
                }
                self.addDashLineLayerAnimation(on: animationView, isEnding: false)
            })
            .disposed(by: animationBag)
    }
    
    func removeRecordingAnimation() {
        animationBag = DisposeBag()
        addRecordViewScaleAnimation(isEnding: true)
        animationViews.forEach { (animationView) in
            addDashLineLayerAnimation(on: animationView, isEnding: true)
        }
    }
    
    func addRecordViewScaleAnimation(isEnding: Bool) {
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = .forwards
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        if isEnding {
            let fromScale = layer.presentation()?.transform.m11 ?? 1
            scaleAnimation.fromValue = fromScale
            scaleAnimation.toValue = 1
            scaleAnimation.repeatCount = 1
            scaleAnimation.duration = animationDuration/5
        } else {
            scaleAnimation.fromValue = 1
            scaleAnimation.toValue = 0.9
            scaleAnimation.autoreverses = true
            scaleAnimation.repeatCount = .greatestFiniteMagnitude
            scaleAnimation.duration = animationDuration/5/2
        }
        
        layer.add(scaleAnimation, forKey: "scale")
    }
    
    func addDashLineLayerAnimation(on view: UIView, isEnding: Bool) {
        
        let fromScale = view.layer.presentation()?.transform.m11 ?? 1
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = isEnding ? fromScale : 1
        scaleAnimation.toValue = 2
        
        let fromOpacity = view.layer.presentation()?.opacity ?? 1
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = isEnding ? fromOpacity : 1
        opacityAnimation.toValue = 0
        
        let duration = isEnding ? Double(fromOpacity) * animationDuration * 0.5 : animationDuration
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.repeatCount = isEnding ? 1 : .greatestFiniteMagnitude
        animationGroup.duration = duration
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = .forwards
        
        view.layer.add(animationGroup, forKey: "group")
    }
}
