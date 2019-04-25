//
//  VideoControlView.swift
//  VoiceActing
//
//  Created by blurryssky on 2018/10/30.
//  Copyright © 2018 blurryssky. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class VideoControlView: UIView {
    
    static let collectionViewInsetTop: CGFloat = 25
    static let itemHeight: CGFloat = 60
    
    var viewModel: MediaComposeViewModel! {
        didSet {
            update()
        }
    }
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = false
        return scrollView
    }()
    
    private lazy var editView: MediaEditComponentView = {
        let editView = MediaEditComponentView.bs.instantiateFromNib
        editView.alpha = 0
        return editView
    }()
    
    private lazy var maskLayer: CALayer = {
        let maskLayer = CALayer()
        maskLayer.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        return maskLayer
    }()
    @IBOutlet weak var constraintLineHeight: NSLayoutConstraint!
    
    private var generator: AVAssetImageGenerator!
    private var timesVariable = Variable<[NSValue]>([])
    
    private let bag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let collectionViewInsetTop = VideoControlView.collectionViewInsetTop
        layout.sectionInset = UIEdgeInsets(top: collectionViewInsetTop, left: 0, bottom: bounds.height - collectionViewInsetTop - layout.itemSize.height, right: 0)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: bs.width/2, bottom: 0, right: bs.width/2)
        scrollView.frame = collectionView.frame
        scrollView.contentInset = collectionView.contentInset
    }
}

private extension VideoControlView {
    
    var isUserDidScrollObservable: Observable<Void> {
        return scrollView.rx.didScroll
            .filter{ [unowned self] in
                self.scrollView.contentSize.width != 0
            }
            .filter{ [unowned self] in
                self.scrollView.isTracking || self.scrollView.isDecelerating
        }
    }
    
    func setup() {
        
        constraintLineHeight.constant = 110.adaptHeight
        
        // 需要editView始终在collection cell上方，所以使用scrollView
        addSubview(scrollView)
        scrollView.rx.contentOffset
            .subscribe(collectionView.rx.contentOffset)
            .disposed(by: bag)
        scrollView.addSubview(editView)
        
        collectionView.register(VideoControlCollectionCell.self, forCellWithReuseIdentifier: VideoControlCollectionCell.bs.string)
        
        timesVariable
            .asObservable()
            .bind(to: collectionView.rx.items(cellIdentifier: VideoControlCollectionCell.bs.string, cellType: VideoControlCollectionCell.self))  { [weak self] (idx, timeValue, cell) in
                guard let `self` = self else { return }
                cell.generator = self.generator
                cell.timeValue = timeValue
            }
            .disposed(by: bag)
        
        collectionView.rx.willDisplayCell
            .take(1)
            .subscribe(onNext: { [unowned self] (cell, indexPath) in
                self.updateUIFromScrollViewContentSize()
            })
            .disposed(by: bag)
        
        isUserDidScrollObservable
            .subscribe(onNext: { [unowned self] (_) in
                self.updateViewModelPlayProgress()
                if let soundEffectItem = self.viewModel.replacingSoundEffectItem {
                    self.viewModel.updateItemSelected(soundEffectItem, isSelected: false)
                }
                self.viewModel.isPlayVariable.value = false
            })
            .disposed(by: bag)
        
        // 限制滑动区域
        scrollView.rx.didScroll
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] (_) in
                
                let insetX = self.scrollView.contentInset.left
                let startTime = self.viewModel.videoItem.editedStartTimeVariable.value
                let startValue = startTime/self.viewModel.videoDuration
                let minOffsetX = self.scrollView.contentSize.width * CGFloat(startValue) - insetX
                
                let endTime = self.viewModel.videoItem.editedEndTimeVariable.value
                let endValue = endTime/self.viewModel.videoDuration
                let maxOffsetX = self.scrollView.contentSize.width * CGFloat(endValue) - insetX
                
