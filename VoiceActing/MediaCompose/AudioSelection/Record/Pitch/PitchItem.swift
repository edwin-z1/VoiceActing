//
//  ChooseAudioProcess.swift
//  kuso
//
//  Created by blurryssky on 2018/7/2.
//  Copyright © 2018年 momo. All rights reserved.
//

import UIKit

enum PitchType: Int {
    case original = 0
    case monster
    case papi
    case transformer
    case robot
    case mute
}

struct PitchItem {
    let pitchType: PitchType!
    let img: UIImage!
    let title: String!
}
