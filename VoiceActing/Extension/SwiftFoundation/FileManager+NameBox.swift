//
//  FileManager+NameBox.swift
//  VoiceActing
//
//  Created by blurryssky on 2018/5/3.
//  Copyright © 2018年 blurryssky. All rights reserved.
//

import Foundation

private let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
private let videosDir = URL(fileURLWithPath: libraryPath).appendingPathComponent("Videos")

extension NamespaceBox where T: FileManager {
    
    // video dirs
    static var recordedAudiosDir: URL {
        return videosDir.appendingPathComponent("RecordedAudios")
    }
    
    static var encodedAudiosDir: URL {
        return videosDir.appendingPathComponent("EncodedAudios")
    }
    
    static var editedVideosDir: URL {
        return videosDir.appendingPathComponent("EditedVideos")
    }
    
    // file urls
    static var newRecordAudioUrl: URL {
        return recordedAudiosDir.appendingPathComponent(timestamp).appendingPathExtension("pcm")
    }
    
    static var newEditVideoUrl: URL {
        return editedVideosDir.appendingPathComponent(timestamp).appendingPathExtension("mp4")
    }
    
    private static var timestamp: String {
        //564135105.987225
        return "\(Int(Date().timeIntervalSinceReferenceDate * 1000000))"
    }
}

extension NamespaceBox where T: FileManager {
    
    static func createDirectorys() {
        let dirs = [recordedAudiosDir, encodedAudiosDir, editedVideosDir]
        for dir in dirs {
            if !FileManager.default.fileExists(atPath: dir.path) {
                do {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                } catch let error {
                    print("create \(dir) = \(error)")
                }
            }
        }
    }
    
    static func clearFiles() {
        
        let dirs = [recordedAudiosDir, encodedAudiosDir, editedVideosDir]
        
        for dir in dirs {
            do {
                try T.default.removeItem(at: dir)
            } catch let error {
                print("clearFiles \(dir) = \(error)")
            }
        }
    }
}
