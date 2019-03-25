//
//  SoundEffectViewController.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/13.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class SoundEffectViewController: BaseViewController {
    
    let confirmSubject = PublishSubject<Void>()
    let playSoundEffectSubject = PublishSubject<SoundEffectListResponse.SoundEffect>()

    @IBOutlet weak var closeButton: HitExtendButton!
    @IBOutlet weak var groupCollectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBOutlet weak var constraintCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet weak var constraintCollectionViewBottom: NSLayoutConstraint!
    
    fileprivate let bag = DisposeBag()
    fileprivate var audioPlayer: AVPlayer?
    
    fileprivate var groupCount = 18
    fileprivate var soundEffectGroupVariable: Variable<[[SoundEffectListResponse.SoundEffect]]> = Variable([])

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        handleClose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = UIColor.clear
        constraintCollectionViewBottom.constant = App.bottomBarHeight
        setupCloseButton()
        setupCollectionView()
        requestSoundEffect()
    }
}

private extension SoundEffectViewController {
    
    func setupCloseButton() {
        closeButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.handleClose()
            })
            .disposed(by: bag)
    }
    
    func handleClose() {
        confirmSubject.onNext(())
        audioPlayer?.pause()
        dismiss(animated: true, completion: nil)
    }
    
    func setupCollectionView() {
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        let groupLayout = groupCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let hInset: CGFloat = 15 + 15
        let vInset: CGFloat = 25 + 15
        let hCount: CGFloat = 6
        let vCount = CGFloat(groupCount)/hCount
        let totalWidth = view.ks.width - hInset - 45 * hCount
        let interitemSpacing = totalWidth/(hCount - 1)
        let height = vInset + 45 * vCount + interitemSpacing * (vCount - 1)
        constraintCollectionViewHeight.constant = height
        
        groupLayout.itemSize = CGSize(width: view.ks.width, height: height)
        
        soundEffectGroupVariable.asObservable()
            .bind(to: groupCollectionView.rx.items(cellIdentifier: SoundEffectGroupCollectionCell.ks.string, cellType: SoundEffectGroupCollectionCell.self))  { [weak self] (idx, soundEffects, cell) in
                guard let `self` = self else { return }
                cell.interitemSpacing = interitemSpacing
                cell.soundEffectsVariable.value = soundEffects
                cell.didSelectClosure = { [unowned self] sd in
                    self.handleSelectSoundEffect(sd)
                }
            }
            .disposed(by: bag)
        
        groupCollectionView.rx.didEndDecelerating
            .subscribe(onNext: { [weak self] (_) in
                guard let `self` = self else { return }
                let idx = Int(self.groupCollectionView.contentOffset.x/self.groupCollectionView.ks.width)
                self.pageControl.currentPage = idx
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
                UIView.ks.showToast(self.view, title: error.localizedDescription)
            })
            .disposed(by: bag)
        
        _ = downloadItem.fileUrlVariable.asObservable()
            .subscribe(onNext: { [weak self] (fileUrl) in
                guard let `self` = self,
                    let fileUrl = fileUrl else {
                        return
                }
                soundEffect.fileUrl = fileUrl
                
                self.playSoundEffectSubject.onNext(soundEffect)
                self.audioPlayer = AVPlayer(url: fileUrl)
                self.audioPlayer?.play()
            })
    }
    
    func requestSoundEffect() {
        KusoNetworking.soundEffectList { [weak self] (response) in
            guard let `self` = self else { return }
            if let list = response?.data?.list {
                let groups = list.split(whereSeparator: { (soundEffect) -> Bool in
                    if let idx = list.index(of: soundEffect),
                        idx != 0 {
                        return idx%(self.groupCount + 1) == 0
                    } else {
                        return false
                    }
                })
                self.pageControl.numberOfPages = groups.count
                self.soundEffectGroupVariable.value = groups.map { Array($0) }
            }
        }
    }
}
