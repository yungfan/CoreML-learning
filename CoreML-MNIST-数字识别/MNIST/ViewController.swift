//
//  ViewController.swift
//  MNIST
//
//  Created by 杨帆 on 2022/5/12.
//

import CoreML
import UIKit
import Vision

class ViewController: UIViewController {
    @IBOutlet var result: UILabel!
    // 涂鸦区域视图
    @IBOutlet var drawView: DrawView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // 识别
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let image = drawView.getSignature()

        do {
            let model = try MNISTClassifier(configuration: MLModelConfiguration())
            guard let cgimage = image.cgImage else { return }
            let input: [MNISTClassifierInput] = [try .init(imageWith: cgimage)]
            let result = try model.predictions(inputs: input)
            DispatchQueue.main.async {
                if let number = result.first?.classLabel {
                    self.result.text = "\(number)"
                } else {
                    self.result.text = "未识别"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.drawView.clearSignature()
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
