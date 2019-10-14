//
//  RootViewController.swift
//  LiveCamera
//
//  Created by Phillip Wright on 8/28/17.
//  Copyright © 2017 Touchopia, LLC. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {

    var photoController: PhotoCameraViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        photoController = PhotoCameraViewController.createStoryboard()
    }

    
    @IBAction func cameraTapped(_ sender: UIButton) {
        present(photoController, animated: false, completion: nil)
    }
    
}
