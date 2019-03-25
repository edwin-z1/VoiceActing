//
//  AVMutableComposition+NameBox.swift
//  Kuso
//
//  Created by blurryssky on 2018/8/6.
//  Copyright © 2018年 momo. All rights reserved.
//

import Foundation

extension NamespaceBox where T: AVComposition {
    
    var renderSize: CGSize {
        let preferredTransform = base.preferredTransform
        let width = floor(base.naturalSize.width)
        let height = floor(base.naturalSize.height)
        
        if preferredTransform.b != 0 {
            return CGSize(width: height, height: width)
        } else {
            return CGSize(width: width, height: height)
        }
    }
    
    var transform: CGAffineTransform {
        let preferredTransform = base.preferredTransform
        let width = floor(base.naturalSize.width)
        let height = floor(base.naturalSize.height)
        
        if preferredTransform.b == 1 { // home在左
            return CGAffineTransform(translationX: height, y: 0).rotated(by: CGFloat.pi/2)
        } else if preferredTransform.b == -1 { // home在右
            return CGAffineTransform(translationX: 0, y: width).rotated(by: CGFloat.pi/2 * 3)
        } else { // home在上
            return CGAffineTransform(translationX: width, y: height).rotated(by: CGFloat.pi)
        }
    }
    
    var appropriateExportPreset: String {
        
        if renderSize.width <= 640 {
            return AVAssetExportPreset640x480
        } else if renderSize.width <= 960 {
            return AVAssetExportPreset960x540
        } else if renderSize.width <= 1280 {
            return AVAssetExportPreset1280x720
        } else {
            return AVAssetExportPreset1920x1080
        }
    }
}
