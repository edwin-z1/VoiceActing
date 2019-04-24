//
//  AudioSoundEffectView.swift
//  VoiceActing
//
//  Created by blurryssky on 2019/4/23.
//  Copyright © 2019 blurryssky. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class SoundEffectView: UIView {
    
    var viewModel: MediaComposeViewModel!

    @IBOutlet weak var layout: UICollectionViewFlowLayout!
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var soundEffectsVariable = Variable<[SoundEffect]>([])
    private var audioPlayer: AVPlayer?
    
    private let bag = DisposeBag()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let hInset = layout.sectionInset.left + layout.sectionInset.right
        let hCount: CGFloat = 6
        let spacing = bs.width - hInset - (layout.itemSize.width * hCount)
        let interitemSpacing = spacing/(hCount - 1)
        layout.minimumInteritemSpacing = interitemSpacing
        layout.sectionInset = UIEdgeInsets(top: 15, left: 10, bottom: 5.adaptHeight, right: 10)
    }
}

private extension SoundEffectView {
    
    func setup() {
        
        let cellNameString = SoundEffectCollectionCell.bs.string
        collectionView.register(UINib(nibName: cellNameString, bundle: nil), forCellWithReuseIdentifier: cellNameString)
        
        soundEffectsVariable.asObservable()
            .bind(to: collectionView.rx.items(cellIdentifier: cellNameString, cellType: SoundEffectCollectionCell.self))  { (idx, soundEffect, cell) in
                cell.soundEffect = soundEffect
            }
            .disposed(by: bag)
        
        collectionView.rx.modelSelected(SoundEffect.self)
            .subscribe(onNext: { [unowned self] (soundEffect) in
                self.audioPlayer = AVPlayer(url: soundEffect.fileUrl)
                self.audioPlayer?.play()
                
                self.viewModel.addSoundEffectItem(soundEffect)
            })
            .disposed(by: bag)
        
        soundEffectsVariable.value = (0...17).map { idx -> SoundEffect in
            let name = "sf_\(idx)"
            let img = UIImage(named: name)
            let fileUrl = Bundle.main.url(forResource: name, withExtension: "mp3")
            return SoundEffect(iconImg: img, fileUrl: fileUrl)
        }
    }
}
