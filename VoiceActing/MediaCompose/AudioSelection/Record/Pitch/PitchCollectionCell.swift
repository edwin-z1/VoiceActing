//
//  PitchCollectionCell.swift
//  kuso
//
//  Created by blurryssky on 2018/7/2.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

class PitchCollectionCell: UICollectionViewCell {
    
    var audioProcessItem: PitchItem! {
        didSet {
            imgView.image = audioProcessItem.img
            label.text = audioProcessItem.title
        }
    }
    
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    fileprivate lazy var selectedLayer: CAShapeLayer = {
        let sa = CAShapeLayer()
        sa.strokeColor = #colorLiteral(red: 1, green: 0.1764705882, blue: 0.3333333333, alpha: 1).cgColor
        sa.fillColor = UIColor.clear.cgColor
        sa.lineWidth = 2
        sa.isHidden = true
        return sa
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.addSublayer(selectedLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(arcCenter: CGPoint(x: ks.width/2, y: imgView.center.y), radius: imgView.ks.width/2 + 2, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        selectedLayer.path = path.cgPath
    }
    
    override var isSelected: Bool {
        didSet {
            selectedLayer.isHidden = !isSelected
            if isSelected {
                label.textColor = UIColor.white.withAlphaComponent(0.8)
            } else {
                label.textColor = UIColor.white.withAlphaComponent(0.4)
            }
        }
    }
}
