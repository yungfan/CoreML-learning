//
//  ViewController.swift
//  CoreML-MusicInstruments Classified
//
//  Created by 杨帆 on 2022/5/13.
//

import AVKit
import SoundAnalysis
import UIKit

class ViewController: UIViewController {
    // AVAudioEngine 可以做实时的音效处理
    private let audioEngine = AVAudioEngine()
    private var soundClassifier: MySoundClassifier!
    var streamAnalyzer: SNAudioStreamAnalyzer!
    var results = [(label: String, confidence: Float)]() {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }

    @IBOutlet var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        results = [("暂无数据", 0)]
        tableView.dataSource = self

        do {
            // 1. 创建分类器
            soundClassifier = try MySoundClassifier(configuration: MLModelConfiguration())
        } catch {
            print(error.localizedDescription)
        }
    }

    private func prepareForRecording() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // 2. 创建分析器
        streamAnalyzer = SNAudioStreamAnalyzer(format: recordingFormat)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [unowned self] buffer, when in
            DispatchQueue.global().async {
                // 3. 开始分析
                self.streamAnalyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            showAudioError()
        }
    }

    private func createClassificationRequest() {
        do {
            // 5. 发起请求
            let request = try SNClassifySoundRequest(mlModel: soundClassifier.model)
            try streamAnalyzer.add(request, withObserver: self)
        } catch {
            fatalError("error adding the classification request")
        }
    }

    // 停止实时录音与分析
    @IBAction func stop(_ sender: Any) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        results = [("暂无数据", 0)]
    }

    // 开始录音并分析
    @IBAction func start(_ sender: Any) {
        prepareForRecording()
        // 4. 分析
        createClassificationRequest()
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "abc")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "abc")
        }

        let result = results[indexPath.row]
        let label = convert(id: result.label)
        cell!.textLabel!.text = "\(label): \(result.confidence)"
        return cell!
    }

    private func convert(id: String) -> String {
        let mapping = ["cel": "drum", "cla": "clarinet", "flu": "flute",
                       "gac": "acoustic guitar", "gel": "electric guitar",
                       "org": "organ", "pia": "piano", "sax": "saxophone",
                       "tru": "trumpet", "vio": "violin", "voi": "human voice"]
        return mapping[id] ?? id
    }
}

extension ViewController: SNResultsObserving {
    // 6. 结果分析
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        var temp = [(label: String, confidence: Float)]()
        let sorted = result.classifications.sorted { (first, second) -> Bool in
            first.confidence > second.confidence
        }
        for classification in sorted {
            let confidence = classification.confidence * 100
            if confidence > 5 {
                temp.append((label: classification.identifier, confidence: Float(confidence)))
            }
        }
        results = temp
    }
}

extension ViewController {
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    func showAudioError() {
        let errorTitle = "Audio Error"
        let errorMessage = "Recording is not possible!"
        showAlert(title: errorTitle, message: errorMessage)
    }
}
