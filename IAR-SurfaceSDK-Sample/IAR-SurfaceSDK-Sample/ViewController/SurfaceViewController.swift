//
//  SurfaceViewController.swift
//  IAR-SurfaceSDK-Sample
//
//  Created by Rogerio on 2022-02-07.
//

import Foundation
import UIKit
import Kingfisher
import IAR_Core_SDK
import IAR_Surface_SDK

class SurfaceViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var surfaceView: IARSurfaceView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var screenshotButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var recordProgressView: UIProgressView!
    
    
    // MARK: - Properties
    
    var marker: Marker?
    private var currentRecordingTime = 0
    private var recorderV1 = IARRecorder()
    private var recorder: SurfaceRecorder? = nil
    
    // MARK: - Surface instruction message
    
    var pointAtSurfaceMessage = "Point your device at a flat surface"
    var tapToPlaceMessage = "Tap the screen to place asset"
    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupPermissions()
        startAR()
        
        // Show user instruction
        setupMessageLabel(self.pointAtSurfaceMessage)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop IARSurface when the view will disappear
        
        pauseAR()
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Start (or resume) IARSurface when the view will appear
        
        resumeAR()
        super.viewWillAppear(animated)
    }
    
    
    // MARK: - Setup
    
    func setupView() {
        self.navigationController?.title = "Surface AR"
        
        // Hide while not recording
        self.recordProgressView.isHidden = true
        
        // Hide move and record buttons while no asset is anchored
        self.disableRecordButtons()
        self.disableMoveButton()
        
        // Pause ARSurface when the app is not on focus and resume once it is again.
        NotificationCenter.default.addObserver(self, selector: #selector(pauseAR), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAR), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func setupPermissions() {
        // Camera
        AVCaptureDevice.requestAccess(for: .video) { isGranted in
            if isGranted {
                print("Camera permission granted")
            } else {
                print( "Camera permission denied - Target AR requires your permission to access the camera")
            }
        }
        
        // Microphone
        AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
            if isGranted {
                print("Microphone permission granted")
            } else {
                print("Microphone permission denied - Target AR requires your permission to access the camera")
            }
        }
    }
    
    // Changes the text on the message label
    // If no paramether is given, hides the label
    func setupMessageLabel(_ message: String?) {
        DispatchQueue.main.async {
            guard let newMessage = message else {
                self.messageView.isHidden = true
                return
            }
            
            self.messageView.isHidden = false
            self.messageLabel.text = newMessage
        }
    }
    
    func getScreenResolution() -> CGSize {
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height

        let scale = UIScreen.main.scale
        let pixelWidth = screenWidth * scale
        let pixelHeight = screenHeight * scale
        
        return CGSize(width: pixelWidth, height: pixelHeight)
    }
    
    // MARK: - Methods - IAR Surface Status
    
    func startAR() {
        
        // ARSurface needs a marker to start, if none was received, it can't start
        guard let marker = self.marker else { return }
        
        // Load and assing a marker
        self.surfaceView.forcedOrientation = .gravity
        self.surfaceView.load()
        self.surfaceView.marker = marker
        
        do {
            var recordingOptions = SurfaceRecorder.Options.default
            recordingOptions.outputUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "IAR-Output.mp4")
            recordingOptions.videoSize = getScreenResolution()
            try recorder = SurfaceRecorder(withSurfaceView: surfaceView, options: recordingOptions)
            recorder?.delegate = self
        } catch let error {
            FileLogger.shared.log(content: "Failed to create recorder: \(error.localizedDescription)")
        }
        
        // Setup its delegate
        surfaceView.delegate = self
    }
    
    @objc func pauseAR() {
        surfaceView?.stop()
    }
    
    @objc func resumeAR() {
        surfaceView?.start()
    }
    
    
    // MARK: - Methods - Move
    
    @IBAction func onMoveButton(_ sender: Any) {
        // Allow the user to move the asset that is currently anchored
        surfaceView.unanchorAsset()
        
        // Remember to show instructions for the user again
        setupMessageLabel(tapToPlaceMessage)
        
        // And disable move and recording buttons
        disableRecordButtons()
        disableMoveButton()
        
    }
    
    func enableMoveButton() {
        self.moveButton.isEnabled = true
    }
    
    func disableMoveButton() {
        self.moveButton.isEnabled = false
    }
    
    
    // MARK: - Methods - Screenshot and Recording
    
    @IBAction func onScreenshotButton(_ sender: Any) {
        // Returns an UIImage for the Surface view
        let screenshotImage: UIImage = recorderV1.takeScreenshot(self.surfaceView)
        
        // With that image, it's possible to present a share modal so the user can save or share wherever they want.
        // NOTE: To share, the user may need to give permission to contacts.
        // NOTE: To save on photos, the user may need to give permission to the photos app.
        let ActivityController = UIActivityViewController(activityItems: [screenshotImage], applicationActivities: nil)
        self.present(ActivityController, animated: true, completion: nil)
    }
    
    @IBAction func onRecordButton(_ sender: Any) {
        startRecording()
    }
    
    func startRecording() {
        // Hides the recording button. It can only record one video at a time
        recordButton.isEnabled = false

        _ = recorder?.startRecording()
        
        currentRecordingTime = 0
        
        // For this example, it will stop recording after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.stopRecording()
        }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                return
            }
            
            self.currentRecordingTime = self.currentRecordingTime + 1
            self.recordProgressView.isHidden = false
            self.recordProgressView.progress = Float(self.currentRecordingTime) / Float(30)
            
            if self.currentRecordingTime > 30 {
                timer.invalidate()
            }
        }
    }
    
    func stopRecording() {
        // Calling stop recording returns the video path after it is created
        recorder?.stopRecording().onSuccess { [weak self] url in
            print("Recording Finished", url)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                
                self.recordButton.isEnabled = true
                self.recordProgressView.isHidden = true
                
//                if let error = error {
//                    // Handle the error
//                    print(error.localizedDescription)
//                }
                
                // With the video URL, it's possible to present a share modal so the user can save or share wherever they want
                // NOTE: To shar, the user may need to give permission to contacts.
                // NOTE: To save on photos, the user may need to give permission to the photos app.
                let ActivityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                self.present(ActivityController, animated: true, completion: nil)
            }
        }
    }
    
    func enableRecordButtons() {
        self.screenshotButton.isEnabled = true
        self.recordButton.isEnabled = true
    }
    
    func disableRecordButtons() {
        self.screenshotButton.isEnabled = false
        self.recordButton.isEnabled = false
    }
}

