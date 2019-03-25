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

class AudioRecordView: UIView {
    
    var recordCount = 0
    
    var isRecordVariable = Variable<Bool>(false)
    
    fileprivate(set) var recorder: AVAudioRecorder?

    @IBOutlet weak var micView: UIView!

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

private extension AudioRecordView {
    
    func setup() {
        setupMicView()
        setupRecordVariable()
    }
    
    func setupMicView() {
        let longPressGesture = UILongPressGestureRecognizer()
        longPressGesture.minimumPressDuration = 0.2
        let isLongPressStart = longPressGesture.rx.event
            .filter{ [unowned self] (longPress) -> Bool in
                
                switch longPress.state {
                case .began:
                    // 过滤由tap开始录音中再长按
                    if self.isRecordVariable.value {
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
                !self.isRecordVariable.value
            }
        
        let startRecord = Observable.merge([isTapStart, isLongPressStart]).share()
        
        startRecord
            .filter { $0 }
            .flatMap { _ in
                AuthorizationManager.requestCaptureDeviceAuthorization(type: .audio)
            }
            .filter { $0 }
            .subscribe(onNext: { [unowned self] (isGranted) in
                self.createRecorder()
            })
            .disposed(by: bag)
        
        startRecord
            .filter { !$0 }
            .subscribe(onNext: { [unowned self] (_) in
                self.isRecordVariable.value = false
            })
            .disposed(by: bag)
        
        micView.addGestureRecognizer(tapGesture)
        micView.addGestureRecognizer(longPressGesture)
        
        tapGesture.require(toFail: longPressGesture)
    }
    
    func setupRecordVariable() {
        isRecordVariable.asObservable()
            .distinctUntilChanged()
            .subscribe(onNext: { [unowned self] (isRecord) in
                if isRecord {
                    
                    guard let recorder = self.recorder,
                        recorder.prepareToRecord(),
                        recorder.record() else {
                            return
                    }
                    self.addRecordingAnimation()
                } else {
                    
                    guard let recorder = self.recorder else { return }
                    recorder.stop()
                    self.removeRecordingAnimation()
                }
            })
            .disposed(by: bag)
    }
    
    func createRecorder() {
        
        guard recordCount < App.systemSetting.mediaSetting.maxRecordCount else {
            UIView.ks.showToast(title:"最多只能配置\(App.systemSetting.mediaSetting.maxRecordCount)个录音")
            return
        }
        
        let url = FileManager.ks.newRecordAudioUrl
        do {
            AVAudioSession.ks.setAudioSessionCategory(AVAudioSessionCategoryPlayAndRecord)
            
            let settings = [AVFormatIDKey: kAudioFormatLinearPCM,
                            AVSampleRateKey: RecordAttributes.sampleRate,
                            AVNumberOfChannelsKey: RecordAttributes.numberOfChannels] as [String : Any]
            recorder = try AVAudioRecorder(url: url, format: AVAudioFormat(settings: settings)!)
            recorder?.isMeteringEnabled = true
            isRecordVariable.value = true
        } catch {
            print("\(#file, #line) catch = \(error)")
        }
    }
}

private extension AudioRecordView {
    
    func addRecordingAnimation() {
        
        addMicViewScaleAnimation(isEndingAnimation: false)
        let count = 5
        Observable<Int>.interval(animationDuration/Double(count), scheduler: MainScheduler.instance)
            .take(count)
            .subscribe(onNext: { [weak self] (idx) in
                guard let `self` = self else { return }
                
                var animationView: UIView!
                if self.animationViews.count < count {
                    animationView = UIView(frame: self.micView.frame)
                    animationView.isUserInteractionEnabled = false
                    animationView.layer.opacity = 0
                    self.addSubview(animationView)
                    self.animationViews.append(animationView)
                    
                    let fromPath = UIBezierPath(roundedRect: animationView.bounds, cornerRadius: animationView.ks.width/2)
                    
                    let shapeLayer = CAShapeLayer()
                    shapeLayer.path = fromPath.cgPath
                    shapeLayer.lineDashPattern = [NSNumber(value: 2)]
                    shapeLayer.strokeColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.3)
                    shapeLayer.fillColor = UIColor.clear.cgColor
                    animationView.layer.addSublayer(shapeLayer)
                    
                } else {
                    animationView = self.animationViews[idx]
                }
                self.addDashLineLayerAnimation(on: animationView, isEndingAnimation: false)
            })
            .disposed(by: animationBag)
    }
    
    func removeRecordingAnimation() {
        animationBag = DisposeBag()
        addMicViewScaleAnimation(isEndingAnimation: true)
        animationViews.forEach { (animationView) in
            addDashLineLayerAnimation(on: animationView, isEndingAnimation: true)
        }
    }
    
    func addMicViewScaleAnimation(isEndingAnimation: Bool) {
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = kCAFillModeForwards
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        
        if isEndingAnimation {
            let fromScale = micView.layer.presentation()?.transform.m11 ?? 1
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
        
        micView.layer.add(scaleAnimation, forKey: "scale")
    }
    
    func addDashLineLayerAnimation(on view: UIView, isEndingAnimation: Bool) {
        
        let fromScale = view.layer.presentation()?.transform.m11 ?? 1
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = isEndingAnimation ? fromScale : 1
        scaleAnimation.toValue = 2
        
        let fromOpacity = view.layer.presentation()?.opacity ?? 1
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = isEndingAnimation ? fromOpacity : 1
        opacityAnimation.toValue = 0
        
        let duration = isEndingAnimation ? Double(fromOpacity) * animationDuration * 0.5 : animationDuration
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.repeatCount = isEndingAnimation ? 1 : .greatestFiniteMagnitude
        animationGroup.duration = duration
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = kCAFillModeForwards
        
        view.layer.add(animationGroup, forKey: "group")
    }
}
