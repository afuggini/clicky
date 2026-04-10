//
//  AIModelConfig.swift
//  leanring-buddy
//
//  Central configuration for all AI model selections. Change models here
//  instead of hunting through individual files.
//

import Foundation

enum AIModelConfig {

    // MARK: - Chat Models (OpenRouter)

    struct ChatModel: Identifiable {
        let label: String
        let modelID: String

        var id: String { modelID }
    }

    /// Models available in the in-app model picker. Each entry is a
    /// user-facing label paired with the OpenRouter model ID.
    static let availableChatModels: [ChatModel] = [
        ChatModel(label: "Sonnet", modelID: "google/gemma-4-26b-a4b-it"),
        ChatModel(label: "Opus", modelID: "google/gemma-4-26b-a4b-it"),
    ]

    /// The model ID selected by default on first launch.
    static let defaultChatModelID = "google/gemma-4-26b-a4b-it"

    // MARK: - Transcription (OpenAI)

    /// OpenAI transcription model used for push-to-talk voice input.
    static let transcriptionModel = "gpt-4o-transcribe"

    // MARK: - Text-to-Speech

    enum TTSProvider: String, CaseIterable, Identifiable {
        case openAI = "openai"
        case apple = "apple"

        var id: String { rawValue }

        var displayLabel: String {
            switch self {
            case .openAI: return "OpenAI"
            case .apple: return "Apple"
            }
        }
    }

    /// Which TTS provider to use by default on first launch.
    static let defaultTTSProvider: TTSProvider = .openAI

    /// OpenAI TTS model for spoken responses.
    static let ttsModel = "tts-1"

    /// OpenAI TTS voice. Options: alloy, ash, ballad, coral, echo, fable,
    /// onyx, nova, sage, shimmer.
    static let ttsVoice = "alloy"
}
