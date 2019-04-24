//
//  MediaComposeViewModel.swift
//  VoiceActing
//
//  Created by blurryssky on 2019/3/20.
//  Copyright © 2019 blurryssky. All rights reserved.
//

import UIKit
import Photos

import RxSwift
import RxCocoa

class MediaComposeViewModel: NSObject {

    var videoAsset: AVAsset! {
        didSet {
            setup()
        }
    }
    
    var collectionViewContentWidth: CGFloat = 0
    
    let isRecordVariable = Variable(false)
    let isPlayVariable = Variable(false)
    private(set) var durationTextVariable: Variable<String>!
    private(set) var playerItemVariable: Variable<AVPlayerItem>!
    let previewProgressVariable: Variable<Double> = Variable(0)
    let playProgressVariable: Variable<Double> = Variable(0)
    
    private(set) var videoDuration: TimeInterval!
    private(set) var videoItem: MediaComposeItem!
    let audioItemsVariable: Variable<[MediaComposeItem]> = Variable([])
    
    let selectedItemVariable: Variable<MediaComposeItem?> = Variable(nil)
    let deleteItemSubject: PublishSubject<MediaComposeItem> = PublishSubject()
    
    private var recordingItem: MediaComposeItem?
    private(set) var replacingSoundEffectItem: MediaComposeItem?
    
    private var isNeedCompose = true
    
    private let bag = DisposeBag()
    
    private var copyVideoItem: MediaComposeItem!
    private var copyAudioItems: [MediaComposeItem] = []
    private var copyAudioItem: MediaComposeItem!
}

private extension MediaComposeViewModel {
    
    func setup() {
        
        // MARK: - Private
        videoDuration = videoAsset.duration.seconds
        setupVideoItem()
        
        // MARK: - Public
        durationTextVariable = Variable(videoDuration.bs.colonString)
        
        let playerItem = AVPlayerItem(asset: videoAsset)
        playerItemVariable = Variable(playerItem)
        
        // MARK: - Noti
        NotificationCenter.default.rx.notification(UIApplication.willResignActiveNotification)
            .subscribe(onNext: { [unowned self] (_) in
                self.endPlayAndRecord()
            })
            .disposed(by: bag)
    }
    
    func setupVideoItem() {
        videoItem = MediaComposeItem()
        videoItem.type = .video
        videoItem.editedEndTimeVariable.value = videoDuration
        videoItem.endTime = videoDuration
        videoItem.videoAsset = videoAsset

        videoItem.editedStartTimeVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (startTime) in
                
                self.isPlayVariable.value = false
                
                let startProgress = startTime/self.videoDuration
                if startProgress < self.playProgressVariable.value {
                    self.previewProgressVariable.value = startProgress
                } else {
                    self.playProgressVariable.value = startProgress
                }
                
                let duration = self.videoItem.editedEndTimeVariable.value - startTime
                self.durationTextVariable.value = duration.bs.colonString
            })
            .disposed(by: bag)
        
        videoItem.editedEndTimeVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (endTime) in
                
                self.isPlayVariable.value = false
                
                let endProgress = endTime/self.videoDuration
                if endProgress > self.playProgressVariable.value {
                    self.previewProgressVariable.value = endProgress
                } else {
                    self.playProgressVariable.value = endProgress
                }

                let duration = endTime - self.videoItem.editedStartTimeVariable.value
                self.durationTextVariable.value = duration.bs.colonString
            })
            .disposed(by: bag)
    }
}

// MARK : - 播放器区域
extension MediaComposeViewModel {
    
    func playerViewHeightWithWidth(_ width: CGFloat) -> CGFloat {
        
        var ratio: CGFloat = 0
        if let videoTrack = videoAsset.tracks(withMediaType: .video).first {
            let renderSize = videoTrack.bs.renderSize
            ratio = renderSize.width/renderSize.height
        }
        ratio = max(min(16/9, ratio), 1/0.6)
        let height = width/ratio
        return height
    }
    
    func handlePlayerViewTap() {
        replacingSoundEffectItem?.isSelectedVariable.value = false
        replacingSoundEffectItem = nil
        
        if isRecordVariable.value {
            isRecordVariable.value = false
        } else {
            let editedEndProgress = videoItem.editedEndTimeVariable.value/videoDuration
            if editedEndProgress - playProgressVariable.value > 0.01 {
                if isNeedCompose {
                    compose()
                }
                isPlayVariable.value = !isPlayVariable.value
            }
        }
    }
    
