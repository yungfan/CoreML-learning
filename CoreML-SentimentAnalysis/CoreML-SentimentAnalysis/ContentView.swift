//
//  ContentView.swift
//  CoreML-SentimentAnalysis
//
//  Created by 杨帆 on 2022/5/13.
//

import NaturalLanguage
import SwiftUI

struct ContentView: View {
    @State private var text: String = ""

    private var sentiment: String {
        return performSentimentAnalysis(for: text)
    }

    private let tagger = NLTagger(tagSchemes: [.tokenType, .sentimentScore])

    var body: some View {
        VStack {
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $text)
                    .border(Color.gray, width: 1)
                    .frame(height: 200)

                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                }
                .padding(8)
                .foregroundStyle(Color.white)
                .background(Color.red)
                .clipShape(Circle())
                .frame(width: 40, height: 40)
            }
            .padding()

            image(for: sentiment)?
                .resizable()
                .frame(width: 150, height: 150)

            Text(sentiment)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private func image(for sentiment: String) -> Image? {
        guard let value = Double(sentiment) else {
            return nil
        }

        if value > 0.5 {
            return Image("happy")
        } else if value >= 0 {
            return Image("positive")
        } else if value > -0.5 {
            return Image("worried")
        } else {
            return Image("crying")
        }
    }

    private func performSentimentAnalysis(for string: String) -> String {
        tagger.string = string
        let (sentiment, _) = tagger.tag(at: string.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return sentiment?.rawValue ?? ""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
