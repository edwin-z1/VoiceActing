//
//  ChooseMusicTableCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/5.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

import RxSwift

class MusicTableCell: UITableViewCell {
    
    var music: BackgroundMusicListResponse.Music! {
        didSet {
            update()
        }
    }

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var separatorView: UIView!
    
    @IBOutlet weak var constraintTitleLabelTop: NSLayoutConstraint!
    @IBOutlet weak var constraintTitleLabelBottom: NSLayoutConstraint!
    
    var reuseBag = DisposeBag()
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        titleLabel.textColor = selected ? #colorLiteral(red: 1, green: 0.06274509804, blue: 0.8470588235, alpha: 1) : #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        
        updateImg()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imgView.layer.removeAllAnimations()
        music.cell = nil
    }
}

private extension MusicTableCell {
    
    func update() {
        
        music.cell = self
        
        switch music.bgmType {
        case .mediaLibrary:
            
            titleLabel.text = "本地音乐"
            constraintTitleLabelTop.constant = 24
            constraintTitleLabelBottom.constant = 24
            separatorView.isHidden = false
            imgView.image = #imageLiteral(resourceName: "cell_indicator")
            
        case .normal:
            
            titleLabel.text = music.name
            constraintTitleLabelTop.constant = 12
            constraintTitleLabelBottom.constant = 12
            separatorView.isHidden = true
            
        default:
            return
        }
        
        updateImg()
    }
    
    func updateImg() {
        guard let downloadItem = music.downloadItem else {
            return
        }
        imgView.layer.removeAllAnimations()
        switch downloadItem.status! {
        case .downloaded:
            if isSelected {
                imgView.image = #imageLiteral(resourceName: "choose_music_select.png")
            } else {
                imgView.image = nil
            }
        case .notDownload:
            imgView.image = #imageLiteral(resourceName: "choose_music_download")
            updateDownloadItem()
        case .downloading:
            updateDownloadItem()
        }
    }
    
    func updateDownloadItem() {
        reuseBag = DisposeBag()
        
        guard let downloadItem = music.downloadItem else {
            return
        }
        
        downloadItem.progressVariable.asObservable()
            .filter{ $0 != 0 && $0 != 1 }
            .subscribe(onNext: { [weak self] (_) in
                self?.addRotationAnimation()
            })
            .disposed(by: reuseBag)
        
        downloadItem.fileUrlVariable.asObservable()
            .filter{ $0 != nil }
            .subscribe(onNext: { [weak self] (_) in
                self?.updateImg()
            })
            .disposed(by: reuseBag)
    }
    
    func addRotationAnimation() {
        
        guard imgView.layer.animation(forKey: "rotation") == nil else {
            return
        }
        
        imgView.image = #imageLiteral(resourceName: "choose_music_downloading")
        
        let rotationBasic = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationBasic.toValue = 2 * Float.pi
        rotationBasic.duration = 1.0
        rotationBasic.repeatCount = Float.greatestFiniteMagnitude
        rotationBasic.isRemovedOnCompletion = false
        rotationBasic.fillMode = kCAFillModeForwards
        imgView.layer.add(rotationBasic, forKey: "rotation")
    }
}

