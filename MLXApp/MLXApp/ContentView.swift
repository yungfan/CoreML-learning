//
//  ContentView.swift
//  MLXApp
//
//  Created by 杨帆 on 2025/2/12.
//

import MLXLLM
import MLXLMCommon
import SwiftUI

import SwiftUI

struct ContentView: View {
    @State private var prompt: String = "什么是SwiftUI？"
    @State private var response: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // 顶部输入区域
            HStack {
                TextField("输入提示词...", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))

                Button {
                    response =  ""
                    
                    Task {
                        do {
                            try await generate()
                        } catch {
                            debugPrint(error)
                        }
                    }
                } label: {
                    Text("生成")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(prompt.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.borderless)
                .disabled(prompt.isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.top)

            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            // 响应展示区域
            if response != "" {
                ScrollView {
                        ResponseBubble(text: response)
                    
                }
                .padding(.horizontal)
            }

            Spacer()
        }

        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .padding()
        }
    }
}

extension ContentView {
    func generate() async throws {
        isLoading = true
        // 加载模型（第一次使用会下载）
        let modelConfiguration = ModelRegistry.llama3_2_1B_4bit
        let modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: modelConfiguration) { progress in
            debugPrint("Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%")
        }
        // 推理
        let _ = try await modelContainer.perform { [prompt] context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
            // 生成结果
            let result = try MLXLMCommon.generate(input: input, parameters: .init(), context: context) { tokens in
                let text = context.tokenizer.decode(tokens: tokens)
                Task { @MainActor in
                    self.response = text
                    self.isLoading = false
                }
                return .more
            }
            return result
        }
    }
}

struct ResponseBubble: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI")
                .font(.system(size: 16))
                .foregroundColor(.gray)

            Text(text)
                .font(.system(size: 16))
                .lineSpacing(4)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

#Preview {
    ContentView()
}
