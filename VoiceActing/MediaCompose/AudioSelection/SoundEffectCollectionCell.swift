//
//  AudioSoundEffectCollectionCell.swift
//  VoiceActing
//
//  Created by blurryssky on 2019/4/23.
//  Copyright © 2019 blurryssky. All rights reserved.
//

import UIKit

class SoundEffectCollectionCell: UICollectionViewCell {
    
    var soundEffect: SoundEffect! {
        didSet {
            update()
        }
    }

    @IBOutlet weak var imgView: UIImageView!
    
    override var isSelected: Bool {
        didSet {
            guard isSelected else {
                return
            }
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.toValue = 1.2
            scaleAnimation.fromValue = 1
            scaleAnimation.autoreverses = true
            scaleAnimation.duration = 0.15
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(scaleAnimation, forKey: "scale")
        }
    }
}

private extension SoundEffectCollectionCell {
    
    func update() {
        imgView.image = soundEffect.iconImg
    }
}
