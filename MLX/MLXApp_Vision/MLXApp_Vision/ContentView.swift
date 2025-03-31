//
//  ContentView.swift
//  MLXApp_Vision
//
//  Created by 杨帆 on 2025/2/13.
//

import AppKit
import MLXLMCommon
import MLXVLM
import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var image: NSImage?
    @State private var result: String = ""
    @State private var prompt: String = "Describe the image in Chinese."
    @State private var isLoading = false
    @State private var imageSelection: PhotosPickerItem?
    @State private var modelContainer: ModelContainer?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 显示图片
                Group {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 5)
                            .padding(.horizontal)
                            .frame(height: 300)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 300)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                            .padding(.horizontal)
                    }
                }
                .padding(.top)

                // 选择图片
                PhotosPicker(selection: $imageSelection, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("选择图片")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .buttonStyle(.borderless)
                .onChange(of: imageSelection) { _, newValue in
                    Task {
                        if let newValue {
                            if let data = try? await newValue.loadTransferable(type: Data.self),
                               let loadImage = NSImage(data: data) {
                                image = loadImage
                                isLoading = true
                                if let ciImage = CIImage(data: data) {
                                    try await processImage(ciImage)
                                }
                                isLoading = false
                            }
                        }
                    }
                }

                // 显示结果
                VStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding()
                    } else if !result.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("AI分析")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(result)
                                    .lineSpacing(4)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .task {
            do {
                // 加载模型
                let modelConfiguration = ModelRegistry.qwen2VL2BInstruct4Bit
                modelContainer = try await VLMModelFactory.shared.loadContainer(configuration: modelConfiguration) { progress in
                    // 获取下载的进度
                    print("正在下载 \(modelConfiguration.name)，当前进度 \(Int(progress.fractionCompleted * 100))%")
                }
            } catch {
                print(error)
            }
        }
    }
}

extension ContentView {
    // MARK: 图片分析
    func processImage(_ ciImage: CIImage) async throws {
        guard let container = modelContainer else { return }
        // 准备输入
        let input = UserInput(prompt: prompt, images: [.ciImage(ciImage)])
        // 进行推理
        _ = try await container.perform { [input] context in
            let input = try await context.processor.prepare(input: input)
            return try MLXLMCommon.generate(input: input, parameters: .init(), context: context) { tokens in
                Task { @MainActor in
                    self.result = context.tokenizer.decode(tokens: tokens)
                }
                return tokens.count >= 800 ? .stop : .more
            }
        }
    }
}

#Preview {
    ContentView()
}
