//
//  ViewController.swift
//  CoreML-ARKit
//
//  Created by 杨帆 on 2022/5/16.
//

import ARKit
import UIKit

class ViewController: UIViewController {
    private var request: VNCoreMLRequest!

    lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: UIScreen.main.bounds)
        imageView.contentMode = .center
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(imageView)
        setupModels()
        setupARKit()
    }
}

extension ViewController {
    // MARK: 通过ARKit获取实时视频流
    func setupARKit() {
        let sceneView = ARSCNView(frame: imageView.bounds)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        let session = sceneView.session
        session.delegate = self
        session.run(configuration)
    }

    func setupModels() {
        guard let modelURL = Bundle.main.url(forResource: "AnimeGANv2", withExtension: "mlmodelc") else {
            return
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            request = VNCoreMLRequest(model: visionModel) { request, _ in
                DispatchQueue.main.async {
                    guard let results = request.results as? [VNPixelBufferObservation] else {
                        return
                    }

                    for result in results {
                        self.imageView.image = UIImage(ciImage: CIImage(cvPixelBuffer: result.pixelBuffer))
                    }
                }
            }
        } catch {
            print("Model loading went wrong: \(error)")
        }
    }
}

extension ViewController: ARSessionDelegate {
    // MARK: 处理视频流
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if case .normal = frame.camera.trackingState {
            let pixelBuffer: CVPixelBuffer = frame.capturedImage
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try imageRequestHandler.perform([self.request])
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}