    var endBoundaryObservable: Observable<NSValue> {
        return videoItem.editedEndTimeVariable.asObservable()
            .map {
                let endTime = CMTime(seconds: $0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                return NSValue(time: endTime)
        }
    }
    
    func endPlayAndRecord() {
        isRecordVariable.value = false
        isPlayVariable.value = false
    }
    
    func updatePlayProgressByPlayerWithTime(_ time: TimeInterval) {
        // 是录音 且未完成录制
        if let recordItem = recordingItem {
            recordItem.editedEndTimeVariable.value = time
        }
        
        let progress = time/videoDuration
        if progress >= playProgressVariable.value {
            playProgressVariable.value = progress
        }
    }
    
    func updatePlayProgress(_ progress: Double) {
        playProgressVariable.value = progress
    }
}

// MARK : - 音视频编辑区域
extension MediaComposeViewModel {
    
    func updateItemSelected(_ item: MediaComposeItem, isSelected: Bool) {
        item.isSelectedVariable.value = isSelected
        if isSelected {
            if let lastSelectedItem = selectedItemVariable.value,
                lastSelectedItem != item {
                lastSelectedItem.isSelectedVariable.value = false
            }
            if let soundEffectItem = replacingSoundEffectItem,
                soundEffectItem != item {
                soundEffectItem.isSelectedVariable.value = false
            }
            selectedItemVariable.value = item
        } else {
            selectedItemVariable.value = nil
        }
        replacingSoundEffectItem = nil
    }
    
    func timeIntervalForPan(_ pan: UIPanGestureRecognizer) -> TimeInterval {
        let translationX = pan.translation(in: pan.view!).x
        let fraction = translationX/collectionViewContentWidth
        let timeInterval = Double(fraction) * videoDuration
        return timeInterval
    }
    
    func updateItemEditedStartTime(_ item: MediaComposeItem, timeInterval: TimeInterval) {
        item.editedStartTimeVariable.value = targetTimeForItem(item, timeInterval: timeInterval)
        isNeedCompose = true
    }
    
    func updateItemEditedEndTime(_ item: MediaComposeItem, timeInterval: TimeInterval) {
        item.editedEndTimeVariable.value = targetTimeForItem(item, timeInterval: timeInterval)
        isNeedCompose = true
    }
    
    private func targetTimeForItem(_ item: MediaComposeItem, timeInterval: TimeInterval) -> TimeInterval {
        var targetTime = min(max(timeInterval, item.startTime), item.endTime)
        
        // 并且在视频的编辑后的范围内
        if item != videoItem {
            targetTime = min(max(targetTime, videoItem.editedStartTimeVariable.value), videoItem.editedEndTimeVariable.value)
        }
        return targetTime
    }
    
    func copyItemsBeforeEditVideo() {
        copyVideoItem = videoItem.copy()
        copyAudioItems = audioItemsVariable.value.map{ $0.copy() }
    }
    
    func moveAudioItemsToRight() {
        let videoStartTime = videoItem.editedStartTimeVariable.value

        for (idx, audioItem) in audioItemsVariable.value.enumerated() {
            
            let copyAudioItem = copyAudioItems[idx]
            let copyAudioStartTime = copyAudioItem.editedStartTimeVariable.value
            
            let timeInterval = videoStartTime - copyAudioStartTime
            guard timeInterval > 0 else {
                continue
            }
            audioItem.startTime = copyAudioItem.startTime + timeInterval
            audioItem.endTime = copyAudioItem.endTime + timeInterval
            audioItem.editedStartTimeVariable.value = copyAudioStartTime + timeInterval
            audioItem.editedEndTimeVariable.value = copyAudioItem.editedEndTimeVariable.value + timeInterval
        }
        
        isNeedCompose = true
    }
    
    func moveAudioItemsToLeft() {
        
        let videoEndTime = videoItem.editedEndTimeVariable.value
        
        for (idx, audioItem) in audioItemsVariable.value.enumerated() {
            
            let copyAudioItem = copyAudioItems[idx]
            let copyAudioEndTime = copyAudioItem.editedEndTimeVariable.value
            
            let timeInterval = videoEndTime - copyAudioEndTime
            guard timeInterval < 0 else {
                continue
            }
            audioItem.startTime = copyAudioItem.startTime + timeInterval
            audioItem.endTime = copyAudioItem.endTime + timeInterval
            audioItem.editedStartTimeVariable.value = copyAudioItem.editedStartTimeVariable.value + timeInterval
            audioItem.editedEndTimeVariable.value = copyAudioEndTime + timeInterval
        }
        
        isNeedCompose = true
    }
    
    func copyAudioItemBeforeEditAudio() {
        guard let audioItem = selectedItemVariable.value else {
            return
        }
        copyAudioItem = audioItem.copy()
    }
    
