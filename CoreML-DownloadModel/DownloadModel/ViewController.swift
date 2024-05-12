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

enum Type {
    case origin
    case download
}

class ViewController: UIViewController {
    // 下载进度
    @IBOutlet var downloadProgress: UIProgressView!
    // 显示识别结果
    @IBOutlet var resultLb: UILabel!
    @IBOutlet var imageView: UIImageView!
    // 模型
    var model: AnimalClassifier!
    // 区分原始（只能识别2种）和下载的模型（识别多种）
    var type: Type = .origin

    lazy var pickerViewController: PHPickerViewController = {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        var pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        return pickerViewController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func predict(_ sender: Any) {
        present(pickerViewController, animated: true)
    }

    // MARK: 下载模型
    @IBAction func download(_ sender: Any) {
        type = .download
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
            // 编译后创建模型，可以先在本地放一个小模型以免报错
            model = try AnimalClassifier(contentsOf: fileURL, configuration: MLModelConfiguration())
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
                // App内原始的模型预测
                if self.type == .origin {
                    do {
                        // 创建模型
                        let model = try AnimalClassifier(configuration: MLModelConfiguration())
                        // 创建输入
                        let input = try AnimalClassifierInput(imageWith: cgimage)
                        // 预测
                        let result = try model.predictions(inputs: [input])
                        DispatchQueue.main.async {
                            self.imageView.image = image
                            // 获取结果
                            self.resultLb.text = result.first?.classLabel
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                } else { // 用下载后的模型预测
                    do {
                        // 创建输入
                        let input = try AnimalClassifierInput(imageWith: cgimage)
                        // 预测
                        let result = try self.model.predictions(inputs: [input])
                        DispatchQueue.main.async {
                            self.imageView.image = image
                            // 获取结果
                            self.resultLb.text = result.first?.classLabel
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
}
