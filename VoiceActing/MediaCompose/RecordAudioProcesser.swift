//
//  RecordAudioAACEncoder.swift
//  kuso
//
//  Created by blurryssky on 2018/6/27.
//  Copyright © 2018年 momo. All rights reserved.
//

import Foundation

struct RecordAttributes {
    static let sampleRate: UInt = 44100
    static let numberOfChannels: UInt = 1
}

class RecordAudioProcesser: NSObject {
    
    fileprivate let skipDataLength = 1024 * 5
    fileprivate let eachDataLength = 1024
    
    lazy var encoder: AACEncoder = {
        let aed = AACEncoder(bitrate: 64000, sampleRate: RecordAttributes.sampleRate, channels: RecordAttributes.numberOfChannels)!
        return aed
    }()
}

extension RecordAudioProcesser {
    
    func encodeToAAC(fromFile fromFileUrl: URL, toFile tofileUrl: URL) throws {
        var fullData = Data(capacity: skipDataLength)
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: fromFileUrl)
            fileHandle.seek(toFileOffset: UInt64(skipDataLength))

            while true {
                let data = fileHandle.readData(ofLength: eachDataLength)
                let isLast = data.count == 0
                
                let encodedData = encoder.encodeSampleBuffer(data, at: CMTime.zero, isLast: isLast)!
                fullData.append(encodedData)
                
                if isLast {
                    break
                }
            }
            fileHandle.closeFile()
            
        } catch {
            throw error
        }
        
        do {
            try fullData.write(to: tofileUrl)
        } catch {
            throw error
        }
    }
}
