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

enum AudioSelectionType: String {
    case record = "录音"
    case soundEffect = "音效"
}

class AudioSelectionView: UIView {

    var viewModel: MediaComposeViewModel! {
        didSet {
            recordView.viewModel = viewModel
            soundEffectView.viewModel = viewModel
        }
    }
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var selectionCollectionView: UICollectionView!
    private let selectedIndexPathVariable: Variable<IndexPath> = Variable([0, 0])
    
    private let recordView = RecordView.bs.instantiateFromNib
    private let soundEffectView = SoundEffectView.bs.instantiateFromNib
    private weak var displayingSubview: UIView?
    
    private let bag = DisposeBag()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let layout = selectionCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let insetX = bs.width/2 - layout.itemSize.width/2
        layout.sectionInset = UIEdgeInsets(top: 0, left: insetX, bottom: 0, right: insetX)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let displayingSubview = displayingSubview {
            let isContain = displayingSubview.frame.contains(point) || selectionCollectionView.frame.contains(point)
            return isContain
        } else {
            return super.point(inside: point, with: event)
        }
    }
}

private extension AudioSelectionView {
    
    func setup() {
        
        setupSubview()
        
        selectedIndexPathVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (idxPath) in
                self.selectionCollectionView.selectItem(at: idxPath, animated: true, scrollPosition: .centeredHorizontally)
                self.updateContentView()
            })
            .disposed(by: bag)
        
        Observable.of([AudioSelectionType.record, AudioSelectionType.soundEffect])
            .bind(to: selectionCollectionView.rx.items(cellIdentifier: AudioSelectionCollectionCell.bs.string, cellType: AudioSelectionCollectionCell.self))  { (idx, type, cell) in
                cell.type = type
            }
            .disposed(by: bag)
        
        selectionCollectionView.rx.itemSelected
            .subscribe(onNext: { [unowned self] (indexPath) in
                self.selectedIndexPathVariable.value = indexPath
            })
            .disposed(by: bag)

        selectionCollectionView.rx.willDisplayCell
            .take(1)
            .delay(0.1, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (cell, indexPath) in
                guard let `self` = self else { return }
                self.selectedIndexPathVariable.value = indexPath
            })
            .disposed(by: bag)
    }
    
    func setupSubview() {
        [recordView, soundEffectView].forEach {
            $0.alpha = 0
            self.contentView.addSubview($0)
        }
        recordView.snp.makeConstraints { (maker) in
            maker.size.equalTo(CGSize(width: 90, height: 90))
            maker.centerX.equalToSuperview()
            maker.bottom.equalToSuperview().offset(-5)
        }
        
        soundEffectView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
    }
    
    func updateContentView() {
        
        displayingSubview?.alpha = 0
        switch selectedIndexPathVariable.value.item {
        case 0:
            displayingSubview = recordView
        case 1:
            displayingSubview = soundEffectView
        default:
            return
        }
        UIView.bs.animate(content: {
            self.displayingSubview?.alpha = 1
        })
    }
}
