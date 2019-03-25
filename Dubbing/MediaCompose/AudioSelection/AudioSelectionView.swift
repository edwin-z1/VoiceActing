//
//  AudioSelectionView.swift
//  Kuso
//
//  Created by blurryssky on 2018/10/31.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class AudioSelectionView: UIView {

    lazy var recordView: AudioRecordView = {
        let record = AudioRecordView.ks.instantiateFromNib
        record.alpha = 0
        return record
    }()
    
    lazy var musicSelectionView: MusicSelectionView = {
        let music = MusicSelectionView.ks.instantiateFromNib
        music.alpha = 0
        return music
    }()
    
    lazy var soundEffectSelectionView: SoundEffectSelectionView = {
        let soundEffect = SoundEffectSelectionView.ks.instantiateFromNib
        soundEffect.alpha = 0
        return soundEffect
    }()
    
    let selectionChangedSubject = PublishSubject<Int>()
    
    let bag = DisposeBag()
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate let selectionVariable: Variable<[String]> = Variable([])
    fileprivate lazy var contentSubviews: [UIView] = {
        let subviews = App.systemSetting.mediaSetting.sort.compactMap { id -> UIView? in
            switch id {
            case 0: return recordView
            case 1: return musicSelectionView
            case 2: return soundEffectSelectionView
            default:
                return nil
            }
        }
        return subviews
    }()
    
    fileprivate var currentIndexPath: IndexPath! {
        didSet {
            guard currentIndexPath != oldValue else {
                return
            }
            recordView.isRecordVariable.value = false
            selectionChangedSubject.onNext(currentIndexPath.item)
            collectionView.selectItem(at: currentIndexPath, animated: true, scrollPosition: .centeredHorizontally)
            updateContentView()
        }
    }
    fileprivate var currentDisplayView: UIView?
    
    deinit {
        print("\(description) deinit")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let insetX = ks.width/2 - layout.itemSize.width/2
        layout.sectionInset = UIEdgeInsetsMake(0, insetX, 0, insetX)
    }
}

private extension AudioSelectionView {
    
    func setup() {
        
        contentSubviews.forEach {
            self.contentView.addSubview($0)
            $0.snp.makeConstraints({ (maker) in
                maker.edges.equalToSuperview()
            })
        }
        
        setupCollectionView()
    }
    
    func setupCollectionView() {
        
        collectionView.decelerationRate = 0.1
        
        let cellString = AudioSelectionCollectionCell.ks.string
        collectionView.register(UINib(nibName: cellString, bundle: nil), forCellWithReuseIdentifier: cellString)
        
        selectionVariable.value = App.systemSetting.mediaSetting.sort.compactMap { id -> String? in
            switch id {
            case 0: return "配音"
            case 1: return "音乐"
            case 2: return "音效"
            default:
                return nil
            }
        }
        selectionVariable.asObservable()
            .bind(to: collectionView.rx.items(cellIdentifier: cellString, cellType: AudioSelectionCollectionCell.self)) ({ (idx, string, cell) in
                cell.label.text = string
            })
            .disposed(by: bag)
        
        collectionView.rx.willDisplayCell
            .take(1)
            .delay(0.1, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (cell, indexPath) in
                guard let `self` = self else { return }
                self.currentIndexPath = indexPath
            })
            .disposed(by: bag)
        
        collectionView.rx.itemSelected
            .subscribe(onNext: { [unowned self] (indexPath) in
                self.currentIndexPath = indexPath
            })
            .disposed(by: bag)
        
        Observable.merge([collectionView.rx.didEndDragging.map{ _ in}, collectionView.rx.didEndDecelerating.map{ _ in}])
            .subscribe(onNext: { [weak self] (_) in
                guard let `self` = self else { return }
                let layout = self.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
                let offsetX = CGPoint(x: self.collectionView.contentOffset.x + layout.sectionInset.left + layout.itemSize.width/2, y: self.collectionView.ks.height/2)
                let last = self.collectionView.visibleCells.filter { return $0.frame.contains(offsetX) }.last
                guard let cell = last,
                    let indexPath = self.collectionView.indexPath(for: cell) else {
                        return
                }
                self.currentIndexPath = indexPath
            })
            .disposed(by: bag)
    }
    
    func updateContentView() {
        
        currentDisplayView?.alpha = 0
        let idx = currentIndexPath.item
        guard idx >= 0, idx < contentSubviews.count else {
            return
        }
        let subview = contentSubviews[idx]
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
            subview.alpha = 1
        }, completion: nil)
        currentDisplayView = subview
    }
}
