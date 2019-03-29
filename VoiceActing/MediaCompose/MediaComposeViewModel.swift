//
//  MediaComposeViewModel.swift
//  VoiceActing
//
//  Created by blurryssky on 2019/3/20.
//  Copyright © 2019 blurryssky. All rights reserved.
//

import UIKit

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
        videoItem.editedEndTimeVarible.value = videoDuration
        videoItem.endTime = videoDuration
        videoItem.videoAsset = videoAsset
        videoItem.isNeedCompose = false
        
        videoItem.editedStartTimeVarible.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (startTime) in
                
                self.isPlayVariable.value = false
                
                let startProgress = startTime/self.videoDuration
                if startProgress < self.playProgressVariable.value {
                    self.previewProgressVariable.value = startProgress
                } else {
                    self.playProgressVariable.value = startProgress
                }
                
                let duration = self.videoItem.editedEndTimeVarible.value - startTime
                self.durationTextVariable.value = duration.bs.colonString
            })
            .disposed(by: bag)
        
        videoItem.editedEndTimeVarible.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (endTime) in
                
                self.isPlayVariable.value = false
                
                let endProgress = endTime/self.videoDuration
                if endProgress > self.playProgressVariable.value {
                    self.previewProgressVariable.value = endProgress
                } else {
                    self.playProgressVariable.value = endProgress
                }

                let duration = endTime - self.videoItem.editedStartTimeVarible.value
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
        if isRecordVariable.value {
            isRecordVariable.value = false
        } else {
            let editedEndProgress = videoItem.editedEndTimeVarible.value/videoDuration
            if editedEndProgress - playProgressVariable.value > 0.01 {
                isPlayVariable.value = !isPlayVariable.value
            }
        }
    }
    
    var endBoundaryObservable: Observable<NSValue> {
        return videoItem.editedEndTimeVarible.asObservable()
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
            recordItem.editedEndTimeVarible.value = time
        }
        
        let progress = time/videoDuration
        if progress > playProgressVariable.value {
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
            selectedItemVariable.value = item
        } else {
            selectedItemVariable.value = nil
        }
    }
    
    func timeIntervalForPan(_ pan: UIPanGestureRecognizer) -> TimeInterval {
        let translationX = pan.translation(in: pan.view!).x
        let fraction = translationX/collectionViewContentWidth
        let timeInterval = Double(fraction) * videoDuration
        return timeInterval
    }
    
    func copyItemsBeforeEditVideo() {
        copyVideoItem = videoItem.copy()
        copyAudioItems = audioItemsVariable.value.map{ $0.copy() }
    }
    
    func updateItemEditedStartTime(_ item: MediaComposeItem, timeInterval: TimeInterval) {
        item.editedStartTimeVarible.value = targetTimeForItem(item, timeInterval: timeInterval)
    }
    
    func updateItemEditedEndTime(_ item: MediaComposeItem, timeInterval: TimeInterval) {
        item.editedEndTimeVarible.value = targetTimeForItem(item, timeInterval: timeInterval)
    }
    
    private func targetTimeForItem(_ item: MediaComposeItem, timeInterval: TimeInterval) -> TimeInterval {
        var targetTime = min(max(timeInterval, item.startTime), item.endTime)
        
        // 并且在视频的编辑后的范围内
        if item != videoItem {
            targetTime = min(max(targetTime, videoItem.editedStartTimeVarible.value), videoItem.editedEndTimeVarible.value)
        }
        return targetTime
    }
    
    func moveAudioItemsToRight() {
        let videoStartTime = videoItem.editedStartTimeVarible.value

        for (idx, audioItem) in audioItemsVariable.value.enumerated() {
            
            let copyAudioItem = copyAudioItems[idx]
            let copyAudioStartTime = copyAudioItem.editedStartTimeVarible.value
            
            let timeInterval = videoStartTime - copyAudioStartTime
            guard timeInterval > 0 else {
                continue
            }
            audioItem.startTime = copyAudioItem.startTime + timeInterval
            audioItem.endTime = copyAudioItem.endTime + timeInterval
            audioItem.editedStartTimeVarible.value = copyAudioStartTime + timeInterval
            audioItem.editedEndTimeVarible.value = copyAudioItem.editedEndTimeVarible.value + timeInterval
        }
    }
    
    func moveAudioItemsToLeft() {
        
        let videoEndTime = videoItem.editedEndTimeVarible.value
        
        for (idx, audioItem) in audioItemsVariable.value.enumerated() {
            
            let copyAudioItem = copyAudioItems[idx]
            let copyAudioEndTime = copyAudioItem.editedEndTimeVarible.value
            
            let timeInterval = videoEndTime - copyAudioEndTime
            guard timeInterval > 0 else {
                continue
            }
            audioItem.startTime = copyAudioItem.startTime + timeInterval
            audioItem.endTime = copyAudioItem.endTime + timeInterval
            audioItem.editedStartTimeVarible.value = copyAudioItem.editedStartTimeVarible.value + timeInterval
            audioItem.editedEndTimeVarible.value = copyAudioEndTime + timeInterval
        }
    }
    
    func copyAudioItemBeforeEditAudio() {
        guard let audioItem = selectedItemVariable.value else {
            return
        }
        copyAudioItem = audioItem.copy()
    }
    
    func updateAudioItemTimes(_ item: MediaComposeItem, timeInterval: TimeInterval) {
        
        let limitStartTime = videoItem.editedStartTimeVarible.value
        let limitEndTime = videoItem.editedEndTimeVarible.value
        
        var timeInterval = timeInterval
        
        var editedStartTime = copyAudioItem.editedStartTimeVarible.value + timeInterval
        if editedStartTime < limitStartTime {
            timeInterval += limitStartTime - editedStartTime
            editedStartTime = copyAudioItem.editedStartTimeVarible.value + timeInterval
        }
        
        var editedEndTime = copyAudioItem.editedEndTimeVarible.value + timeInterval
        if editedEndTime > limitEndTime {
            timeInterval += limitEndTime - editedEndTime
            editedStartTime = copyAudioItem.editedStartTimeVarible.value + timeInterval
            editedEndTime = copyAudioItem.editedEndTimeVarible.value + timeInterval
        }
        
        let startTime = copyAudioItem.startTime + timeInterval
        let endTime = copyAudioItem.endTime + timeInterval
        item.startTime = startTime
        item.endTime = endTime
        item.editedStartTimeVarible.value = editedStartTime
        item.editedEndTimeVarible.value = editedEndTime
    }
}


// MARK : - 音频输入区域
extension MediaComposeViewModel {
    
    func addRecordItem() {
        let recordItem = MediaComposeItem()
        recordItem.type = .record
        let currentTime = playProgressVariable.value * videoDuration
        recordItem.startTime = currentTime
        recordItem.editedStartTimeVarible.value = currentTime
        recordItem.editedEndTimeVarible.value = currentTime
        audioItemsVariable.value.append(recordItem)
        recordingItem = recordItem
    }
    
    func finishAddRecordItem(fileUrl: URL) {
        guard let recordItem = recordingItem else {
            return
        }
        let currentTime = playProgressVariable.value * videoDuration
        recordItem.editedEndTimeVarible.value = currentTime
        recordItem.endTime = currentTime
        recordItem.fileUrl = fileUrl
        recordItem.isSelectedVariable.value = false
        recordingItem = nil
    }
    
    func removeAudioItem(_ item: MediaComposeItem) {
        updateItemSelected(item, isSelected: false)
        if let idx = audioItemsVariable.value.index(of: item) {
            audioItemsVariable.value.remove(at: idx)
        }
        deleteItemSubject.onNext(item)
    }
}
