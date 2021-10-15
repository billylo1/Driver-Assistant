//
//  ViewController.swift
//  DriverAssistant
//
//  Created by David Kirchhoff on 2021-06-21.
//

import UIKit
import AVFoundation
import Vision
import SwiftUI

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    // Include SwiftUI views
    let navigationView = UIHostingController(rootView: NavigationView())
    let displayView = UIHostingController(rootView: DisplayView())
    
    @IBOutlet weak var trafficLightRed: UIImageView!
    @IBOutlet weak var trafficLightGreen: UIImageView!
    @IBOutlet weak var stopSign: UIImageView!
    @IBOutlet weak private var previewView: UIView!
    
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
    
    
    override func viewDidLoad() {
        UIApplication.shared.isIdleTimerDisabled = true // Prevent the device from going to sleep
        super.viewDidLoad()
        
        // Launch camera only if device is connected to allow for tests without device
        if (TARGET_IPHONE_SIMULATOR == 0) {
                setupAVCapture() // Preview stuff
        }
        
        trafficLightRed.superview?.bringSubviewToFront(trafficLightRed)
        trafficLightGreen.superview?.bringSubviewToFront(trafficLightGreen)
        stopSign.superview?.bringSubviewToFront(stopSign)
    }
       
    
    fileprivate func setupConstraints() {
        navigationView.view.backgroundColor = UIColor.clear // Required to not hide other layers
        navigationView.view.translatesAutoresizingMaskIntoConstraints = false
        navigationView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        navigationView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        navigationView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        navigationView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
    
    fileprivate func setupConstraintsDisplay() {
        displayView.view.backgroundColor = UIColor.clear // Needed to not hide other layers
        displayView.view.translatesAutoresizingMaskIntoConstraints = false
        displayView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        displayView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        displayView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        displayView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first // TODO: use back camera
        
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        // Begins list of configurations. They are applied after commitConfiguration.
        session.beginConfiguration()
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        }
        else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
                
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            
            // Swap height and width because of input video orientation
            bufferSize.width = CGFloat(dimensions.height)
            bufferSize.height = CGFloat(dimensions.width)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        
        // Apply the configurations
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
        
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        
        // Show the current speed at the top of the screen
        addChild(displayView)
        view.addSubview(displayView.view)
        setupConstraintsDisplay()
        
        // Add layers for display and navigation from SwiftUI
        addChild(navigationView) // Allows embedding the custom SwiftUI view
        view.addSubview(navigationView.view)
        setupConstraints()
    }
    
    
    func startCaptureSession() {
        session.startRunning()
    }
    
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
}
