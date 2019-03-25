//
//  SoundEffectGroupCollectionCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/13.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class SoundEffectGroupCollectionCell: UICollectionViewCell {
    
    var didSelectClosure: ((SoundEffectListResponse.SoundEffect)->Void)!
    var interitemSpacing: CGFloat = 0 {
        didSet {
            let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
            layout.minimumInteritemSpacing = interitemSpacing
            layout.minimumLineSpacing = interitemSpacing
        }
    }
    var soundEffectsVariable: Variable<[SoundEffectListResponse.SoundEffect]> = Variable([])
    
    @IBOutlet weak var collectionView: UICollectionView!
    fileprivate let bag = DisposeBag()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCollectionView()
    }
}

private extension SoundEffectGroupCollectionCell {
    
    func setupCollectionView() {
        soundEffectsVariable.asObservable()
            .bind(to: collectionView.rx.items(cellIdentifier: SoundEffectCollectionCell.ks.string, cellType: SoundEffectCollectionCell.self))  { (idx, soundEffect, cell) in
                cell.soundEffect = soundEffect
        }
        .disposed(by: bag)
        
        collectionView.rx.modelSelected(SoundEffectListResponse.SoundEffect.self)
            .subscribe(onNext: { [unowned self] (soundEffect) in
                self.didSelectClosure(soundEffect)
            })
            .disposed(by: bag)
    }
}