                let offsetX = self.scrollView.contentOffset.x
                if offsetX < minOffsetX {
                    self.scrollView.contentOffset = CGPoint(x: minOffsetX, y: 0)
                } else if offsetX > maxOffsetX {
                    self.scrollView.contentOffset = CGPoint(x: maxOffsetX, y: 0)
                }
            })
            .disposed(by: bag)
        
        let tap = UITapGestureRecognizer()
        tap.rx.event
            .subscribe(onNext: { [unowned self] (tap) in
                let location = tap.location(in: self)
                let videoItem = self.viewModel.videoItem!
                let isVideoItemSelected = videoItem.isSelectedVariable.value
                
                if location.y <= self.editView.frame.maxY {
                    self.viewModel.updateItemSelected(videoItem, isSelected: !isVideoItemSelected)
                } else if let selectedItem = self.viewModel.selectedItemVariable.value {
                    self.viewModel.updateItemSelected(selectedItem, isSelected: false)
                } else if let soundEffectItem = self.viewModel.replacingSoundEffectItem {
                    self.viewModel.updateItemSelected(soundEffectItem, isSelected: false)
                }
            })
            .disposed(by: bag)
        addGestureRecognizer(tap)
        
        editView.leftPan.rx.event
            .subscribe(onNext: { [unowned self] (pan) in
                
                switch pan.state {
                case .began:
                    self.viewModel.copyItemsBeforeEditVideo()
                case .changed:
                    self.viewModel.moveAudioItemsToRight()
                case .cancelled:fallthrough
                case .ended:
                    self.updateViewModelPlayProgress()
                default: break
                }
            })
            .disposed(by: editView.bag)
        
        editView.rightPan.rx.event
            .subscribe(onNext: { [unowned self] (pan) in
                
                switch pan.state {
                case .began:
                    self.viewModel.copyItemsBeforeEditVideo()
                case .changed:
                    self.viewModel.moveAudioItemsToLeft()
                case .cancelled:fallthrough
                case .ended:
                    self.updateViewModelPlayProgress()
                default: break
                }
            })
            .disposed(by: editView.bag)
    }
    
    func updateUIFromScrollViewContentSize() {
        let collectionViewContentWidth = collectionView.contentSize.width
        
        scrollView.contentSize = CGSize(width: collectionViewContentWidth, height: 0)
        
        viewModel.collectionViewContentWidth = collectionViewContentWidth
        
        let originX = -MediaEditComponentView.handleWidth
        let width = collectionViewContentWidth + MediaEditComponentView.handleWidth * 2
        editView.frame = CGRect(x: originX, y: 0, width: width, height: VideoControlView.collectionViewInsetTop + VideoControlView.itemHeight)
        
        collectionView.layer.mask = maskLayer
        maskLayer.frame = CGRect(x: 0, y: VideoControlView.collectionViewInsetTop, width: collectionViewContentWidth, height: VideoControlView.itemHeight)
    }
    
    func updateViewModelPlayProgress() {
        let insetX = scrollView.contentInset.left
        let offsetX = scrollView.contentOffset.x + insetX
        let progress = Double(offsetX/scrollView.contentSize.width)
        viewModel.updatePlayProgress(progress)
    }
}

private extension VideoControlView {
    
    var layout: UICollectionViewFlowLayout {
        return collectionView.collectionViewLayout as! UICollectionViewFlowLayout
    }
    
    func update() {
        updateTimesVariable()
        observeViewModel()
    }
    
    func updateTimesVariable() {
        
        let asset = viewModel.videoAsset!
        generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        
        let itemHeight: CGFloat = VideoControlView.itemHeight
        var itemWidth: CGFloat = itemHeight
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let renderSize = videoTrack.bs.renderSize
            let multiper = max(renderSize.width, renderSize.height)/720
            generator.maximumSize = renderSize.applying(.init(scaleX: 1/multiper, y: 1/multiper))
            
            let ratio = renderSize.width/renderSize.height
            itemWidth = floor(ratio * itemHeight)
        }
        // 设置item size
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        
        let timeIntervalForEachScreen: TimeInterval = 15
        let totalWidth = CGFloat(viewModel.videoDuration/timeIntervalForEachScreen) * UIScreen.main.bounds.width
        let imagesCount = Int(ceil(totalWidth/itemWidth))
        
        // 计算帧数信息
        let duration = asset.duration
        var each = duration.value/CMTimeValue(imagesCount)
        let startTime = CMTimeValue(Double(each) * 0.5)
        each = (duration.value - startTime)/CMTimeValue(imagesCount)
        let times = (0..<imagesCount).map { index -> NSValue in
            let value = startTime + each * CMTimeValue(index)
            let time = CMTime(value: value, timescale: duration.timescale)
            return NSValue(time: time)
        }
        
