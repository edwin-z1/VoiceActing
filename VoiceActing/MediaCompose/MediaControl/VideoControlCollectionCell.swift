//
//  VideoControlCollectionCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/10/30.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

class VideoControlCollectionCell: UICollectionViewCell {
    
    var generator: AVAssetImageGenerator!
    var timeValue: NSValue! {
        didSet {
            update()
        }
    }
    
    lazy var imgView: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        imgView.alpha = 0
        return imgView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imgView)
        backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imgView.frame = bounds
    }
}

private extension VideoControlCollectionCell {
    
    func update() {
        generator.generateCGImagesAsynchronously(forTimes: [timeValue]) {
            [weak self] (requestTime, cgImage, acturalTime, result, error) in
            guard let `self` = self else { return }
            switch result {
            case .failed:
                guard let error = error else {
                    return
                }
                print("generateCGImagesAsynchronously = \(error)")
            case .succeeded:
                guard let cg = cgImage else {
                    return
                }
                let image = UIImage(cgImage: cg)
                DispatchQueue.main.async {
                    self.imgView.image = image
                    UIView.bs.animate(content: {
                        self.imgView.alpha = 1
                    })
                }
            default:
                break
            }
        }
    }
}
