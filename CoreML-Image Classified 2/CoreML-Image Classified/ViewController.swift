//
//  ViewController.swift
//  CoreML-Image Classified
//
//  Created by 杨帆 on 2022/5/4.
//

import CoreML
import PhotosUI
import UIKit

class ViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var animalInfo: UILabel!

    lazy var pickerViewController: PHPickerViewController = {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = PHPickerFilter.any(of: [.images, .videos, .livePhotos])
        var pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        return pickerViewController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        present(pickerViewController, animated: true, completion: nil)
    }

    private func analyze(image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        do {
            // 自定义配置
            let config = MLModelConfiguration()
            config.allowLowPrecisionAccumulationOnGPU = true
            // CPU、GPU和NN
            config.computeUnits = .all
            let model = try AnimalClassifier(configuration: config)
            // 通过input，图片不用调整大小和转换CVPixelBuffer
            let input = try AnimalClassifierInput(imageWith: cgImage)
            let output = try model.prediction(input: input)
            DispatchQueue.main.async {
                self.imageView.image = image
                self.animalInfo.text = output.classLabel
            }
        } catch {
            print(error)
        }
    }
}

// MARK: - PHPickerViewControllerDelegate
extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard !results.isEmpty else { return }
        let itemProvider = results.first!.itemProvider
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                guard error == nil else { return }
                guard let image = object as? UIImage else { return }
                // 显示图片
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
                // 分析图片
                self.analyze(image: image)
            }
        }
    }
}

// MARK: - 还可以扩展模型
extension AnimalClassifier {
}
