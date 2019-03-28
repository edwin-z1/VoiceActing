//
//  AVAudioSession+NameBox.swift
//  kuso
//
//  Created by blurryssky on 2018/5/1.
//  Copyright © 2018年 momo. All rights reserved.
//

import AVFoundation

extension NamespaceBox where T == AVAudioSession {
    
    static func setAudioSession(category: AVAudioSession.Category) {
        let audioSeesion = AVAudioSession.sharedInstance()
        guard audioSeesion.category != category else {
            return
        }
        do {
            try audioSeesion.setCategory(category)
        } catch let error {
            print("setAudioSessionCategory = \(error)")
        }
        
    }
}
