//
//  ViewController.swift
//  CoreML-Speech
//
//  Created by 杨帆 on 2022/5/13.
//

import AVKit
import Speech
import UIKit

class ViewController: UIViewController {
    lazy var label: UILabel = {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        label.text = "显示结果"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.center = view.center
        return label
    }()

    var recognizer: SFSpeechRecognizer!
    var speechTask: SFSpeechRecognitionTask?
    // 语音识别器
    lazy var request: SFSpeechAudioBufferRecognitionRequest = {
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        return recognitionRequest
    }()

    lazy var audioEngine: AVAudioEngine = {
        let audioEngine = AVAudioEngine()
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            // 获取声音数据
            self.request.append(buffer)
        }
        return audioEngine
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // view.addSubview(label)
        // 检查权限
        checkPermission()

        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_Hans_CN"))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        recognizeVoice()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        speechTask?.cancel()
        label.text = "显示结果"
    }

    // MARK: 语音识别
    func recognizeVoice() {
        prepareForRecording()
        // 开始识别
        speechTask = recognizer?.recognitionTask(with: request) { [unowned self] result, error in
            self.label.text = "正在识别..."
            guard let result = result else {
                print(error?.localizedDescription)
                return
            }

            // 总文本
            let textTotal = result.bestTranscription.formattedString
            // 单次文本
            let text = result.bestTranscription.segments.last?.substring

            label.text = textTotal

            if text?.prefix(2) == "红色" {
                self.view.backgroundColor = .red
            }
            if text?.prefix(2) == "蓝色" {
                self.view.backgroundColor = .blue
            }
            if text?.prefix(2) == "绿色" {
                self.view.backgroundColor = .green
            }
            if text?.prefix(2) == "随机" {
                self.view.backgroundColor = UIColor(displayP3Red: .random(in: 0 ... 1),
                                                    green: .random(in: 0 ... 1),
                                                    blue: .random(in: 0 ... 1),
                                                    alpha: 1.0)
            }
        }
    }

    private func prepareForRecording() {
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            showAudioError()
        }
    }
}

extension ViewController {
    // MARK: 请求授权
    func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    print("同意授权")
                } else {
                    print("不同意授权")
                }
            }
        }
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
