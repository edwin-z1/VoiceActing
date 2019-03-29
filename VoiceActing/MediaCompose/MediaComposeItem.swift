//
//  MediaComposeItem.swift
//  Kuso
//
//  Created by blurryssky on 2018/10/31.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class MediaComposeItem: NSObject {
    
    // MARK: - 音块一共有4种，原视频、录音、音乐、音效
    enum MediaType: String {
        case video
        case record
        case soundEffect
    }
    
    var type: MediaType!
    /// 最早开始时间，由于音块可以拖动范围，这个是最早时间的限制
    var startTime: TimeInterval = 0
    /// 最晚结束时间，由于音块可以拖动范围，这个是最晚时间的限制
    var endTime: TimeInterval = 0
    /// 被编辑的开始时间
    let editedStartTimeVarible = Variable<TimeInterval>(0)
    /// 被编辑的结束时间
    let editedEndTimeVarible = Variable<TimeInterval>(0)
    
    /// 媒体文件的沙盒路径
    var fileUrl: URL?
    /// 该段媒体文件的音量
    var preferredVolume: Float = 1
    
    /// 用于 type == .video
    var videoAsset: AVAsset?
    var videoComposition: AVMutableVideoComposition?
    
    /// 用于 type == .soundEffect
    let soundEffectIconUrlVariable = Variable<URL?>(nil)
    
    // MARK: - 处理UI逻辑
    let isSelectedVariable = Variable<Bool>(false)

    /// 控制是否需要合成
    var isNeedCompose: Bool = true
    
    deinit {
        print("\(description) deinit")
    }
    
    /// 一个新的对象，只复制了4个时间，仅用于计算和处理UI
    func copy() -> MediaComposeItem {
        let mediaBrick = MediaComposeItem()
        mediaBrick.startTime = startTime
        mediaBrick.endTime = endTime
        mediaBrick.editedStartTimeVarible.value = editedStartTimeVarible.value
        mediaBrick.editedEndTimeVarible.value = editedEndTimeVarible.value
        return mediaBrick
    }
}
