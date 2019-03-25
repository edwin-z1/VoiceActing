//
//  MusicViewController.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/5.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class MusicViewController: BaseViewController, BackgroundGradient {
    
    let confirmSubject = PublishSubject<(BackgroundMusicListResponse.Music, Float)>()

    var videoDuration: TimeInterval = 0

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var closeButton: HitExtendButton!
    @IBOutlet weak var confirmButton: HitExtendButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loudspeackerButton: HitExtendButton!
    @IBOutlet weak var volumeSlider: AnimationSlider! {
        didSet {
            volumeSlider.thumbImage = #imageLiteral(resourceName: "choose_music_volume_point")
            volumeSlider.thumbExtendRespondsRadius = 20
            volumeSlider.minimunTrackTintColors = [#colorLiteral(red: 1, green: 0.06274509804, blue: 0.8470588235, alpha: 1), #colorLiteral(red: 1, green: 0.3137254902, blue: 0.2588235294, alpha: 1)]
            volumeSlider.maximunTrackTintColors = [#colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.06)]
            volumeSlider.value = 1
        }
    }
    @IBOutlet weak var selectedMusicName: UILabel!
    
    @IBOutlet weak var constraintBottomViewHeight: NSLayoutConstraint!
    
    fileprivate var musics: [BackgroundMusicListResponse.Music] = []
    fileprivate var selectedMusic: BackgroundMusicListResponse.Music?

    fileprivate let bag = DisposeBag()
    fileprivate var player: AVPlayer?
    
    override var naviBarStyle: NavigationBarStyle {
        return .hidden
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeEditCell()
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        selectedMusic = nil
    }
}

private extension MusicViewController {
    
    func setup() {
        constraintBottomViewHeight.constant = 50 + App.safeAreaBottomInset
        insertVerticalGradient(colors: [#colorLiteral(red: 0.1960784314, green: 0.1960784314, blue: 0.1960784314, alpha: 1).cgColor,#colorLiteral(red: 0.07058823529, green: 0.07058823529, blue: 0.07058823529, alpha: 1).cgColor], at: contentView)
        setupButtonsAndSlider()
        requestMusic()
    }
    
    func setupButtonsAndSlider() {
        closeButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.dismiss(animated: true, completion: nil)
                self.player?.pause()
            })
            .disposed(by: bag)
        
        confirmButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.dismiss(animated: true, completion: nil)
                self.player?.pause()
                
                self.selectedMusic?.asset = self.player?.currentItem?.asset
                if let music = self.selectedMusic {
                    self.confirmSubject.onNext((music, Float(self.volumeSlider.value)))
                }
            })
            .disposed(by: bag)
        
        loudspeackerButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.loudspeackerButton.isSelected = !self.loudspeackerButton.isSelected
                if self.loudspeackerButton.isSelected {
                    self.loudspeackerButton.setImage(#imageLiteral(resourceName: "choose_music_volume_close"), for: .normal)
                    self.player?.volume = 0
                } else {
                    self.loudspeackerButton.setImage(#imageLiteral(resourceName: "choose_music_volume"), for: .normal)
                    self.player?.volume = Float(self.volumeSlider.value)
                }
            })
            .disposed(by: bag)
        
        volumeSlider.rx.value
            .skip(1)
            .subscribe(onNext: { [unowned self] (value) in
                self.player?.volume = Float(value)
                
                var img = #imageLiteral(resourceName: "choose_music_volume_close")
                if value != 0 {
                    img = #imageLiteral(resourceName: "choose_music_volume")
                }
                self.loudspeackerButton.setImage(img, for: .normal)

            })
            .disposed(by: bag)
        
        NotificationCenter.default.rx.notification(Notification.Name.AVPlayerItemDidPlayToEndTime)
            .subscribe(onNext: { [unowned self] (noti) in
                guard let item = noti.object as? AVPlayerItem,
                    item == self.player?.currentItem else {
                        return
                }
                self.player?.seek(to: kCMTimeZero)
                self.player?.play()
            })
            .disposed(by: bag)
    }
    
    func requestMusic() {
        
        KusoNetworking.backgroundMusicList { [weak self] (response) in
            guard let `self` = self else { return }
            if let list = response?.data?.list {
                self.handleBgmMusic(list)
            }
        }
    }
    
    func handleBgmMusic(_ list: [BackgroundMusicListResponse.Music]) {
        
        var models = list
        
        let mediaLibraryMusic = BackgroundMusicListResponse.Music()
        mediaLibraryMusic.bgmType = .mediaLibrary
        mediaLibraryMusic.name = "本地音乐"
        
        models.insert(contentsOf: [mediaLibraryMusic], at: 0)
        
        musics = models
        tableView.reloadData()
    }
    
    func playMusic(_ music: BackgroundMusicListResponse.Music?) {
        
        if music?.bgmType == .normal {
            guard selectedMusic != music else {
                return
            }
        }
        selectedMusic = music
        
        selectedMusicName.text = music?.name

        player?.pause()
        player = nil
        
        if let music = music,
            let fileUrl = music.fileUrl {
            player = AVPlayer(url: fileUrl)
            player?.volume = Float(volumeSlider.value)
            player?.play()
            
        }
        
        updateEditCell(music)
    }
    
    func updateEditCell(_ music: BackgroundMusicListResponse.Music?) {
        
        tableView.beginUpdates()
        
        let editMusicIndex = musics.index { (music) -> Bool in
            return music.bgmType == .edit
        }
        
        if let editMusicIndex = editMusicIndex {
            musics.remove(at: editMusicIndex)
            tableView.deleteRows(at: [[0, editMusicIndex]], with: .left)
        }
        
        if let music = music {
            
            if let currentIndex = musics.index(of: music) {
                let insertIndex = currentIndex + 1
                
                let editMusic = BackgroundMusicListResponse.Music()
                editMusic.bgmType = .edit
                editMusic.fileUrl = music.fileUrl
                
                musics.insert(editMusic, at: insertIndex)
                tableView.insertRows(at: [[0, insertIndex]], with: .left)
            }
        }
        tableView.endUpdates()
    }
    
    func removeEditCell() {
        tableView.beginUpdates()
        
        let editMusicIndex = musics.index { (music) -> Bool in
            return music.bgmType == .edit
        }
        
        if let editMusicIndex = editMusicIndex {
            musics.remove(at: editMusicIndex)
            tableView.deleteRows(at: [[0, editMusicIndex]], with: .left)
        }
        tableView.endUpdates()
    }
}

