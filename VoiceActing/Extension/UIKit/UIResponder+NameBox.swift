//
//  UIResponder+NameBox.swift
//  VoiceActing
//
//  Created by blurryssky on 2018/5/16.
//  Copyright © 2018年 blurryssky. All rights reserved.
//

import Foundation

extension NamespaceBox where T: UIResponder {
    
    var nextViewController: UIViewController? {
        if let next = base.next  {
            if let vc = next as? UIViewController,
                !vc.isKind(of: UINavigationController.self) {
                return vc
            } else {
                return next.bs.nextViewController
            }
        } else {
            return nil
        }
    }
    
    var nextNaviViewController: UINavigationController? {
        if let next = base.next  {
            if let vc = next as? UINavigationController {
                return vc
            } else {
                return next.bs.nextNaviViewController
            }
        } else {
            return nil
        }
    }
    
}
