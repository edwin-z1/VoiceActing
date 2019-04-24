//
//  AudioToolView.swift
//  VoiceActing
//
//  Created by blurryssky on 2018/11/5.
//  Copyright © 2018 blurryssky. All rights reserved.
//

import UIKit

import RxSwift
import RxCocoa

class AudioToolView: UIView {

    var viewModel: MediaComposeViewModel!
    var composeItem: MediaComposeItem! {
        didSet {
            deleteButton.isHidden = composeItem == viewModel.videoItem
            volumeSlider.value = CGFloat(composeItem.preferredVolume)
        }
    }
    
    @IBOutlet weak var loudspeakerButton: HitExtendButton!
    @IBOutlet weak var volumeSlider: AnimationSlider! {
        didSet {
            volumeSlider.thumbImage = #imageLiteral(resourceName: "mc_slider_thumb")
            volumeSlider.thumbExtendRespondsRadius = 12
            volumeSlider.minimunTrackTintColors = [#colorLiteral(red: 1, green: 0.06274509804, blue: 0.8470588235, alpha: 1), #colorLiteral(red: 1, green: 0.3137254902, blue: 0.2588235294, alpha: 1)]
            volumeSlider.maximunTrackTintColors = [#colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.06)]
            volumeSlider.value = 1
        }
    }
    @IBOutlet weak var deleteButton: HitExtendButton!
    
    fileprivate let bag = DisposeBag()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
}

private extension AudioToolView {
    
    func setup() {
        
        loudspeakerButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.loudspeakerButton.isSelected = !self.loudspeakerButton.isSelected
                if self.loudspeakerButton.isSelected {
                    self.loudspeakerButton.setImage(#imageLiteral(resourceName: "mc_mute"), for: .normal)
                    self.volumeSlider.value = 0
                    self.viewModel.updateItemVolume(self.composeItem, volume: 0)
                } else {
                    self.loudspeakerButton.setImage(#imageLiteral(resourceName: "mc_speaker"), for: .normal)
                    self.volumeSlider.value = 1
                    self.viewModel.updateItemVolume(self.composeItem, volume: 1)
                }
            })
            .disposed(by: bag)
        
        volumeSlider.rx.value
            .skip(1)
            .subscribe(onNext: { [unowned self] (value) in
                
                var img = #imageLiteral(resourceName: "mc_mute")
                if value != 0 {
                    img = #imageLiteral(resourceName: "mc_speaker")
                }
                self.loudspeakerButton.setImage(img, for: .normal)
                self.viewModel.updateItemVolume(self.composeItem, volume: Float(value))
            })
            .disposed(by: bag)
        
        deleteButton.rx.tap
            .subscribe(onNext: { [unowned self] (_) in
                self.alertDelete()
            })
            .disposed(by: bag)
        
    }
    
    func alertDelete() {
        let alert = UIAlertController(title: "是否删除? ", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确认", style: .default, handler: { [unowned self] (action) in
            self.viewModel.removeAudioItem(self.composeItem)
        }))
        bs.nextViewController?.present(alert, animated: true, completion: nil)
    }
}
