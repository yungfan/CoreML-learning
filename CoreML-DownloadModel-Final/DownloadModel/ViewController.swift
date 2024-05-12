//
//  ViewController.swift
//  DownloadModel
//
//  Created by 杨帆 on 2022/5/8.
//

import CoreML
import PhotosUI
import UIKit
import Vision

class ViewController: UIViewController {
    // 下载进度
    @IBOutlet var downloadProgress: UIProgressView!
    // 显示识别结果
    @IBOutlet var resultLb: UILabel!
    @IBOutlet var imageView: UIImageView!
    // 模型
    var model: MLModel!

    lazy var pickerViewController: PHPickerViewController = {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        var pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        return pickerViewController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        download()
    }

    @IBAction func selectImage(_ sender: Any) {
        present(pickerViewController, animated: true)
    }

    // MARK: 下载模型
    func download() {
        let url = URL(string: "http://192.168.0.97:8080/AppTestAPI/AnimalClassifier.mlmodel")!
        let request = URLRequest(url: url)
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: self,
                                 delegateQueue: OperationQueue())
        let task = session.downloadTask(with: request)
        task.resume()
    }
}

// MARK: - URLSessionDownloadDelegate
extension ViewController: URLSessionDownloadDelegate {
    // MARK: 下载完成
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let savePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let fileName = "AnimalClassifier.mlmodelc"
        let filePath = savePath + "/" + fileName
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            // 下载后编译，仍然是在tmp中
            let compiledUrl = try MLModel.compileModel(at: location)
            // 已经存在则删除
            if FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.removeItem(at: fileURL)
            }
            // 从tmp中移动到Documents中
            try FileManager.default.moveItem(at: compiledUrl, to: fileURL)
            // 编译后创建MLModel
            model = try MLModel(contentsOf: fileURL, configuration: MLModelConfiguration())
        } catch {
            print(error.localizedDescription)
        }
    }

    // MARK: 计算下载进度
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            self.downloadProgress.setProgress(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite), animated: true)
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
                guard let image = object as? UIImage, let cgimage = image.cgImage else { return }
                // 由于本地没有模型，所以不能直接使用Model自动生成API，此时需要用间接的方式来操作
                // 1. 创建constraint，此时的model是MLModel
                let imageConstraint = self.model.modelDescription.inputDescriptionsByName["image"]!.imageConstraint!
                // 2. 创建options
                let imageOptions = [MLFeatureValue.ImageOption.cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue]
                do {
                    // 3. 根据1和2创建MLFeatureValue，iOS13之后使用MLFeatureValue，图片不用调整大小和转换CVPixelBuffer
                    let featureValue = try MLFeatureValue(cgImage: cgimage, constraint: imageConstraint, options: imageOptions)
                    // 4. 创建输入
                    let inputs = ["image": featureValue]
                    // 5. 创建provider
                    let provider = try MLDictionaryFeatureProvider(dictionary: inputs)
                    // 6. 预测
                    let result = try self.model.prediction(from: provider)
                    DispatchQueue.main.async {
                        self.imageView.image = image
                        // 7. 获取结果
                        self.resultLb.text = result.featureValue(for: "classLabel")?.stringValue
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
