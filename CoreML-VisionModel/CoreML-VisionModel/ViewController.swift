//
//  ViewController.swift
//  CoreML-VisionModel
//
//  Created by 杨帆 on 2022/5/16.
//

import CoreML
import UIKit
import Vision

class ViewController: UIViewController {
    private lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let config = MLModelConfiguration()
            // 注意点：替换自己的Model
            let model = try VNCoreMLModel(for: MobileNetV2(configuration: config).model)
            let request = VNCoreMLRequest(model: model) { request, _ in
                // 3 处理结果
                self.handle(request.results)
            }
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()

    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        return picker
    }()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        present(imagePicker, animated: true)
    }

    // MARK: 分析图片
    func analyze(_ image: UIImage) {
        guard let orientation = CGImagePropertyOrientation(
            rawValue: UInt32(image.imageOrientation.rawValue)) else {
            return
        }
        guard let ciImage = CIImage(image: image) else {
            fatalError("Unable to create \(CIImage.self) from \(image).")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                // 2 执行请求
                try handler.perform([self.classificationRequest])
            } catch {
                print("Failed to perform task.\n\(error.localizedDescription)")
            }
        }
    }

    // MARK: 处理结果
    func handle(_ results: [VNObservation]?) {
        // 注意点：转换成当前任务的Observation
        let obs = results as? [VNClassificationObservation]
        if let obs = obs {
            for ob in obs {
                print(ob.identifier, ob.confidence)
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            fatalError("Unable to get image from Album.")
        }
        // 1 选择照片之后开始分析
        analyze(image)
    }
}
