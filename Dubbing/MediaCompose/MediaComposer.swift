//
//  MediaComposer.swift
//  Kuso
//
//  Created by blurryssky on 2018/11/12.
//  Copyright © 2018 momo. All rights reserved.
//

import Foundation

import RxSwift

struct MediaComposer {
    
    // 主要是把音频合在视频上，所以视频的处理会有一些不同，传参的时候把视频的model和其他音频的model分开了
    static func compose(videoBrick: MediaComposeItem, audioBricks: [MediaComposeItem]) -> (AVMutableComposition, AVMutableAudioMix)? {

        // 这个是最后的合成对象，新建的时候相当于是一张白纸，准备往上面画画
        let composition = AVMutableComposition()
        // 这个是控制最后的composition的音量的，一般来说都会被设计成composition的属性，但iOS设计成了2个对象
        let audioMix = AVMutableAudioMix()
        // 初始化该属性为一个空数组，之后可以直接往数组里添加对象
        audioMix.inputParameters = []
        
        // 如果没有视频文件，return nil
        guard let videoAsset = videoBrick.videoAsset else {
            return nil
        }

        // 视频的全长范围
        let range = CMTimeRange(start: .zero, duration: videoAsset.duration)
        
        // 因为新建的composition是空的，先把原视频的视轨添加上去
        // 获取视频资源的视轨originVideoAssetTrack；创建composition新加的视轨originVideoCompotionTrack
        guard let originVideoAssetTrack = videoAsset.tracks(withMediaType: .video).first,
            let originVideoCompotionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        do {
            // 将originVideoCompotionTrack填满originVideoAssetTrack的内容
            try originVideoCompotionTrack.insertTimeRange(range, of: originVideoAssetTrack, at: .zero)
        } catch {
            return nil
        }
        // 到此添加完毕
        
        // 添加原视频的音轨，音轨可能有多个，先检查没有音轨return nil并且记录失败
        let audioTracks = videoAsset.tracks(withMediaType: .audio)
        // 所有被新建的originAudioCompositionTrack需要持有起来，之后被重合的音轨需要删除原音音轨
        var originAudioCompositionTracks: [AVMutableCompositionTrack] = []
        for originAudioAssetTrack in audioTracks {
            // 循环里和上面的逻辑一样
            guard let originAudioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                continue
            }
            do {
                try originAudioCompositionTrack.insertTimeRange(range, of: originAudioAssetTrack, at: .zero)
                originAudioCompositionTracks.append(originAudioCompositionTrack)
            } catch {
                continue
            }
        }
        
        // 到此准备工作做完了，现在composition已经和原视频文件具有相同的视轨和音轨了
        
