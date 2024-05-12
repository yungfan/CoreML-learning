//
//  ViewController.swift
//  Vision-OCR
//
//  Created by 杨帆 on 2022/5/17.
//

import UIKit
import Vision
import VisionKit

class ViewController: UIViewController {
    // 显示图片
    lazy var imageView: UIImageView = {
        var imageView = UIImageView(image: UIImage(systemName: "photo"))
        imageView.frame = CGRect(x: 20, y: 80, width: UIScreen.main.bounds.width - 40, height: 300)
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapImage)))
        return imageView
    }()

    // 显示进度
    lazy var indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.center = CGPoint(x: UIScreen.main.bounds.width * 0.5, y: (80 + 300) * 0.5)
        indicator.style = .large
        indicator.color = .systemPurple
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // 显示结果
    lazy var resultText: UITextView = {
        var textView = UITextView()
        textView.frame = CGRect(x: 20, y: 400, width: UIScreen.main.bounds.width - 40, height: 500)
        textView.text = "结果"
        textView.font = UIFont(name: "Helvetica", size: 15)
        textView.isEditable = false
        return textView
    }()

    // Vision请求
    lazy var request: VNRecognizeTextRequest = {
        var textLayers: [CALayer] = []
        let textDetectionRequest = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            // 处理结果
            DispatchQueue.main.async {
                self.indicator.stopAnimating()
                var resultStr = ""
                for observation in observations {
                    for candidate in observation.topCandidates(1) {
                        resultStr += candidate.string + "\n"
                    }
                }
                self.resultText.text = resultStr
                // 添加边框
                textLayers = self.addShapeToText(forObservations: observations, withImageView: self.imageView)
                for layer in textLayers {
                    self.imageView.layer.addSublayer(layer)
                }
            }
        }
        textDetectionRequest.recognitionLanguages = ["zh", "en"]
        textDetectionRequest.recognitionLevel = .accurate
        textDetectionRequest.revision = VNRecognizeTextRequestRevision2
        return textDetectionRequest
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(imageView)
        view.addSubview(resultText)
        view.addSubview(indicator)
    }

    @objc func tapImage(tap: UITapGestureRecognizer) {
        let picker = UIImagePickerController()
        picker.delegate = self
        present(picker, animated: true)
    }

    func startOCR(_ image: UIImage) {
        if let cgImage = image.cgImage {
            // 处理请求
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // 添加边框
    func addShapeToText(forObservations observations: [VNRecognizedTextObservation],
                        withImageView textImageView: UIImageView) -> [CALayer]
    {
        let layers: [CALayer] = observations.map { observation in
            // boundingBox是比例
            let w = observation.boundingBox.size.width * textImageView.bounds.width
            let h = observation.boundingBox.size.height * textImageView.bounds.height
            let x = observation.boundingBox.origin.x * textImageView.bounds.width
            let y = abs((observation.boundingBox.origin.y * textImageView.bounds.height) - textImageView.bounds.height) - h
            let layer = CALayer()
            layer.frame = CGRect(x: x, y: y, width: w, height: h)
            layer.borderColor = UIColor.systemPurple.cgColor
            layer.borderWidth = 1
            return layer
        }
        return layers
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            return
        }
        imageView.image = image

        DispatchQueue.global().async {
            // 清除上一次的结果
            DispatchQueue.main.async {
                self.imageView.layer.sublayers?.forEach { layer in
                    layer.removeFromSuperlayer()
                }
                self.resultText.text = ""
                self.indicator.startAnimating()
            }
            // 开始OCR
            self.startOCR(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
