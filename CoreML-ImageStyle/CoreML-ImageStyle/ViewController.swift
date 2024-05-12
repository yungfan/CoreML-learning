//
//  ViewController.swift
//  CoreML-ImageStyle
//
//  Created by 杨帆 on 2022/5/29.
//

import CoreML
import UIKit
import Vision

class ViewController: UIViewController {
    @IBOutlet var originImageView: UIImageView!
    @IBOutlet var tranformImageView: UIImageView!

    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        return picker
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func tranform(_ sender: Any) {
        present(imagePicker, animated: true)
    }

    // MARK: 分析图片
    private func analyze(image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        do {
            let config = MLModelConfiguration()
            config.allowLowPrecisionAccumulationOnGPU = true
            config.computeUnits = .all
            let model = try AnimeGANv2(configuration: config)
            let input = try AnimeGANv2Input(inputWith: cgImage)
            let output = try model.prediction(input: input)
            DispatchQueue.main.async {
                self.tranformImageView.image = UIImage(pixelBuffer: output.output)
            }
        } catch {
            print(error)
        }
    }

    private func analyze2(image: UIImage) {
        DispatchQueue.global().async {
            guard let cgImage = image.cgImage else { return }
            do {
                let model = try photo2cartoon(configuration: MLModelConfiguration())
                let input = try photo2cartoonInput(faceWith: cgImage)
                let output = try model.prediction(input: input)
                DispatchQueue.main.async {
                    self.tranformImageView.image = output.cartoon.image()
                }
            } catch {
                print(error)
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
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        originImageView.image = image
        // 分析
        analyze2(image: image)
    }
}
