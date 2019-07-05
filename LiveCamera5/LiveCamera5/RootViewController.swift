//
//  RootViewController.swift
//  LiveCamera
//
//  Created by Phillip Wright on 8/28/17.
//  Copyright © 2017 Touchopia, LLC. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {

    var photoController: PhotoCameraViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let controller = PhotoCameraViewController.createStoryboard()
        self.present(controller, animated: false, completion: nil)
        self.photoController = controller
    }

}
