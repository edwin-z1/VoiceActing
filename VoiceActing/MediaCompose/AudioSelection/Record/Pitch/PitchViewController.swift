//
//  PitchViewController.swift
//  kuso
//
//  Created by blurryssky on 2018/7/2.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class PitchViewController: BaseViewController {
    
    var mediaBrick: MediaBrick! {
        didSet {
            update()
        }
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var bottomView: UIView!
    fileprivate lazy var audioToolView: AudioToolView = {
        let audioToolView = AudioToolView.ks.instantiateFromNib
        return audioToolView
    }()
    
    fileprivate let bag = DisposeBag()
    fileprivate let items =
        [(PitchType.mute, #imageLiteral(resourceName: "ev_audio_mute"), "静音"),
         (PitchType.original, #imageLiteral(resourceName: "ev_audio_original"), "原声"),
         (PitchType.monster, #imageLiteral(resourceName: "ev_audio_monster"), "怪兽"),
         (PitchType.papi, #imageLiteral(resourceName: "ev_audio_papi"), "papi"),
         (PitchType.transformer, #imageLiteral(resourceName: "ev_audio_transformer"), "变形金刚"),
         (PitchType.robot, #imageLiteral(resourceName: "ev_audio_robot"), "机器人")]
        .map { (tuple) -> PitchItem in
            let (pitchType, img, title) = tuple
            return PitchItem(pitchType: pitchType, img: img, title: title)
        }
    
    override var naviBarStyle: NavigationBarStyle {
        return .clear
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        Observable<[PitchItem]>.from(optional: items)
            .bind(to: collectionView.rx.items(cellIdentifier: PitchCollectionCell.ks.string, cellType: PitchCollectionCell.self))  { (index, item, cell) in
                cell.audioProcessItem = item
            }
            .disposed(by: bag)
        
        collectionView.rx.modelSelected(PitchItem.self)
            .subscribe(onNext: { [unowned self] (pitchItem) in
                self.mediaBrick.pitchType = pitchItem.pitchType
                self.mediaBrick.isNeedCompose = true
            })
            .disposed(by: bag)
        
        bottomView.addSubview(audioToolView)
        audioToolView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
    }
    
    func update() {
        if let index = items.index(where: { $0.pitchType == mediaBrick.pitchType }) {
            collectionView?.selectItem(at: [0, index], animated: true, scrollPosition: .right)
        }
        
        audioToolView.mediaBrick = mediaBrick
    }
}
