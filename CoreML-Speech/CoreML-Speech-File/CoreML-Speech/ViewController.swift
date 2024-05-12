//
//  ViewController.swift
//  CoreML-Speech
//
//  Created by 杨帆 on 2022/5/13.
//

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

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(label)
        // 检查权限
        checkPermission()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        recognizeVoice()
    }

    // MARK: 语音识别
    func recognizeVoice() {
        // 语音文件
        let url = Bundle.main.url(forResource: "sound", withExtension: "mp3")!
        // 语音识别器
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_Hans_CN"))
        // 音频文件地址
        let request = SFSpeechURLRecognitionRequest(url: url)

        // 开始识别
        recognizer?.recognitionTask(with: request) { [unowned self] result, error in
            self.label.text = "正在识别..."
            guard let result = result else {
                print(error?.localizedDescription)
                return
            }
            // 识别完毕
            if result.isFinal {
                self.label.text = result.bestTranscription.formattedString
            }
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
