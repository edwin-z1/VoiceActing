//
//  AVAudioSession+NameBox.swift
//  kuso
//
//  Created by blurryssky on 2018/5/1.
//  Copyright © 2018年 momo. All rights reserved.
//

import AVFoundation

extension NamespaceBox where T == AVAudioSession {
    
    static func setAudioSession(category: AVAudioSession.Category, policy: AVAudioSession.RouteSharingPolicy = .default) {
        let audioSeesion = AVAudioSession.sharedInstance()
        guard audioSeesion.category != category, audioSeesion.routeSharingPolicy != policy else {
            return
        }
        do {
            try audioSeesion.setCategory(category, mode: .moviePlayback, policy: policy, options: [.allowAirPlay])
        } catch let error {
            print("setAudioSessionCategory = \(error)")
        }
        
    }
}
