//
//  ViewController.swift
//  CoreML-TextClassifier
//
//  Created by 杨帆 on 2022/5/23.
//

import CoreML
import NaturalLanguage
import UIKit

class ViewController: UIViewController {
    @IBOutlet var textView: UITextView!
    @IBOutlet var result: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func classify(_ sender: Any) {
        let inputText = textView.text

        do {
            let mlModel = try SpamTextClassifier(configuration: MLModelConfiguration()).model
            let sentimentPredictor = try NLModel(mlModel: mlModel)
            if let inputText = inputText {
                let result = sentimentPredictor.predictedLabel(for: inputText)
                self.result.text = result
            }
        } catch {
            print(error)
        }
    }
}
