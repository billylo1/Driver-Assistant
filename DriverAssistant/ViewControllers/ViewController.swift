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
    private let sessionQueue = DispatchQueue(label: "SessionQueue", qos: .userInitiated)
    
    // Zoom control properties
    private var currentZoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 5.0
    private var videoDevice: AVCaptureDevice?
    private var pinchGestureRecognizer: UIPinchGestureRecognizer!
    
    // Zoom control UI elements
    private var zoomInButton: UIButton!
    private var zoomOutButton: UIButton!
    private var resetZoomButton: UIButton!
    private var zoomLevelLabel: UILabel!
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
    
    
    override func viewDidLoad() {
        UIApplication.shared.isIdleTimerDisabled = true // Prevent the device from going to sleep
        super.viewDidLoad()
        
        // Launch camera only if device is connected to allow for tests without device
//        if (TARGET_IPHONE_SIMULATOR == 0) {
                setupAVCapture() // Preview stuff
//        }
        
        trafficLightRed.superview?.bringSubviewToFront(trafficLightRed)
        trafficLightGreen.superview?.bringSubviewToFront(trafficLightGreen)
        stopSign.superview?.bringSubviewToFront(stopSign)
        
        // Setup zoom gesture
        setupZoomGesture()
    }
    
    private func setupZoomGesture() {
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGestureRecognizer)
    }
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let device = videoDevice else { return }
        
        switch gesture.state {
        case .began:
            // Store initial zoom factor
            currentZoomFactor = device.videoZoomFactor
        case .changed:
            // Calculate new zoom factor
            let newZoomFactor = currentZoomFactor * gesture.scale
            let clampedZoomFactor = max(minZoomFactor, min(maxZoomFactor, newZoomFactor))
            
            // Apply zoom
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoomFactor
                device.unlockForConfiguration()
            } catch {
                print("Error setting zoom factor: \(error)")
            }
        case .ended:
            // Reset gesture scale
            gesture.scale = 1.0
        default:
            break
        }
    }
    
    // Public method to set zoom factor programmatically
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = videoDevice else { return }
        
        let clampedFactor = max(minZoomFactor, min(maxZoomFactor, factor))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            currentZoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom factor: \(error)")
        }
    }
    
    // Public method to get current zoom factor
    func getCurrentZoomFactor() -> CGFloat {
        return videoDevice?.videoZoomFactor ?? 1.0
    }
    
    // Public method to reset zoom
    func resetZoom() {
        setZoomFactor(1.0)
    }
    
    // Public method to zoom in
    func zoomIn() {
        let currentFactor = getCurrentZoomFactor()
        setZoomFactor(currentFactor * 1.5)
    }
    
    // Public method to zoom out
    func zoomOut() {
        let currentFactor = getCurrentZoomFactor()
        setZoomFactor(currentFactor / 1.5)
    }
       
    
    fileprivate func setupConstraints() {
        navigationView.view.backgroundColor = UIColor.clear // Required to not hide other layers
        navigationView.view.isUserInteractionEnabled = false // Allow gestures to pass through
        navigationView.view.translatesAutoresizingMaskIntoConstraints = false
        navigationView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        navigationView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        navigationView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        navigationView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
    
    fileprivate func setupConstraintsDisplay() {
        displayView.view.backgroundColor = UIColor.clear // Needed to not hide other layers
        displayView.view.isUserInteractionEnabled = false // Allow gestures to pass through
        displayView.view.translatesAutoresizingMaskIntoConstraints = false
        displayView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        displayView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        displayView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        displayView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
    private func setupZoomControls() {
        // Create zoom level label
        zoomLevelLabel = UILabel()
        zoomLevelLabel.text = "1.0x"
        zoomLevelLabel.textColor = .white
        zoomLevelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        zoomLevelLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        zoomLevelLabel.textAlignment = .center
        zoomLevelLabel.layer.cornerRadius = 8
        zoomLevelLabel.layer.masksToBounds = true
        zoomLevelLabel.translatesAutoresizingMaskIntoConstraints = false
        previewView.addSubview(zoomLevelLabel)
        
        // Create zoom in button
        zoomInButton = UIButton(type: .system)
        zoomInButton.setImage(UIImage(systemName: "plus.magnifyingglass"), for: .normal)
        zoomInButton.tintColor = .white
        zoomInButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        zoomInButton.layer.cornerRadius = 25
        zoomInButton.translatesAutoresizingMaskIntoConstraints = false
        zoomInButton.addTarget(self, action: #selector(zoomInTapped), for: .touchUpInside)
        previewView.addSubview(zoomInButton)
        
        // Create zoom out button
        zoomOutButton = UIButton(type: .system)
        zoomOutButton.setImage(UIImage(systemName: "minus.magnifyingglass"), for: .normal)
        zoomOutButton.tintColor = .white
        zoomOutButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        zoomOutButton.layer.cornerRadius = 25
        zoomOutButton.translatesAutoresizingMaskIntoConstraints = false
        zoomOutButton.addTarget(self, action: #selector(zoomOutTapped), for: .touchUpInside)
        previewView.addSubview(zoomOutButton)
        
        // Create reset zoom button
        resetZoomButton = UIButton(type: .system)
        resetZoomButton.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .normal)
        resetZoomButton.tintColor = .white
        resetZoomButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        resetZoomButton.layer.cornerRadius = 25
        resetZoomButton.translatesAutoresizingMaskIntoConstraints = false
        resetZoomButton.addTarget(self, action: #selector(resetZoomTapped), for: .touchUpInside)
        previewView.addSubview(resetZoomButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Zoom level label
            zoomLevelLabel.bottomAnchor.constraint(equalTo: previewView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            zoomLevelLabel.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -20),
            zoomLevelLabel.widthAnchor.constraint(equalToConstant: 60),
            zoomLevelLabel.heightAnchor.constraint(equalToConstant: 30),
            
            // Zoom in button
            zoomInButton.bottomAnchor.constraint(equalTo: zoomLevelLabel.topAnchor, constant: -12),
            zoomInButton.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -20),
            zoomInButton.widthAnchor.constraint(equalToConstant: 50),
            zoomInButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Zoom out button
            zoomOutButton.bottomAnchor.constraint(equalTo: zoomInButton.topAnchor, constant: -12),
            zoomOutButton.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -20),
            zoomOutButton.widthAnchor.constraint(equalToConstant: 50),
            zoomOutButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Reset zoom button
            resetZoomButton.bottomAnchor.constraint(equalTo: zoomOutButton.topAnchor, constant: -12),
            resetZoomButton.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -20),
            resetZoomButton.widthAnchor.constraint(equalToConstant: 50),
            resetZoomButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func zoomInTapped() {
        zoomIn()
        updateZoomLevelLabel()
    }
    
    @objc private func zoomOutTapped() {
        zoomOut()
        updateZoomLevelLabel()
    }
    
    @objc private func resetZoomTapped() {
        resetZoom()
        updateZoomLevelLabel()
    }
    
    func updateZoomLevelLabel() {
        let currentZoom = getCurrentZoomFactor()
        zoomLevelLabel.text = String(format: "%.1fx", currentZoom)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func setupAVCapture() {
        // Setup UI immediately for responsiveness
        setupUI()
        
        // Configure session on background thread
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    private func setupUI() {
        // Setup preview layer immediately
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        
        // Show the current speed at the top of the screen
        addChild(displayView)
        view.addSubview(displayView.view)
        setupConstraintsDisplay()
        
        // Add layers for display and navigation from SwiftUI
        addChild(navigationView)
        view.addSubview(navigationView.view)
        setupConstraints()
        
        // Add zoom controls for all view controllers
        setupZoomControls()
    }
    
    private func configureSession() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        
        guard let videoDevice = videoDevice else {
            print("No video device found")
            return
        }
        
        // Store reference to video device for zoom control
        self.videoDevice = videoDevice
        
        // Set initial zoom factor
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.videoZoomFactor = currentZoomFactor
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error setting initial zoom factor: \(error)")
        }
        
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        // Configure session
        session.beginConfiguration()
        session.sessionPreset = .high // Use high quality for better performance
        
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        
        let captureConnection = videoDataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        
        // Get device dimensions
        do {
            try videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
            bufferSize.width = CGFloat(dimensions.height)
            bufferSize.height = CGFloat(dimensions.width)
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error getting device dimensions: \(error)")
        }
        
        session.commitConfiguration()
        
        // Setup detection-specific components on main thread
        DispatchQueue.main.async {
            if let detectionVC = self as? ViewControllerDetection {
                detectionVC.setupLayers()
                detectionVC.updateLayerGeometry()
                if let error = detectionVC.setupVision() {
                    print("Vision setup failed: \(error)")
                }
                detectionVC.startCaptureSession()
            } else {
                // For non-detection view controllers, start session directly
                self.startCaptureSession()
            }
        }
    }
    
    
    func startCaptureSession() {
        sessionQueue.async {
            self.session.startRunning()
        }
    }
    
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
}
