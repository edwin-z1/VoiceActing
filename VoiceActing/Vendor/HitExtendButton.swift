//
//  HitExtendButton.swift
//  kuso
//
//  Created by blurryssky on 2018/6/30.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

class HitExtendButton: UIButton {
    
    var extendRadius: CGFloat = 12

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        
        let insetedBounds = bounds.insetBy(dx: -extendRadius, dy: -extendRadius)
        if insetedBounds.contains(point) {
            return true
        } else {
            return super.point(inside: point, with: event)
        }
    }
}
