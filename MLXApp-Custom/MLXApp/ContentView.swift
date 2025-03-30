//
//  ContentView.swift
//  MLXApp
//
//  Created by 杨帆 on 2025/2/12.
//

import MLXLLM
import MLXLMCommon
import SwiftUI

// MARK: - 注册自定义模型
extension MLXLLM.ModelRegistry {
    public static let localModel = ModelConfiguration(
        directory: URL(fileURLWithPath: "/Users/yangfan/Desktop/modelscope/Hermes-3-Llama-3.2-3B"),  // 本地模型的路径
        overrideTokenizer: "PreTrainedTokenizer",
        defaultPrompt: ""
    )
}

struct ContentView: View {
    // 提示词
    @State private var prompt: String = "什么是SwiftUI？"
    // 输出结果
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
                    response = ""

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
                ResponseBubble(text: response)
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
    // MARK: 文本生成
    func generate() async throws {
        isLoading = true
        // 加载模型
        let modelConfiguration = ModelRegistry.localModel
        let modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: modelConfiguration) { progress in
            print("正在下载 \(modelConfiguration.name)，当前进度 \(Int(progress.fractionCompleted * 100))%")
        }
        // 生成结果
        let _ = try await modelContainer.perform { [prompt] context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
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
        ScrollView {
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
        .padding(.horizontal)
    }
}


#Preview {
    ContentView()
}
