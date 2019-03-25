//
//  SoundEffectCollectionCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/13.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

class SoundEffectCollectionCell: UICollectionViewCell {
    
    var soundEffect: SoundEffectListResponse.SoundEffect! {
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
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            layer.add(scaleAnimation, forKey: "scale")
        }
    }
}

private extension SoundEffectCollectionCell {
    
    func update() {
        guard let iconUrl = soundEffect.iconUrl else {
            return
        }
        imgView.kf.setImage(with: iconUrl)
    }
}
