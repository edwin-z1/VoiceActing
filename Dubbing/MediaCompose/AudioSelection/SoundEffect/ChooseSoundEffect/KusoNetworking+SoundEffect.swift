//
//  KusoNetworking+SoundEffect.swift
//  Kuso
//
//  Created by blurryssky on 2018/9/13.
//  Copyright © 2018年 momo. All rights reserved.
//

import Foundation

class SoundEffectListResponse: NSObject, BaseResponse {
    
    var ec: KusoNetworking.Code?
    var em: String?
    var data: SoundEffectList?
    
    
    class SoundEffectList: NSObject, Codable {
        var list: [SoundEffect]?
    }
    
    class SoundEffect: NSObject, Codable {
        
        var id: String?
        var name: String?
        var icon: String?
        var urlString: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case icon
            case urlString = "url"
        }
        
        lazy var downloadItem: MediaDownloader.DownloadItem? = {
            guard !isDefaultItem,
                let id = id,
                let url = url else {
                    return nil
            }
            return MediaDownloader.shared.downloadItem(forType: .music, id: "SoundEffect+\(id)", url: url)
        }()
        
        // MARK: - custom
        var isDefaultItem = false
        
        // MARK: - for composition
        var fileUrl: URL?
        var startTime: TimeInterval = 0
    }
}

extension SoundEffectListResponse.SoundEffect {
    
    var url: URL? {
        guard let urlString = urlString?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: urlString) else {
                return nil
        }
        return url
    }
    
    var iconUrl: URL? {
        guard let icon = icon?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: icon) else {
                return nil
        }
        return url
    }
    
}

extension KusoNetworking {
    
    static func soundEffectList(completion: @escaping (SoundEffectListResponse?) -> Void) {
        let path = "/api/opus/getSdList"
        KusoNetworking.getJSON(path: path, parameters: nil, completion: completion)
    }
}
