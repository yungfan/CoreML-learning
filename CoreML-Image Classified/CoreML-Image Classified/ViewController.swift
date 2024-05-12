//
//  ViewController.swift
//  CoreML-Image Classified
//
//  Created by 杨帆 on 2022/5/4.
//

import CoreML
import UIKit

class ViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var fruitInfo: UILabel!

    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        return picker
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        present(imagePicker, animated: true)
    }

    private func analyze(image: UIImage?) {
        // 图片按照模型调整尺寸后转CVPixelBuffer
        guard let buffer = image?.resize(size: CGSize(width: 299, height: 299))?
            .convertToBuffer() else { return }

        do {
            let model = try AnimalClassifier(configuration: MLModelConfiguration())
            let output = try model.prediction(image: buffer)
            fruitInfo.text = output.classLabel
        } catch {
            print(error.localizedDescription)
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
            return
        }
        imageView.image = image
        // 分析
        analyze(image: image)
    }
}
