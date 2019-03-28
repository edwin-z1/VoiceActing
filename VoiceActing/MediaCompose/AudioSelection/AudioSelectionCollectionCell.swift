//
//  AudioSelectionTabCollectionCell.swift
//  Kuso
//
//  Created by blurryssky on 2018/10/31.
//  Copyright © 2018 momo. All rights reserved.
//

import UIKit

class AudioSelectionCollectionCell: UICollectionViewCell {
    
    var type: AudioSelectionType! {
        didSet {
            label.text = type.rawValue
        }
    }
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var dotView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.6)
        dotView.isHidden = true
    }
    
    override var isSelected: Bool {
        didSet {
            label.textColor = isSelected ? #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0) : #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.6)
            dotView.isHidden = !isSelected
        }
    }
}
