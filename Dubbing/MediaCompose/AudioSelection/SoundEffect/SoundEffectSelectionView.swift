//
//  SoundEffectSelectionView.swift
//  Kuso
//
//  Created by blurryssky on 2018/11/2.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class SoundEffectSelectionView: UIView {
    
    let cancelSubject = PublishSubject<Void>()
    let confirmSubject = PublishSubject<Void>()
    let playSoundEffectSubject = PublishSubject<SoundEffectListResponse.SoundEffect>()

    @IBOutlet weak var moreButton: HitExtendButton!
    @IBOutlet weak var confirmButton: HitExtendButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate let bag = DisposeBag()
    fileprivate var player: AVPlayer?
    
    fileprivate var soundEffectsVariable = Variable<[SoundEffectListResponse.SoundEffect]>([])
    fileprivate var currentSoundEffect: SoundEffectListResponse.SoundEffect! {
        didSet {
            if currentSoundEffect.isDefaultItem {
                confirmButton.isHidden = true
                cancelSubject.onNext(())
            } else {
                confirmButton.isHidden = false
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
        requestSoundEffect()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let insetX = ks.width/2 - layout.itemSize.width/2
        layout.sectionInset = UIEdgeInsetsMake(0, insetX, 0, insetX)
    }
}

private extension SoundEffectSelectionView {
    
    func setup() {
        
        let defaultSoundEffect = SoundEffectListResponse.SoundEffect()
        defaultSoundEffect.isDefaultItem = true
        currentSoundEffect = defaultSoundEffect
        soundEffectsVariable.value = [defaultSoundEffect]
        
        let nameString = SoundEffectSelectionCollectionCell.ks.string
        collectionView.register(UINib(nibName: nameString, bundle: nil), forCellWithReuseIdentifier: nameString)
        
        soundEffectsVariable.asObservable()
            .bind(to: collectionView.rx.items(cellIdentifier: nameString, cellType: SoundEffectSelectionCollectionCell.self))  { (idx, soundEffect, cell) in
                cell.soundEffect = soundEffect
            }
            .disposed(by: bag)
        
        collectionView.rx.itemSelected
            .subscribe(onNext: { [unowned self] (indexPath) in
                self.collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
                let soundEffect = self.soundEffectsVariable.value[indexPath.item]
                self.currentSoundEffect = soundEffect
                
                self.handleSelectSoundEffect(soundEffect)
            })
            .disposed(by: bag)

        confirmButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.confirmSubject.onNext(())
            })
            .disposed(by: bag)
    }
    
    func handleSelectSoundEffect(_ soundEffect: SoundEffectListResponse.SoundEffect) {
        guard let downloadItem = soundEffect.downloadItem else {
            return
        }
        MediaDownloader.shared.download(type: .music, item: downloadItem)
            .subscribe(onError: { [weak self] (error) in
                guard let `self` = self else { return }
                UIView.ks.showToast(self, title: error.localizedDescription)
            })
            .disposed(by: bag)
        
        _ = downloadItem.fileUrlVariable.asObservable()
            .subscribe(onNext: { [weak self] (fileUrl) in
                guard let `self` = self,
                    let fileUrl = fileUrl else {
                        return
                }
                soundEffect.fileUrl = fileUrl
                
                guard self.currentSoundEffect == soundEffect else { return }
                self.playSoundEffectSubject.onNext(soundEffect)
                self.player = AVPlayer(url: fileUrl)
                self.player?.play()
            })
    }
    
    func requestSoundEffect() {
        KusoNetworking.soundEffectList { [weak self] (response) in
            guard let `self` = self else { return }
            if var list = response?.data?.list {
                let maxShowCount = App.systemSetting.mediaSetting.soundShowCount
                if maxShowCount != 0 {
                    list = Array(list[0...(min(maxShowCount, list.count) - 1)])
                }
                self.soundEffectsVariable.value.append(contentsOf: list)
            }
        }
    }
}
