//
//  ViewController.swift
//  CoreML-ImageStyleVideo
//
//  Created by 杨帆 on 2022/5/29.
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController {
    private let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var requests = [VNRequest]()
    lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: UIScreen.main.bounds)
        imageView.contentMode = .center
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(imageView)
        setup()
    }

    func setup() {
        setupAVCapture()
        setupModels()
        startCaptureSession()
    }

    func startCaptureSession() {
        session.startRunning()
    }
}

extension ViewController {
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
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
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
    }
}

extension ViewController {
    func setupModels() {
        guard let modelURL = Bundle.main.url(forResource: "AnimeGANv2", withExtension: "mlmodelc") else {
            return
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel) { request, _ in
                DispatchQueue.main.async {
                    guard let results = request.results as? [VNPixelBufferObservation] else {
                        return
                    }

                    for result in results {
                        self.imageView.image = UIImage(ciImage: CIImage(cvPixelBuffer: result.pixelBuffer))
                    }
                }
            }
            requests = [objectRecognition]
        } catch {
            print("Model loading went wrong: \(error)")
        }
    }
    
    
    func setupModels2() {
        guard let modelURL = Bundle.main.url(forResource: "photo2cartoon", withExtension: "mlmodelc") else {
            return
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel) { request, _ in
                DispatchQueue.main.async {
                    guard let results = request.results as? [VNPixelBufferObservation] else {
                        return
                    }

                    for result in results {
                        self.imageView.image = UIImage(ciImage: CIImage(cvPixelBuffer: result.pixelBuffer))
                    }
                }
            }
            requests = [objectRecognition]
        } catch {
            print("Model loading went wrong: \(error)")
        }
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
}
