//
//  ViewController.swift
//  CoreML-OnDeviceUpdate
//
//  Created by 杨帆 on 2022/5/18.
//

import CoreML
import PhotosUI
import UIKit
import Vision

enum AnimalType {
    case dog
    case cat
}

class ViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var info: UILabel!
    @IBOutlet var pickerView: UIPickerView!

    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        return picker
    }()

    // 模型存储路径
    lazy var modelURL: URL = {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = documentDirectory.appendingPathComponent("Update.mlmodelc")
        return modelURL
    }()

    // 训练进度
    lazy var progressHandler = { (context: MLUpdateContext) in
        switch context.event {
        case .trainingBegin:
            print("Training begin")
        case .miniBatchEnd:
            let batchIndex = context.metrics[.miniBatchIndex] as! Int
            let batchLoss = context.metrics[.lossValue] as! Double
            print("Mini batch \(batchIndex), loss: \(batchLoss)")
        case .epochEnd:
            let epochIndex = context.metrics[.epochIndex] as! Int
            let trainLoss = context.metrics[.lossValue] as! Double
            print("Epoch \(epochIndex), loss: \(trainLoss)")
        default: print("Unknown event")
        }
    }

    // 成功回调
    lazy var completionHandler = { (context: MLUpdateContext) in
        if context.task.state == .failed { return }
        let trainLoss = context.metrics[.lossValue] as! Double
        print("Final loss: \(trainLoss)")
        // 保存新的模型
        do {
            try context.model.write(to: self.modelURL)
            print("更新完成")
            DispatchQueue.main.async {
                self.imageLabelDictionary = [:]
                self.updatableModel = self.loadModel(url: self.modelURL)
            }
        } catch {
            print(error)
        }
    }

    // 图片与标签
    var imageLabelDictionary: [UIImage: String] = [:]
    // 更新不能增加新的分类
    var content = ["Dog", "Cat"]
    var updatableModel: MLModel!
    var bundleUrl = CatDogUpdatable.urlOfModelInThisBundle

    override func viewDidLoad() {
        super.viewDidLoad()

        print(bundleUrl)
        // 设置数据源
        pickerView.dataSource = self
        // 设置代理
        pickerView.delegate = self
        // 优先加载沙盒模型
        if let model = loadModel(url: modelURL) {
            updatableModel = model
        } else {
            if let model = loadModel(url: bundleUrl) {
                updatableModel = model
            }
        }
    }

    @IBAction func tap(_ sender: Any) {
        present(imagePicker, animated: true)
    }

    func loadModel(url: URL) -> MLModel? {
        do {
            return try MLModel(contentsOf: url, configuration: MLModelConfiguration())
        } catch {
            print(error)
            return nil
        }
    }

    // MARK: 更新模型
    func updateModel() {
        let config = MLModelConfiguration()
        do {
            // 提供新的训练数据
            let trainingData = try prepareTrainingDatas()
            // 判断是否存在，不存在就用原来的模型进行训练
            if FileManager.default.fileExists(atPath: modelURL.path) {
                bundleUrl = modelURL
            }
            print(imageLabelDictionary)
            let handlers = MLUpdateProgressHandlers(forEvents: [.trainingBegin, .miniBatchEnd, .epochEnd],
                                                    progressHandler: progressHandler,
                                                    completionHandler: completionHandler)
            let updateTask = try MLUpdateTask(forModelAt: bundleUrl,
                                              trainingData: trainingData,
                                              configuration: config,
                                              progressHandlers: handlers)

            updateTask.resume()
        } catch {
            print("出错了", error.localizedDescription)
        }
    }

    // MARK: 封装一个新的训练数据
    func prepareTrainingDatas() throws -> MLArrayBatchProvider {
        var featureProviders: [MLFeatureProvider] = []
        for (image, label) in imageLabelDictionary {
            do {
                let input = try CatDogUpdatableTrainingInput(imageWith: image.cgImage!, classLabel: label)
                featureProviders.append(input)
            } catch {
                print("出错了", error.localizedDescription)
            }
        }
        return MLArrayBatchProvider(array: featureProviders)
    }

    // MARK: 预测数据
    private func analyzeImage(image: UIImage) -> AnimalType? {
        do {
            let featureValue = try MLFeatureValue(cgImage: image.cgImage!,
                                                  constraint: updatableModel.modelDescription.inputDescriptionsByName["image"]!.imageConstraint!,
                                                  options: [
                                                      .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue,
                                                  ])
            let featureProviderDict = try MLDictionaryFeatureProvider(dictionary: ["image": featureValue])
            let prediction = try updatableModel?.prediction(from: featureProviderDict)
            let value = prediction?.featureValue(for: "classLabel")?.stringValue
            info.text = value
            if value == "Dog" {
                return .dog
            } else {
                return .cat
            }
        } catch {
            print("出错了", error.localizedDescription)
        }
        return nil
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
        let animal = analyzeImage(image: image)
        if let animal = animal {
            if animal == .dog {
                pickerView.selectRow(0, inComponent: 0, animated: true)
            } else if animal == .cat {
                pickerView.selectRow(1, inComponent: 0, animated: true)
            }
        } else {
            self.info.text = "Neither dog nor cat."
        }
    }
}

extension ViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return content.count
    }

    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {
        return content[row]
    }

    // MARK: UIPickerViewDelegate代理方法，选择数据列（滚动的时候调用）
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if let image = imageView.image {
            info.text = content[row]
            imageLabelDictionary[image] = content[row]
            updateModel()
        }
    }
}
