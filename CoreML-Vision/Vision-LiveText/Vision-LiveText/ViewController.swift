//
//  ViewController.swift
//  Vision-LiveText
//
//  Created by 杨帆 on 2022/6/17.
//

import UIKit
import VisionKit

class ViewController: UIViewController {
    lazy var label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var dataScannerController: DataScannerViewController = {
        // 创建DataScannerViewController
        let dataScannerController = DataScannerViewController(recognizedDataTypes: [.text(), .barcode()], qualityLevel: .balanced, isHighlightingEnabled: true)
        // 设置代理
        dataScannerController.delegate = self
        return dataScannerController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(label)

        addChild(dataScannerController)
        view.addSubview(dataScannerController.view)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        dataScannerController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dataScannerController.view.topAnchor.constraint(equalTo: view.topAnchor),
            dataScannerController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            dataScannerController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
            dataScannerController.view.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7, constant: -20)])
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: dataScannerController.view.bottomAnchor, constant: 10),
            label.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            label.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            label.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3)])

       
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 判断是否支持
        guard DataScannerViewController.isSupported else { return }
        // 开始扫描
        try? dataScannerController.startScanning()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // dataScannerController.stopScanning()
    }
}

// MARK: - DataScannerViewControllerDelegate
extension ViewController: DataScannerViewControllerDelegate {
    // MARK: 扫描到识别的区域后点击该区域调用
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        print(#function)
        switch item {
        // 获取识别的文本
        case let .text(text):
            label.text = text.transcript
        // 获取识别的二维码信息
        case let .barcode(code):
            label.text = code.payloadStringValue
        default: break
        }
    }
}
