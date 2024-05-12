//
//  ViewController.swift
//  CoreML-CreateML in iOS
//
//  Created by 杨帆 on 2022/5/18.
//

import Combine
import CoreML
import CreateML
import UIKit
import Vision

class ViewController: UIViewController {
    @IBOutlet var resultLb: UILabel!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var trainButton: UIButton!
    @IBOutlet var trainingProgress: UIProgressView!
    var subscriptions = Set<AnyCancellable>()
    var cancellable: AnyCancellable!

    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        return picker
    }()

    // 训练好的模型存放到沙盒
    lazy var modelURL: URL = {
        let savePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let modelPath = savePath + "/" + "model.mlmodel"
        let modelURL = URL(fileURLWithPath: modelPath)
        return modelURL
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // 给按钮创建菜单
        trainButton.menu = createMenu()
    }

    @IBAction func selectData(_ sender: Any) {
        present(imagePicker, animated: true)
    }

    func trainingModel(folderName: String) {
        do {
            // 数据源目录，一定要记得选择Copy items & Create folder references，千万不要Create group！！！
            let trainDirectory = Bundle.main.resourceURL!.appendingPathComponent("Train/\(folderName)").path
            // 创建数据源
            let data = MLImageClassifier.DataSource.labeledDirectories(at: URL(fileURLWithPath: trainDirectory))
            // 训练数据
            let job = try MLImageClassifier.train(trainingData: data, parameters: MLImageClassifier.ModelParameters(augmentation: [.noise, .rotation, .crop]))

            // 订阅获取训练的阶段
            job.phase.sink { phase in
                // 可能是个bug
                // 在训练阶段取消，evaluating阶段的进度不会干扰训练的进度，否则会不一致
                if phase == .training {
                    self.cancellable.cancel()
                }
            }.store(in: &subscriptions)

            // 订阅获取训练的进度
            cancellable = job.progress.publisher(for: \.fractionCompleted)
                .sink { [weak job] fractionCompleted in
                    guard let job = job, let progress = MLProgress(progress: job.progress) else {
                        return
                    }

                    let completed = Float(String(format: "%.2f", fractionCompleted))! * 1000

                    let info = "Progress: \(completed) %, Iteration: \(progress.itemCount) of \(progress.totalItemCount ?? 0)"

                    DispatchQueue.main.async {
                        self.resultLb.text = info
                        self.trainingProgress.progress = Float(fractionCompleted * 10)

                        if fractionCompleted == 0.1 {
                            self.resultLb.text = "训练完成，正在保存模型"
                        }
                    }
                }

            // 订阅获取训练好的模型
            job.result.sink { result in
                print("--------------------------\(result)")
            } receiveValue: { model in
                do { // 保存模型
                    try model.write(to: self.modelURL)

                    DispatchQueue.main.async {
                        self.resultLb.text = "模型生成完毕，请测试"
                    }
                } catch {
                    print(error)
                }
            }
            .store(in: &subscriptions)

            // 订阅查看检测点
            job.checkpoints.sink { checkpoint in
                print(checkpoint)
            }
            .store(in: &subscriptions)
        } catch {
            print(error)
        }
    }

    func analyzeImage(image: UIImage) {
        do {
            // 编译模型
            let compiledURL = try MLModel.compileModel(at: modelURL)
            // 创建模型
            let mlModel = try MLModel(contentsOf: compiledURL)
            // 创建输入
            guard let cgimage = image.cgImage else { return }
            let imageConstraint = mlModel.modelDescription.inputDescriptionsByName["image"]!.imageConstraint!
            let imageOptions = [MLFeatureValue.ImageOption.cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue]
            let featureValue = try MLFeatureValue(cgImage: cgimage, constraint: imageConstraint, options: imageOptions)
            let inputs = ["image": featureValue]
            // 封装MLDictionaryFeatureProvider
            let provider = try MLDictionaryFeatureProvider(dictionary: inputs)
            // 预测
            let result = try mlModel.prediction(from: provider)
            // 显示结果
            DispatchQueue.main.async {
                self.resultLb.text = result.featureValue(for: "classLabel")?.stringValue
            }
        } catch {
            print(error)
        }
    }

    // MARK: 创建菜单
    func createMenu() -> UIMenu {
        let one = UIAction(title: "Fruit") { _ in
            self.setTrainingInfo(folderName: "Fruit")
        }
        let two = UIAction(title: "Shape") { _ in
            self.setTrainingInfo(folderName: "Shape")
        }
        let menuActions = [one, two]
        let menu = UIMenu(children: menuActions)
        return menu
    }

    // MARK: 菜单功能
    func setTrainingInfo(folderName: String) {
        trainingModel(folderName: folderName)
        resultLb.text = "即将显示模型训练过程信息"
        trainingProgress.progress = 0
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
        // 分析图片
        analyzeImage(image: image)
    }
}
