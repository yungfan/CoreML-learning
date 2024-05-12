//
//  ViewController.swift
//  CoreML-YOLOv3
//
//  Created by 杨帆 on 2022/5/14.
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController {
    private var bufferSize: CGSize = .zero
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var detectionOverlay: CALayer!
    private var requests = [VNRequest]()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func setup() {
        setupAVCapture()
        setupLayers()
        updateLayerGeometry()
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

        detectionOverlay = CALayer()
        detectionOverlay.bounds = CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: view.layer.bounds.midX, y: view.layer.bounds.midY)
        view.layer.addSublayer(detectionOverlay)
    }

    func updateLayerGeometry() {
        let bounds = view.layer.bounds
        var scale: CGFloat
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }
}

extension ViewController {
    func setupModels() {
        guard let modelURL = Bundle.main.url(forResource: "YOLOv3TinyFP16", withExtension: "mlmodelc") else {
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
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }

            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                            identifier: topLabelObservation.identifier,
                                                            confidence: topLabelObservation.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
        updateLayerGeometry()
        CATransaction.commit()
    }

    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.5
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = UIColor.green.cgColor
        textLayer.contentsScale = 2.0
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }

    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.backgroundColor = UIColor.red.withAlphaComponent(0.5).cgColor
        shapeLayer.cornerRadius = 7
        return shapeLayer
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
