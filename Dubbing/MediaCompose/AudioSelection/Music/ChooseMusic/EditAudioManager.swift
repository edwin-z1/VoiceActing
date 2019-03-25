//
//  EditAudioManager.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/6.
//  Copyright © 2018年 momo. All rights reserved.
//

import Foundation

import RxSwift

struct EditAudioManager {
    
    static func createEditComposition(fileAsset: AVURLAsset, startTime: TimeInterval, endTime: TimeInterval) -> AVMutableComposition {
        
        let composition = AVMutableComposition()
        // origin audio
        let audioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        if let audioAssetTrack = fileAsset.tracks(withMediaType: .audio).first {
            do {
                let start = CMTime(seconds: startTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                let end = CMTime(seconds: endTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                let range = CMTimeRange(start: start, end: end)
                try audioCompositionTrack?.insertTimeRange(range, of: audioAssetTrack, at: kCMTimeZero)
            } catch {
                print(error)
            }
        }
        return composition
    }
    
    static func exportEditedAudio(composition: AVComposition) -> Observable<URL> {
        return Observable<URL>.create({ (observer) -> Disposable in
            
            // export
            guard let exportSession = AVAssetExportSession.ks.compatibleSession(asset: composition, priorPresetName: AVAssetExportPresetPassthrough) else {
                return Disposables.create()
            }
            let outputUrl = FileManager.ks.newEditMusicUrl
            
            exportSession.outputFileType = AVFileType.mp3
            exportSession.outputURL = outputUrl
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.exportAsynchronously { [weak exportSession] in
                guard let es = exportSession else {
                    return
                }
                switch es.status {
                case .completed:
                    observer.onNext(outputUrl)
                case .failed:
                    if let error = es.error {
                        observer.onError(error)
                    }
                default:
                    break
                }
            }
            return Disposables.create {
                exportSession.cancelExport()
            }
        })
            .observeOn(MainScheduler.asyncInstance)
    }
}
