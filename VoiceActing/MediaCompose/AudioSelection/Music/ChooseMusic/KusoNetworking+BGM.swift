//
//  KusoNetworking+BGM.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/6.
//  Copyright © 2018年 momo. All rights reserved.
//

import Foundation

import RxSwift
import RxCocoa

class BackgroundMusicListResponse: NSObject, BaseResponse {
    
    var ec: KusoNetworking.Code?
    var em: String?
    var data: MusicList?
    
    class MusicList: NSObject, Codable {
        var list: [Music]?
    }
    
    class Music: NSObject, Codable {
        
        var name: String?
        var id: String?
        var urlString: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case id
            case urlString = "url"
        }
        
        var bgmType: BackgroundMusicType = .normal
        
        lazy var downloadItem: MediaDownloader.DownloadItem? = {
            guard let id = id,
                let url = url else {
                    return nil
            }
            return MediaDownloader.shared.downloadItem(forType: .music, id: "Music+\(id)", url: url)
        }()
        
        weak var cell: UIView?
        var isPlayingVariable = Variable<Bool>(false)
        
        // MARK: - only for bgmType == .edit
        var startValue: CGFloat = 0
        var endValue: CGFloat = 1
        
        // MARK: - for composition
        var fileUrl: URL?
        var startTime: TimeInterval = 0
        var asset: AVAsset?
    }
    
    enum BackgroundMusicType {
        case `default`
        case normal
        case edit
        case mediaLibrary
    }
}

extension BackgroundMusicListResponse.Music {
    
    var url: URL? {
        guard let urlString = urlString?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: urlString) else {
                return nil
        }
        return url
    }
    
}

extension KusoNetworking {
    
    static func backgroundMusicList(completion: @escaping (BackgroundMusicListResponse?) -> Void) {
        let path = "/api/opus/getBgmList"
        KusoNetworking.getJSON(path: path, parameters: nil, completion: completion)
    }
}