    func offsetAudioItemTimes(_ item: MediaComposeItem, timeInterval: TimeInterval) {
        
        let limitStartTime = videoItem.editedStartTimeVariable.value
        let limitEndTime = videoItem.editedEndTimeVariable.value
        
        var timeInterval = timeInterval
        
        var editedStartTime = copyAudioItem.editedStartTimeVariable.value + timeInterval
        if editedStartTime < limitStartTime {
            timeInterval += limitStartTime - editedStartTime
            editedStartTime = copyAudioItem.editedStartTimeVariable.value + timeInterval
        }
        
        var editedEndTime = copyAudioItem.editedEndTimeVariable.value + timeInterval
        if editedEndTime > limitEndTime {
            timeInterval += limitEndTime - editedEndTime
            editedStartTime = copyAudioItem.editedStartTimeVariable.value + timeInterval
            editedEndTime = copyAudioItem.editedEndTimeVariable.value + timeInterval
        }
        
        let startTime = copyAudioItem.startTime + timeInterval
        let endTime = copyAudioItem.endTime + timeInterval
        item.startTime = startTime
        item.endTime = endTime
        item.editedStartTimeVariable.value = editedStartTime
        item.editedEndTimeVariable.value = editedEndTime
        
        isNeedCompose = true
    }
    
    func updateItemVolume(_ item: MediaComposeItem, volume: Float) {
        item.preferredVolume = volume
        isNeedCompose = true
    }
}


// MARK : - 音频输入区域
extension MediaComposeViewModel {
    
    func addRecordItem() {
        let recordItem = MediaComposeItem()
        recordItem.type = .record
        let currentTime = playProgressVariable.value * videoDuration
        recordItem.startTime = currentTime
        recordItem.editedStartTimeVariable.value = currentTime
        recordItem.editedEndTimeVariable.value = currentTime
        audioItemsVariable.value.append(recordItem)
        recordingItem = recordItem
    }
    
    func finishAddRecordItem(fileUrl: URL) {
        guard let recordItem = recordingItem else {
            return
        }
        let currentTime = playProgressVariable.value * videoDuration
        recordItem.editedEndTimeVariable.value = currentTime
        recordItem.endTime = currentTime
        recordItem.fileUrl = fileUrl
        recordItem.isSelectedVariable.value = false
        recordingItem = nil
        
        isNeedCompose = true
    }
    
    func addSoundEffectItem(_ soundEffect: SoundEffect) {
        
        var sdItem: MediaComposeItem!
        
        if let existItem = replacingSoundEffectItem {
            sdItem = existItem
        } else {
            sdItem = MediaComposeItem()
            sdItem.type = .soundEffect
            
            let currentTime = playProgressVariable.value * videoDuration
            sdItem.startTime = currentTime
            sdItem.editedStartTimeVariable.value = currentTime
            
            audioItemsVariable.value.append(sdItem)
            
            replacingSoundEffectItem = sdItem
        }
        
        sdItem.fileUrl = soundEffect.fileUrl
        sdItem.soundEffectImgVariable.value = soundEffect.iconImg

        let asset = AVAsset(url: soundEffect.fileUrl)
        let sdDuration = asset.duration.seconds
        
        let endTime = sdItem.startTime + sdDuration
        sdItem.endTime = endTime
        
        let editedEndTime = min(videoItem.editedEndTimeVariable.value, endTime)
        sdItem.editedEndTimeVariable.value = editedEndTime
        
        isNeedCompose = true
    }
    
    func removeAudioItem(_ item: MediaComposeItem) {
        updateItemSelected(item, isSelected: false)
        if let idx = audioItemsVariable.value.firstIndex(of: item) {
            audioItemsVariable.value.remove(at: idx)
        }
        deleteItemSubject.onNext(item)
        
        isNeedCompose = true
    }
}

// MARK : - 合成
extension MediaComposeViewModel {
    
    func compose() {
        guard let (composition, audioMix, videoComposition) = MediaComposer.compose(videoItem: videoItem, audioItems: audioItemsVariable.value) else {
            return
        }
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.audioMix = audioMix
        playerItem.videoComposition = videoComposition
        playerItemVariable.value = playerItem
        updatePlayProgress(playProgressVariable.value)
        
        isNeedCompose = false
    }
    
    func export(success: @escaping ()->Void, failure: @escaping (Error)->Void) {
        
        if isNeedCompose {
            compose()
        }
        
        let asset = playerItemVariable.value.asset
        guard let composition = MediaComposer.clip(asset: asset, times: (videoItem.editedStartTimeVariable.value, videoItem.editedEndTimeVariable.value)) else {
            return
        }
        _ = MediaComposer.exportComposedVideo(asset: composition, audioMix: playerItemVariable.value.audioMix, videoComposition: playerItemVariable.value.videoComposition)
            .subscribe(onNext: { (fileUrl) in
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileUrl)
                }) { (isFinished, error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            failure(error)
                        } else {
                            success()
                        }
                    }
                }
                
            }, onError: { (error) in
                failure(error)
            })
    }
}