extension MusicViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return musics.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let music = musics[indexPath.row]
        switch music.bgmType {
        case .default: fallthrough
        case .mediaLibrary: fallthrough
        case .normal:
            let cell = tableView.dequeueReusableCell(withIdentifier: MusicTableCell.ks.string) as! MusicTableCell
            cell.music = music
            return cell
        case .edit:
            let cell = tableView.dequeueReusableCell(withIdentifier: MusicEditTableCell.ks.string) as! MusicEditTableCell
            cell.videoDuration = videoDuration
            cell.music = music
            cell.player = player
            return cell
        }
    }
}

extension MusicViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let music = musics[indexPath.row]
        switch music.bgmType {
        case .default:
            break
        case .mediaLibrary:
            _ = AuthorizationManager.requestMediaLibraryAuthorization()
                .subscribe(onNext: { [unowned self] (isGranted) in
                    let pickerController = MPMediaPickerController(mediaTypes: .music)
                    pickerController.delegate = self
                    self.present(pickerController, animated: true, completion: nil)
                })
        case .normal:
            handleSelectNormalMusic(music)
        case .edit:
            tableView.selectRow(at: [0, indexPath.row - 1], animated: true, scrollPosition: .none)
        }
    }
    
    func handleSelectNormalMusic(_ music: BackgroundMusicListResponse.Music) {
        guard let downloadItem = music.downloadItem else {
            return
        }
        switch downloadItem.status! {
        case .downloaded:
            if let fileUrl = downloadItem.fileUrlVariable.value {
                music.fileUrl = fileUrl
                playMusic(music)
            }
        case .notDownload:
            
            MediaDownloader.shared.download(type: .music, item: downloadItem)
                .subscribe(onNext: { [weak self] (fileUrl) in
                    music.fileUrl = fileUrl
                    self?.playMusic(music)
                    }, onError: { [weak self] (error) in
                        guard let `self` = self else { return }
                        UIView.ks.showToast(self.view, title: error.localizedDescription)
                })
                .disposed(by: bag)
        case .downloading:
            break
        }
    }
}

extension MusicViewController: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        
        if let item = mediaItemCollection.items.last {
            if let fileUrl = item.assetURL {
                
                let mediaLibrary = musics.first!
                mediaLibrary.name = item.title
                mediaLibrary.fileUrl = fileUrl
                playMusic(mediaLibrary)
                
                mediaPicker.dismiss(animated: true, completion: nil)
                
            } else {
                
                UIView.ks.showToast(mediaPicker.view, title: "该音乐受版权保护，无法使用")
                playMusic(nil)
            }
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        if let selectedMusic = selectedMusic,
            let idx = musics.index(of: selectedMusic) {
            tableView.selectRow(at: [0, idx], animated: true, scrollPosition: .none)
        }
        mediaPicker.dismiss(animated: true, completion: nil)
    }
}