        // 开始合成录音、音乐、音效
        for audioBrick in audioBricks {
            
            var mediaAsset: AVAsset!
            switch audioBrick.type! {
            case .record:
                
                // 获取本地录音资源文件，从pcm转到aac，并且完成变音功能
                guard let fileUrl = getAACFileUrl(recordBrick: audioBrick) else { continue }
                mediaAsset = AVAsset(url: fileUrl)
                
            case .music:

                // 因为音乐可以先编辑，优先取编辑之后的资源文件，再去原音乐资源文件
                if let asset = audioBrick.musicAsset {
                    mediaAsset = asset
                } else if let fileUrl = audioBrick.fileUrl {
                    mediaAsset = AVAsset(url: fileUrl)
                } else {
                    continue
                }
                
            case .soundEffect:
                
                // 获取本地音效资源文件
                guard let fileUrl = audioBrick.fileUrl else { continue }
                mediaAsset = AVAsset(url: fileUrl)
                
            default:
                continue
            }
            
            // 和上面的总体逻辑一样，获取资源文件的音轨，添加composition的音轨
            for audioAssetTrack in mediaAsset.tracks(withMediaType: .audio) {
                guard let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    continue
                }
                
                // 然后把资源文件的音轨插入到composition的音轨
                // 但是这些音频文件主要是在插入时间上有不同，原音轨用全范围即可，这里用到的范围会比较多
                // 一些范围检查
                let modifiedStartTime = max(audioBrick.editedStartTimeVarible.value, 0)
                let modifiedEndTime = min(audioBrick.editedEndTimeVarible.value, videoAsset.duration.seconds)
                guard modifiedStartTime < modifiedEndTime else { continue }
                
                // 参照音频文件的时间，是该音频资源内部的时间
                // 被编辑的时间 - 最早时间，即是内部的时间，这里使用的时间是CMTime
                let startTimeByAudio = CMTime(seconds: modifiedStartTime - audioBrick.startTime, preferredTimescale: audioAssetTrack.naturalTimeScale)
                // 这段音频的总时长
                let audioDuration = CMTime(seconds: modifiedEndTime - modifiedStartTime, preferredTimescale: audioAssetTrack.naturalTimeScale)
                // 根据上面两个时间，做出CMTimeRange
                let rangeByAudio = CMTimeRangeMake(start: startTimeByAudio, duration: audioDuration)
                
                // 参照视频文件的时间
                let startTimeByVideo = CMTime(seconds: modifiedStartTime, preferredTimescale: audioAssetTrack.naturalTimeScale)
                
                do {
                    // 开始填充audioCompositionTrack，将上面准备好的参数填入
                    try audioCompositionTrack.insertTimeRange(rangeByAudio, of: audioAssetTrack, at: startTimeByVideo)
                } catch {
                    continue
                }
                
                // 这是控制这段音频音量的代码
                let inputParameter = AVMutableAudioMixInputParameters(track: audioCompositionTrack)
                inputParameter.setVolume(audioBrick.preferredVolume, at: CMTime.zero)
                audioMix.inputParameters.append(inputParameter)
                
                // 如果是录音和音乐，需要把原音轨对应的声音去掉，所以去掉对应的范围
                if audioBrick.type! != .soundEffect {
                    // replace origin audio to empty
                    let removeRange = CMTimeRangeMake(start: startTimeByVideo, duration: audioDuration)
                    originAudioCompositionTracks.forEach {
                        $0.removeTimeRange(removeRange)
                        $0.insertEmptyTimeRange(removeRange)
                    }
                }
            }
        }
        // 返回的composition和audioMix，会被用在AVPlayer上进行播放
        return (composition, audioMix)
    }
    
    // 视频支持裁剪功能，第一个参数其实是上面compose方法产生的composition，同时需要视频的model来获取裁剪时间
    static func clip(asset: AVAsset, times: (startTime: TimeInterval, endTime: TimeInterval)) -> (AVMutableComposition, AVMutableVideoComposition?)? {
        
        // 同样是新建一个空的composition
        let composition = AVMutableComposition()
        
        // 范围检查
        let (startTime, endTime) = times
        guard startTime < endTime else { return nil }
        
        // 这里和之前类似，将视频资源的视轨插入到composition新加的视轨上
        guard let videoAssetTrack = asset.tracks(withMediaType: .video).first,
            let videoCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        // 范围取成裁剪后的范围，裁剪功能就完成了
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let range = CMTimeRange(start: startCMTime, end: endCMTime)
        do {
            try videoCompositionTrack.insertTimeRange(range, of: videoAssetTrack, at: .zero)
        } catch {
            return nil
        }
        
        // 这里是对竖直视频的处理，如果视频的方向不对，需要矫正（用手机竖直拍摄的视频方向就不对）
        // 下面的代码看做是固定处理代码吧
        // (其实所有视轨插入都需要这段代码，不过目前用来合成的视频方向都是正确的，而自己上传的视频都会先被裁剪，也就是调用这个方法后，再进入编辑页)
        var videoComposition: AVMutableVideoComposition?
        if videoAssetTrack.preferredTransform != .identity {
        
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
            let transform = videoAssetTrack.bs.transform
            // 这里的时间范围和开始时间要按照已经被裁剪后的时间来算
            let instructionRange = CMTimeRange(start: .zero, end: CMTimeSubtract(endCMTime, startCMTime))
            layerInstruction.setTransform(transform, at: .zero)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = instructionRange
            instruction.layerInstructions = [layerInstruction]
            
            videoComposition = AVMutableVideoComposition()
            videoComposition!.renderSize = videoAssetTrack.bs.renderSize
            videoComposition!.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition!.instructions = [instruction]
        }
        
        // 下面和之前的逻辑类似，根据范围裁剪
        for audioAssetTrack in asset.tracks(withMediaType: .audio) {
            guard let audioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                continue
            }
            do {
                try audioCompositionTrack.insertTimeRange(range, of: audioAssetTrack, at: .zero)
            } catch {
                continue
            }
        }
        // 返回的composition、videoComposition会在导出的时候使用
        return (composition, videoComposition)
    }
    
    // 完成视频编辑后，需要把内存里的composition audioMix videoComposition都导出到沙盒，存储起来，用来上传
    static func exportComposedVideo(asset: AVAsset, audioMix: AVAudioMix? = nil, videoComposition: AVMutableVideoComposition? = nil) -> Observable<URL> {
        return Observable<URL>.create({ (observer) -> Disposable in
            
            // 根据视轨的分辨率取得合适的导出分辨率
            guard let videoAssetTrack = asset.tracks(withMediaType: .video).first else {
                let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法导出该视频"])
                observer.onError(error)
                return Disposables.create()
            }
            let exportPreset = videoAssetTrack.bs.appropriateExportPreset

            // 获取兼容性的exportSession
            guard let exportSession = AVAssetExportSession.bs.compatibleSession(asset: asset, priorPresetName: exportPreset) else {
                return Disposables.create()
            }
            // 根据时间戳新建一个视频文件路径
            let outputUrl = FileManager.bs.newEditVideoUrl
            
            // 设置exportSession的参数
            exportSession.audioMix = audioMix
            exportSession.videoComposition = videoComposition
            exportSession.outputFileType = .mp4
            exportSession.outputURL = outputUrl
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.exportAsynchronously { [weak exportSession] in
                guard let es = exportSession else {
                    return
                }
                switch es.status {
                case .completed:
                    // 成功则发出最终的url
                    observer.onNext(outputUrl)
                case .failed:
                    // 失败则抛出错误
                    if let error = es.error {
                        observer.onError(error)
                    }
                default:
                    break
                }
            }
            return Disposables.create {
                // 如果这个observer被取消了，也把正在export的session取消掉
                exportSession.cancelExport()
            }
        })
            // 很随意的异步一下，其实意义不大
            .observeOn(MainScheduler.asyncInstance)
    }
}

private extension MediaComposer {
    
    static func getAACFileUrl(recordBrick: MediaComposeItem) -> URL? {
        
        let fileUrl = recordBrick.fileUrl!
        
        let lastPathNoExtension = fileUrl.deletingPathExtension().lastPathComponent
        let encodedFileUrl = FileManager.bs.encodedAudiosDir.appendingPathComponent(lastPathNoExtension).appendingPathExtension("aac")
        
        let encoder = RecordAudioProcesser()
        do {
            try encoder.encodeToAAC(fromFile: fileUrl, toFile: encodedFileUrl)
            return encodedFileUrl
        } catch {
            return nil
        }
    }

}
