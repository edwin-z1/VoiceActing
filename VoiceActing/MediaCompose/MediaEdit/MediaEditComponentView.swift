//
//  MediaEditComponentView.swift
//  Kuso
//
//  Created by blurryssky on 2018/11/7.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class MediaEditComponentView: UIView {
    
    static let handleWidth: CGFloat = 15
    
    var mediaItem: MediaComposeItem! {
        didSet {
            update()
        }
    }
    
    let leftPan = UIPanGestureRecognizer()
    let rightPan = UIPanGestureRecognizer()
    let centerPan = UIPanGestureRecognizer()
    let bag = DisposeBag()
    
    @IBOutlet weak var leftTimeLabel: UILabel!
    @IBOutlet weak var leftImgView: UIImageView!
    @IBOutlet weak var rightTimeLabel: UILabel!
    @IBOutlet weak var rightImgView: UIImageView!
   
    private let updateBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
}

private extension MediaEditComponentView {
    
    func setup() {
        
        leftImgView.addGestureRecognizer(leftPan)
        rightImgView.addGestureRecognizer(rightPan)
        addGestureRecognizer(centerPan)
    }
    
    func update() {
        
        mediaItem.editedStartTimeVarible.asObservable()
            .throttle(0.1, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] (startTime) in
                self.leftTimeLabel.text = startTime.bs.colonString

                guard self.mediaItem.fileUrl != nil else { return }
                let endTime = self.mediaItem.editedEndTimeVarible.value
                let isHideLabel = (endTime - startTime < 1) && self.leftTimeLabel.alpha == 1
                UIView.bs.animate(content: {
                    self.rightTimeLabel.alpha = isHideLabel ? 0 : 1
                })
            })
            .disposed(by: updateBag)
        
        mediaItem.editedEndTimeVarible.asObservable()
            .throttle(0.1, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] (endTime) in
                self.rightTimeLabel.text = endTime.bs.colonString
                
                let startTime = self.mediaItem.editedStartTimeVarible.value
                let isHideLabel = (endTime - startTime < 1) && self.rightTimeLabel.alpha == 1
                UIView.bs.animate(content: {
                    self.leftTimeLabel.alpha = isHideLabel ? 0 : 1
                })
            })
            .disposed(by: updateBag)
        
    }
}

