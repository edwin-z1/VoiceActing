//
//  SoundEffectSelectionCollectionCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/11/5.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

class SoundEffectSelectionCollectionCell: UICollectionViewCell {

    var soundEffect: SoundEffectListResponse.SoundEffect! {
        didSet {
            update()
        }
    }
    
    @IBOutlet weak var defaultBgView: UIView!
    @IBOutlet weak var imgView: UIImageView!

    override func prepareForReuse() {
        super.prepareForReuse()
        imgView.kf.cancelDownloadTask()
        imgView.image = nil
    }
}

private extension SoundEffectSelectionCollectionCell {
    
    func update() {
        if soundEffect.isDefaultItem {
            defaultBgView.isHidden = false
            imgView.image = #imageLiteral(resourceName: "ev_sound_effect")
        } else {
            defaultBgView.isHidden = true
            guard let iconUrl = soundEffect.iconUrl else {
                return
            }
            imgView.kf.setImage(with: iconUrl)
        }
    }
}
