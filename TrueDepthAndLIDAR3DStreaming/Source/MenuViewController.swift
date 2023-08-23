//
//  IBAViewController.swift
//  TrueDepthAndLIDAR3DStreaming
//
//  Created by KoheiOgawa on 2020/12/20.
//  Copyright © 2020 Itty Bitty Apps Pty Ltd. All rights reserved.
//

import UIKit

class MenuViewController: UIViewController{
    
    @IBOutlet var topView: UIView!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var remoteView: UIView!
    @IBOutlet weak var cameraTitle: UILabel!
    @IBOutlet weak var cameraDiscription: UILabel!
    @IBOutlet weak var cameraViewButton: UIButton!
    @IBOutlet weak var cameraArrow: UIImageView!
    @IBOutlet weak var remoteTitle: UILabel!
    @IBOutlet weak var remoteDiscription: UILabel!
    @IBOutlet weak var remoteViewButton: UIButton!
    @IBOutlet weak var remoteArrow: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var appTitle: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if DEBUG
            print(NSStringFromClass(type(of: self)),"の",#function,"メソッド")
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {
        var margin:CGFloat = 50
        cameraView.frame.size.width = topView.frame.width - margin
        remoteView.frame.size.width = topView.frame.width - margin
        cameraView.frame.size.height = topView.frame.height/5
        remoteView.frame.size.height = topView.frame.height/5
        cameraView.frame.origin.x = margin / 2
        cameraView.frame.origin.y = topView.frame.size.height/2 - cameraView.frame.size.height  //+ topView.frame.height/14
        remoteView.frame.origin.x = margin / 2
        remoteView.frame.origin.y = cameraView.frame.maxY + topView.frame.height/14
        margin = 10
        cameraTitle.frame.size.width = cameraView.frame.size.width
        cameraTitle.textAlignment = NSTextAlignment.center
        cameraDiscription.frame.origin.x = cameraView.frame.origin.x - margin
        cameraDiscription.frame.size.width = cameraView.frame.size.width - margin * 2
        if cameraView.frame.size.width > 600{
            cameraTitle.font = .boldSystemFont(ofSize: 28)
            cameraDiscription.font = .systemFont(ofSize: 20)
        }
        cameraViewButton.frame.size = cameraView.frame.size
        cameraArrow.frame.size.width = cameraView.frame.size.height / 4
        cameraArrow.frame.origin.x = cameraView.frame.size.width - cameraArrow.frame.size.width - margin
        cameraArrow.frame.origin.y = cameraView.frame.size.height - cameraArrow.frame.size.height - margin
        
        remoteTitle.frame.size.width = remoteView.frame.size.width
        remoteTitle.textAlignment = NSTextAlignment.center
        remoteDiscription.frame.origin.x = remoteView.frame.origin.x - margin
        remoteDiscription.frame.size.width = remoteView.frame.size.width - margin * 2
        if remoteView.frame.size.width > 600{
            remoteTitle.font = .boldSystemFont(ofSize: 28)
            remoteDiscription.font = .systemFont(ofSize: 20)
        }
        remoteViewButton.frame.size = remoteView.frame.size
        remoteArrow.frame.size.width = remoteView.frame.size.height / 4
        remoteArrow.frame.origin.x = remoteView.frame.size.width - remoteArrow.frame.size.width - margin
        remoteArrow.frame.origin.y = remoteView.frame.size.height - remoteArrow.frame.size.height - margin
        
        iconImageView.frame.origin.x = appTitle.frame.maxX
    }
    // CameraViewControllerへ遷移
    @IBAction func StartSencing_TouchUp(_ sender: Any) {
        performSegue(withIdentifier: "Menu2CameraView", sender: nil)
    }
    
    // RemoteViewControllerへ遷移
    @IBAction func StartControlling_TouchUp(_ sender: Any) {
        performSegue(withIdentifier: "Menu2RemoteView", sender: nil)
    }
}