// MARK: - Extension IARSurfaceViewDelegate

extension SurfaceViewController: IARSurfaceViewDelegate {
    
    // Define if the AR Asset will always face the camera - default FALSE
    func surfaceViewOnlyShowAssetOnTap(_ surfaceView: IAR_Surface_SDK.IARSurfaceView) -> Bool {
        print("IAR - surfaceViewOnlyShowAsset")
        return false
    }
    
    // MARK: - Required delegate methods
    
    // Called when an error occurs
    func surfaceView(_ surfaceView: IARSurfaceView, onError error: Error) {
        print("IAR - Error: \(error.localizedDescription)")
    }
    
    
    // MARK: - Optional delegate methods
    
    // Called when a surface is detected
    func surfaceViewSurfaceDetected(_ surfaceView: IARSurfaceView) {
        print("IAR - Surface detected")
        
        // When the surface is detected, instruct the user to tap the screen
        // and place the asset.
        setupMessageLabel(self.tapToPlaceMessage)
    }

    // Called when an asset is anchored
    func surfaceViewAssetAnchored(_ surfaceView: IARSurfaceView) {
        print("IAR - Asset anchored")
        
        // When the asset is anchored, instructions are no longer needed
        setupMessageLabel(nil)
        
        // When the asset is anchored, Moving and Recording is available
        enableRecordButtons()
        enableMoveButton()
    }

    // Define if the AR asset can be scaled by user input - default FALSE
    func surfaceViewCanScaleAsset(_ surfaceView: IARSurfaceView) -> Bool {
        print("IAR - surfaceViewCanScaleAsset")
        return false
    }
    
    // Called to show the current download progress of any asset
    func surfaceView(_ surfaceView: IARSurfaceView, downloadProgress progress: CGFloat) {
        print("IAR - downloadProgress \(progress)")
    }
}

extension SurfaceViewController: SurfaceRecorderDelegate {
    func onError(error: Error) {
        print("IAR - Recorder error: \(error.localizedDescription)")
    }
}
