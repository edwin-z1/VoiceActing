//
//  MusicSelectionView.swift
//  Kuso
//
//  Created by blurryssky on 2018/11/2.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class MusicSelectionView: UIView {
    
    let cancelSubject = PublishSubject<Void>()
    let confirmSubject = PublishSubject<Void>()
    let playMusicSubject = PublishSubject<BackgroundMusicListResponse.Music>()

    @IBOutlet weak var moreButton: HitExtendButton!
    @IBOutlet weak var confirmButton: HitExtendButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate let bag = DisposeBag()
    fileprivate var player: AVPlayer?
    
    fileprivate var musicsVariable = Variable<[BackgroundMusicListResponse.Music]>([])
    fileprivate var currentMusic: BackgroundMusicListResponse.Music! {
        didSet {
            if currentMusic.bgmType == .default {
                confirmButton.isHidden = true
                cancelSubject.onNext(())
            } else {
                confirmButton.isHidden = false
            }
            
            if currentMusic != oldValue,
                oldValue != nil {
                player?.pause()
                oldValue.isPlayingVariable.value = false
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
        requestMusic()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let insetX = ks.width/2 - layout.itemSize.width/2
        layout.sectionInset = UIEdgeInsetsMake(0, insetX, 0, insetX)
    }
}

extension MusicSelectionView {
    
    func pauseMusic() {
        currentMusic.isPlayingVariable.value = false
        player?.pause()
    }
}

private extension MusicSelectionView {
    
    func setup() {
        
        let defaultMusic = BackgroundMusicListResponse.Music()
        defaultMusic.bgmType = .default
        currentMusic = defaultMusic
        
        let mediaLibrary = BackgroundMusicListResponse.Music()
        mediaLibrary.bgmType = .mediaLibrary
        
        musicsVariable.value = [defaultMusic, mediaLibrary]
        
        let nameString = MusicSelectionCollectionCell.ks.string
        collectionView.register(UINib(nibName: nameString, bundle: nil), forCellWithReuseIdentifier: nameString)
        
        musicsVariable.asObservable()
            .bind(to: collectionView.rx.items(cellIdentifier: nameString, cellType: MusicSelectionCollectionCell.self))  { (idx, music, cell) in
                cell.idx = idx - 2
                cell.music = music
            }
            .disposed(by: bag)
        
        collectionView.rx.itemSelected
            .subscribe(onNext: { [unowned self] (indexPath) in
                self.collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
                let music = self.musicsVariable.value[indexPath.item]
                self.currentMusic = music
                
                switch music.bgmType {
                case .mediaLibrary:
                    self.handleSelectMediaLibrary()
                case .normal:
                    self.handleSelectMusic(music)
                default:
                    break
                }
            })
            .disposed(by: bag)
        
        NotificationCenter.default.rx.notification(Notification.Name.AVPlayerItemDidPlayToEndTime)
            .subscribe(onNext: { [unowned self] (noti) in
                guard let item = noti.object as? AVPlayerItem,
                    item == self.player?.currentItem else {
                        return
                }
                self.currentMusic.isPlayingVariable.value = false
            })
            .disposed(by: bag)
        
        confirmButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.confirmSubject.onNext(())
            })
            .disposed(by: bag)
    }
    
    func handleSelectMediaLibrary() {
        _ = AuthorizationManager.requestMediaLibraryAuthorization()
            .subscribe(onNext: { [unowned self] (isGranted) in
                let pickerController = MPMediaPickerController(mediaTypes: .music)
                pickerController.delegate = self
                self.ks.nextViewController?.present(pickerController, animated: true, completion: nil)
            })
    }
    
    func handleSelectMusic(_ music: BackgroundMusicListResponse.Music) {
        guard let downloadItem = music.downloadItem else {
            return
        }
        
        MediaDownloader.shared.download(type: .music, item: downloadItem)
            .subscribe(onNext: { [weak self] (fileUrl) in
                guard let `self` = self else { return }
                music.fileUrl = fileUrl
                
                guard self.currentMusic == music else { return }
                self.playMusic(music)
                }, onError: { [weak self] (error) in
                    guard let `self` = self else { return }
                    UIView.ks.showToast(self, title: error.localizedDescription)
            })
            .disposed(by: bag)
    }
    
    func playMusic(_ music: BackgroundMusicListResponse.Music) {
        guard let fileUrl = music.fileUrl else { return }
        player = AVPlayer(url: fileUrl)
        player?.play()
        playMusicSubject.onNext(music)
        music.isPlayingVariable.value = true
    }
    
    func requestMusic() {
        KusoNetworking.backgroundMusicList { [weak self] (response) in
            guard let `self` = self else { return }
            if var list = response?.data?.list {
                let maxShowCount = App.systemSetting.mediaSetting.musicShowCount
                if maxShowCount != 0 {
                    list = Array(list[0...(min(maxShowCount, list.count) - 1)])
                }
                self.musicsVariable.value.append(contentsOf: list)
            }
        }
    }
}

extension MusicSelectionView: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        
        if let item = mediaItemCollection.items.last {
            if let fileUrl = item.assetURL {
                
                let mediaLibrary = musicsVariable.value[1]
                mediaLibrary.name = item.title
                mediaLibrary.fileUrl = fileUrl
                playMusic(mediaLibrary)
                
                mediaPicker.dismiss(animated: true, completion: nil)
                
            } else {
                UIView.ks.showToast(mediaPicker.view, title: "该音乐受版权保护，无法使用")
            }
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        cancelSubject.onNext(())
        mediaPicker.dismiss(animated: true, completion: nil)
    }
}
