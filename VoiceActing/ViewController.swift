//
//  ViewController.swift
//  VoiceActing
//
//  Created by blurryssky on 2019/3/18.
//  Copyright © 2019 blurryssky. All rights reserved.
//

import UIKit

import Photos

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        FileManager.bs.createDirectorys()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

private extension ViewController {
    
    @IBAction func handleChooseVideoButton(_ sender: UIButton) {
        
        _ = AuthorizationManager.requestPhotoLibraryAuthorization()
            .filter { $0 }
            .subscribe(onNext: { [unowned self] (isGranted) in
                let photosSelectVC = PhotosSelectViewController.bs.instantiateFromStoryboard(name: "PhotosSelectViewController")
                photosSelectVC.fetchType = .video
                let navi = UINavigationController(rootViewController: photosSelectVC)
                photosSelectVC.photosDidSelectClosure = { [unowned navi, unowned self] assets in
                    navi.dismiss(animated: true, completion: nil)
                    self.handleVideoAsset(assets.first!)
                }
                self.present(navi, animated: true, completion: nil)
            })
    }
    
    func handleVideoAsset(_ videoAsset: PHAsset) {
        PHImageManager.default().requestAVAsset(forVideo: videoAsset, options: nil, resultHandler: { (asset, _, _) in
            guard let asset = asset as? AVURLAsset else {
                print("无法编辑该视频")
                return
            }
            DispatchQueue.main.async {
                let composeVC = MediaComposeViewController.bs.instantiateFromStoryboard(name: "MediaCompose")
                composeVC.videoAsset = asset
                let navi = UINavigationController(rootViewController: composeVC)
                navi.navigationBar.barStyle = .blackTranslucent
                navi.navigationBar.tintColor = UIColor.white
                navi.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
                self.present(navi, animated: true, completion: nil)
            }
        })
    }
}

