//
//  PhotoCameraViewController.swift
//  LiveCamera
//
//  Created by Phillip Wright on 8/28/17.
//  Copyright © 2017 Touchopia, LLC. All rights reserved.
//

import UIKit
import AVFoundation

extension AVCaptureVideoOrientation {
    static func orientationFromUIDeviceOrientation(_ orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
}

class PhotoCameraViewController: UIViewController {
    
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var backdropView: UIView!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var finalOverlayView: UIView!
    
    //MARK: -
    //MARK:
    var capturedImageView: UIImageView?
    var maxWidth: CGFloat = 300
    var hasPhoto: Bool = false {
        didSet {
            self.cameraButton.isSelected = hasPhoto
        }
    }
    
    //MARK: -
    //MARK:
    
    var captureSession: AVCaptureSession = AVCaptureSession()
    var stillImageOutput: AVCaptureStillImageOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var cameraDevice: AVCaptureDevice?
    var centeredView = UIView()
    
    fileprivate var prevZoomFactor: CGFloat = 1
    fileprivate var minZoomFactor: CGFloat = 1
    
    //MARK: -
    //MARK: View Life Cycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.addPreviewLayerView()
        self.addCaptureLayer(position: .front)
        self.centerView(self.centeredView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let layer = previewLayer, let previewView = self.previewView {
            layer.frame = previewView.frame
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.previewLayer = nil
    }
    
    //MARK: - Layout
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let connection =  self.previewLayer?.connection  {
            let previewLayerConnection : AVCaptureConnection = connection
            if previewLayerConnection.isVideoOrientationSupported {
                updatePreviewLayer()
            }
        }
        
        if centeredView.frame.width > 0 {
            overlayView.isUserInteractionEnabled = false
            overlayView.alpha = 0.6
            
            // mask center
            let layerMask = CAShapeLayer()
            let path = CGMutablePath()
            path.addRect(overlayView.bounds)
            path.addRect(centeredView.frame)
            layerMask.path = path
            layerMask.fillRule = CAShapeLayerFillRule.evenOdd
            overlayView.layer.mask = layerMask
        }
    }
    
    private func addPreviewLayerView() {
        if self.previewView != nil {
            return
        }
        
        previewView.addSubview(UIView(frame: self.backdropView.bounds))
        
        if let previewView = self.previewView {
            self.backdropView.addSubview(previewView)
            
            let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(PhotoCameraViewController.pinch(sender:)))
            previewView.addGestureRecognizer(pinchRecognizer)
        }
    }
    
    private func updatePreviewLayer() {
        if let connection =  self.previewLayer?.connection  {
            let previewLayerConnection : AVCaptureConnection = connection
            previewLayerConnection.videoOrientation = .orientationFromUIDeviceOrientation(UIDevice.current.orientation)
            previewLayerConnection.videoPreviewLayer?.frame = previewView.frame
        }
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        if let layer = previewLayer {
            layer.frame = previewView.frame
        }
    }
    
    @objc func addCaptureLayer(position: AVCaptureDevice.Position) {
        
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        cameraDevice = self.getDevice(position: position)
        
        var error : NSError?
        var input: AVCaptureDeviceInput?
        
        do {
            input = try AVCaptureDeviceInput(device: cameraDevice!)
        } catch let e as NSError {
            input = nil
            error = e
            
            print("An error occurred \(error?.localizedDescription ?? "")")
        }
        
        if error == nil && captureSession.canAddInput(input!) {
            captureSession.addInput(input!)
            
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput!.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            
            if captureSession.canAddOutput(stillImageOutput!) {
                captureSession.addOutput(stillImageOutput!)
                
                let layer = AVCaptureVideoPreviewLayer(session: captureSession)
                layer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewView?.layer.addSublayer(layer)
                previewLayer = layer
                
                self.finalOverlayView.isHidden = true
                captureSession.startRunning()
            }
        }
    }
    
    @objc func pinch(sender: UIPinchGestureRecognizer) {
        
        var zoomFactor = sender.scale * prevZoomFactor
        
        if sender.state == .ended {
            prevZoomFactor = zoomFactor >= 1 ? zoomFactor : 1
        }
        
        if let camera = self.cameraDevice {
            defer { camera.unlockForConfiguration() }
            
            do {
                try camera.lockForConfiguration()
                
                let maxZoomFactor = camera.activeFormat.videoMaxZoomFactor
                
                if (zoomFactor <= maxZoomFactor && zoomFactor > minZoomFactor) {
                    camera.videoZoomFactor = zoomFactor
                }
            } catch {
                print("Error in Zooming")
            }
        }
    }
    
    //MARK: - Action Methods
    
    @IBAction func cameraButtonTapped() {
        
        guard let output = stillImageOutput else {
            print("No Output Detected")
            return
        }
        
        if captureSession.isRunning {

            if let videoConnection = output.connection(with: AVMediaType.video) {

                // Make sure always portrait
                videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait

                output.captureStillImageAsynchronously(from: videoConnection, completionHandler: {(sampleBuffer, error) in

                    if let buffer = sampleBuffer {

                        self.capturedImageView?.removeFromSuperview()

                        if let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer) {
                            let dataProvider = CGDataProvider(data: imageData as CFData)

                            if let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent) {
                                let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImage.Orientation.leftMirrored)

                                let captured = UIImageView(image: image)
                                captured.contentMode = .scaleAspectFill
                                captured.frame = self.centeredView.frame

                                let orientation = UIDevice.current.orientation
                                if orientation == .landscapeLeft {
                                    captured.transform = captured.transform.rotated(by: CGFloat(-Double.pi/2))
                                } else if orientation == .landscapeRight {
                                    captured.transform = captured.transform.rotated(by: CGFloat(Double.pi/2))
                                }
                                self.view.addSubview(captured)
                                self.capturedImageView = captured

                                self.centerView(captured)
                                self.hasPhoto = true
                                self.captureSession.stopRunning()

                                self.finalOverlayView.isHidden = false
                                // self.view.bringSubview(toFront: captured)
                                //self.view.bringSubview(toFront: self.cameraButton)
                            }
                        }
                    }
                })
            }
        } else {
            self.capturedImageView?.removeFromSuperview()
            self.hasPhoto = false
            self.finalOverlayView.isHidden = true
            self.captureSession.startRunning()
        }
    }
    
    private func getDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        var capturedDevice: AVCaptureDevice?
        
        for device in AVCaptureDevice.devices() {
            if(device.position == position) {
                capturedDevice = device
            }
        }
        return capturedDevice
    }
    
    // MARK: -
    // MARK: Public Static API
    static func createStoryboard() -> PhotoCameraViewController {
        let storyboard = UIStoryboard(name: "PhotoCamera", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "PhotoCameraViewController") as! PhotoCameraViewController
    }
    
    func centerView(_ theView: UIView) {
        theView.backgroundColor = UIColor.clear
        theView.layer.borderColor = UIColor.white.cgColor
        theView.layer.borderWidth = 4
        theView.clipsToBounds = true
        view.addSubview(theView)
        
        // Autolayout to center of screen
        theView.translatesAutoresizingMaskIntoConstraints = false
        theView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        theView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        theView.heightAnchor.constraint(equalToConstant: maxWidth).isActive = true
        theView.widthAnchor.constraint(equalToConstant: maxWidth).isActive = true
        view.bringSubviewToFront(theView)
    }
}
