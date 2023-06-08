//
//  ViewController.swift
//  VideoEncodeDemo
//
//  Created by 王磊 on 2023/5/23.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    private var videoEncoder: VideoEncoder?
    
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        return session
    }()
    
    private lazy var encodingQueue = DispatchQueue(label: "com.encodingQueue.video")
    private let videoOutput: AVCaptureVideoDataOutput = {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        return videoOutput
    }()
    private let audioOutput: AVCaptureAudioDataOutput = {
        let audioOutput = AVCaptureAudioDataOutput()
        return audioOutput
    }()
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        return previewLayer
    }()
    
    private var backCameraDevice: AVCaptureDevice?
    private var frontCameraDevice: AVCaptureDevice?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCamaraLayer()
        
        let startRecordingButton = UIButton(type: .system)
        startRecordingButton.setTitle("开始录制", for: .normal)
        startRecordingButton.addTarget(self, action: #selector(startRecordingButtonClick(sender:)), for: .touchUpInside)
        startRecordingButton.frame = CGRect(x: 100, y: 100, width: 40, height: 20)
        startRecordingButton.sizeToFit()
        view.addSubview(startRecordingButton)
        
        let finishRecordingButton = UIButton(type: .system)
        finishRecordingButton.setTitle("结束录制", for: .normal)
        finishRecordingButton.addTarget(self, action: #selector(finishRecordingButtonClick(sender:)), for: .touchUpInside)
        finishRecordingButton.frame = CGRect(x: 100, y: 200, width: 40, height: 20)
        finishRecordingButton.sizeToFit()
        view.addSubview(finishRecordingButton)
        
    }

    private func addCamaraLayer() {
        configCameraDevice()
        if let frontCameraDevice, let frontCameraInput = try? AVCaptureDeviceInput(device: frontCameraDevice) {
            if captureSession.canAddInput(frontCameraInput) {
                captureSession.addInput(frontCameraInput)
            }
        }
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        if let audioDevice = AVCaptureDevice.default(for: .audio), let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
        }
        
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }
        
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
        
        guard let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first else { return }
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = window.bounds
        view.layer.addSublayer(previewLayer)
    }
    
    private func configCameraDevice() {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInTelephotoCamera, .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTripleCamera], mediaType: .video, position: .unspecified)
        let availableCameraDevices = discoverySession.devices
        for device in availableCameraDevices {
            if device.position == .back {
                backCameraDevice = device
            } else if device.position == .front {
                frontCameraDevice = device
            }
        }
    }
    
}

extension ViewController {
    
    @objc private func startRecordingButtonClick(sender: UIButton) {
        encodingQueue.async {
            let encoder = VideoEncoder(videoResolution: CGSize(width: 1080.0, height: 1920.0), videoBitrate: 6000 * 1000, audioSampleRate: 44100, encodingQueue: self.encodingQueue, videoOutput: self.videoOutput, audioOutput: self.audioOutput, recordingInterval: 6.0)
            self.videoEncoder = encoder
            self.videoEncoder?.startEncoding()
        }
    }
    
    @objc private func finishRecordingButtonClick(sender: UIButton) {
        try? videoEncoder?.finishEncoding(completion: nil)
    }
}
