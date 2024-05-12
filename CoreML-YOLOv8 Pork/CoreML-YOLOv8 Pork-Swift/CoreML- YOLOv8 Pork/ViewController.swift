//
//  ViewController.swift
//  CoreML- YOLOv8 Pork
//
//  Created by 杨帆 on 2024/5/11.
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController {
    private var bufferSize: CGSize = .zero
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var requests = [VNRequest]()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func setup() {
        setupAVCapture()
        setupLayers()
        setupModels()
        startCaptureSession()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        setup()
    }

    func startCaptureSession() {
        session.startRunning()
    }

    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
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
        let captureConnection = videoDataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        do {
            try videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
    }

    func setupLayers() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
    }
}

extension ViewController {
    func setupModels() {
        guard let modelURL = Bundle.main.url(forResource: "best100", withExtension: "mlmodelc") else {
            return
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel) { request, _ in
                DispatchQueue.main.async {
                    if let results = request.results {
                        self.drawVisionRequestResults(results)
                    }
                }
            }
            requests = [objectRecognition]
        } catch {
            print("Model loading went wrong: \(error)")
        }
    }

    func drawVisionRequestResults(_ results: [Any]) {
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }

            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            print("置信度：", topLabelObservation.confidence)
            print("内容：", topLabelObservation.identifier)
            print("边框", objectBounds)
        }
    }

    func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:
            exifOrientation = .down
        case UIDeviceOrientation.portrait:
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let exifOrientation = exifOrientationFromDeviceOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
}


