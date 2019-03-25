//
//  MusicSelectionCollectionCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/11/6.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift

class MusicSelectionCollectionCell: UICollectionViewCell {
    
    var idx: Int = 0
    var music: BackgroundMusicListResponse.Music! {
        didSet {
            update()
        }
    }
    
    @IBOutlet weak var defaultImgView: UIImageView!
    @IBOutlet weak var normalImgView: UIImageView!
    
    @IBOutlet weak var selectedImgView: UIImageView! {
        didSet {
            let scale = CGFloat(90)/70
            selectedImgView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
    fileprivate lazy var selectedLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.4)
        shapeLayer.lineWidth = 10
        return shapeLayer
    }()
    
    @IBOutlet weak var downloadCircleSlider: CircleSlider! {
        didSet {
            downloadCircleSlider.maximunTrackTintColors = [#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.1) ,#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.1)]
            downloadCircleSlider.minimunTrackTintColors = [#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)]
            downloadCircleSlider.lineWidth = 1
            downloadCircleSlider.isUserInteractionEnabled = false
        }
    }
    @IBOutlet weak var downloadProgressLabel: UILabel!
    @IBOutlet weak var raceLampView: BSRaceLampView! {
        didSet {
            raceLampView.font = UIFont(name: "PingFangSC-Semibold", size: 11) ?? UIFont.boldSystemFont(ofSize: 11)
            raceLampView.stayTimeInterval = 1
        }
    }
    
    fileprivate var reuseBag = DisposeBag()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        clean()
//        layer.addSublayer(selectedLayer)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        clean()
        reuseBag = DisposeBag()
    }
    
//    override func layoutSubviews() {
//        super.layoutSubviews()
//
//        let bigCirclePath = UIBezierPath(arcCenter: CGPoint(x: ks.width/2, y: ks.height/2), radius: ks.width/2 - 5, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
//        selectedLayer.path = bigCirclePath.cgPath
//    }
    
//    override var isSelected: Bool {
//        didSet {
//            clean()
//            update()
//        }
//    }
}

private extension MusicSelectionCollectionCell {
    
    func clean() {
        defaultImgView.isHidden = true
        normalImgView.alpha = 0
        selectedImgView.alpha = 0
        selectedLayer.opacity = 0
        downloadCircleSlider.alpha = 0
        raceLampView.alpha = 0
        raceLampView.velocity = 0
    }
    
    func update() {
        music.cell = self
        
        switch music.bgmType {
        case .default:
            defaultImgView.isHidden = false
            
        case .mediaLibrary:
            normalImgView.alpha = 1
            normalImgView.image = #imageLiteral(resourceName: "ev_music_selection_local")
            
        case .normal:
            
            if idx >= 0 {
                
                let imgName = "ev_seletion_music_\(idx%12)"
                let img = UIImage(named: imgName)
                normalImgView.alpha = 1
                normalImgView.image = img
//                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
//                    if self.isSelected {
//                        let cropImg = img?.ks.cropToRect(CGRect(x: 10, y: 0, width: 70, height: 70), radius: 35)
//                        self.selectedImgView.image = cropImg
//                        self.selectedImgView.alpha = 1
//                        self.selectedLayer.opacity = 1
//                    } else {
//                        self.normalImgView.alpha = 1
//                        self.normalImgView.image = img
//                    }
//                }, completion: nil)
            }
            
            raceLampView.text = music.name
            raceLampView.alpha = 1
            music.isPlayingVariable.asObservable()
                .subscribe(onNext: { [unowned self] (isPlaying) in
                    self.raceLampView.velocity = isPlaying ? 30 : 0
                })
                .disposed(by: reuseBag)
            
            self.updateDownloadItem()
            
        default:
            break
        }
    }
    
    func updateDownloadItem() {
        guard let downloadItem = music.downloadItem,
            downloadItem.status! != .downloaded else {
            return
        }
        
        downloadItem.progressVariable.asObservable()
            .skip(1)
            .filter{ $0 != 1 }
            .subscribe(onNext: { [weak self] (progress) in
                guard let `self` = self else { return }
                UIView.animate(withDuration: 0.25, delay: 0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                    self.downloadCircleSlider.alpha = 1
                    self.raceLampView.alpha = 0
                }, completion: nil)
                
                self.update(progress: progress)
            })
            .disposed(by: reuseBag)
        
        downloadItem.fileUrlVariable.asObservable()
            .filter{ $0 != nil }
            .subscribe(onNext: { [weak self] (fileUrl) in
                guard let `self` = self else { return }
                UIView.animate(withDuration: 0.25, delay: 0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                    self.downloadCircleSlider.alpha = 0
                    self.raceLampView.alpha = 1
                }, completion: nil)
            })
            .disposed(by: reuseBag)
    }
    
    func update(progress: Double) {
        
        downloadCircleSlider.setValue(value: CGFloat(progress), animated: true)
        
        let formattedString = String(format: "%.0f%%", arguments: [progress * 100])
        let attributedString = NSMutableAttributedString(string: formattedString)
        if let font = UIFont(name: "DINAlternate-Bold", size: 11) {
            let range = (formattedString as NSString).range(of: "%")
            let targetRange = NSRange(location: range.location, length: formattedString.count - range.location)
            attributedString.addAttributes([NSAttributedStringKey.font : font], range: targetRange)
        }
        downloadProgressLabel.attributedText = attributedString
    }
}