        timesVariable.value = times
    }
    
    func observeViewModel() {
        
        // - play
        viewModel.playProgressVariable.asObservable()
            .map { [unowned self] (progress) -> String in
                let time = self.viewModel.videoDuration * progress
                return time.bs.colonString
            }
            .bind(to: timeLabel.rx.text)
            .disposed(by: bag)
        
        viewModel.playProgressVariable.asObservable()
            .filter { [unowned self] _ in
                !(self.scrollView.isTracking || self.scrollView.isDecelerating)
            }
            .map { [unowned self] (progress) -> CGPoint in
                let insetX = self.scrollView.contentInset.left
                let offsetX = self.scrollView.contentSize.width * CGFloat(progress) - insetX
                return CGPoint(x: offsetX, y: 0)
            }
            .bind(to: scrollView.rx.contentOffset)
            .disposed(by: bag)
        
        // - video item
        let videoItem = viewModel.videoItem!
        editView.viewModel = viewModel
        editView.mediaItem = videoItem
        
        videoItem.isSelectedVariable.asObservable()
            .subscribe(onNext: { [unowned self] (isSelected) in
                if isSelected {
                    self.scrollView.bringSubviewToFront(self.editView)
                }
                
                UIView.bs.animate(content: {
                    self.editView.alpha = isSelected ? 1 : 0
                    self.timeLabel.alpha = isSelected ? 0 : 1
                })
            })
            .disposed(by: bag)
        
        videoItem.editedStartTimeVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (startTime) in
                self.updateOriginX()
                self.updateWidth()
            })
            .disposed(by: bag)
        
        videoItem.editedEndTimeVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (endTime) in
                self.updateWidth()
            })
            .disposed(by: bag)
        
        // - audio items
        viewModel.audioItemsVariable.asObservable()
            .skip(1)
            .subscribe(onNext: { [unowned self] (items) in
                
                let audioEditViews = self.scrollView.subviews.filter { $0 is AudioEditView } as! [AudioEditView]
                if audioEditViews.count < items.count {
                    self.addAudioEditView()
                } 
            })
            .disposed(by: bag)
        
        // -
        viewModel.selectedItemVariable.asObservable()
            .skip(1)
            .map { $0 != nil ? true : false }
            .bind(to: timeLabel.rx.isHidden)
            .disposed(by: bag)
    }
    
    func updateOriginX() {
        let videoItem = viewModel.videoItem!
        let startValue = videoItem.editedStartTimeVariable.value/viewModel.videoDuration
        let leading = CGFloat(startValue) * scrollView.contentSize.width
        editView.bs.origin.x = leading - MediaEditComponentView.handleWidth
        
        let maskLayerFrame = maskLayer.frame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = CGRect(x: leading, y: maskLayerFrame.origin.y, width: maskLayerFrame.width, height: maskLayerFrame.height)
        CATransaction.commit()
    }
    
    func updateWidth() {
        let videoItem = viewModel.videoItem!
        let startValue = videoItem.editedStartTimeVariable.value/viewModel.videoDuration
        let endValue = videoItem.editedEndTimeVariable.value/viewModel.videoDuration
        
        let widthValue = endValue - startValue
        let width = CGFloat(widthValue) * scrollView.contentSize.width
        editView.bs.width = width + 2 * MediaEditComponentView.handleWidth
        
        let maskLayerFrame = maskLayer.frame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = CGRect(x: maskLayerFrame.origin.x, y: maskLayerFrame.origin.y, width: width, height: maskLayerFrame.height)
        CATransaction.commit()
    }
    
    func addAudioEditView() {
        guard let audioItem = viewModel.audioItemsVariable.value.last else {
            return
        }
        let audioEditView = AudioEditView.bs.instantiateFromNib
        audioEditView.viewModel = viewModel
        audioEditView.audioItem = audioItem
        scrollView.addSubview(audioEditView)
        
        audioItem.isSelectedVariable.asObservable()
            .subscribe(onNext: { [unowned self, unowned audioEditView] (isSelected) in
                self.scrollView.bringSubviewToFront(audioEditView)
            })
            .disposed(by: audioEditView.bag)
    }
}
