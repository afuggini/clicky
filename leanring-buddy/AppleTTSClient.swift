//
//  AppleTTSClient.swift
//  leanring-buddy
//
//  On-device text-to-speech using macOS AVSpeechSynthesizer.
//  Free, zero network latency, runs entirely locally.
//

import AVFoundation
import Foundation
import NaturalLanguage

@MainActor
final class AppleTTSClient: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    /// Queue of text waiting to be spoken, in order.
    private var textQueue: [String] = []

    /// True while any speech is playing or queued.
    private(set) var isPlaying: Bool = false

    /// Continuation resumed when the entire queue finishes speaking.
    private var finishedContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `text` immediately or enqueues it after the current utterance.
    /// Returns as soon as speech starts or is queued — does NOT wait for
    /// playback to complete.
    func enqueueText(_ text: String) {
        if synthesizer.isSpeaking {
            textQueue.append(text)
        } else {
            speakNow(text)
        }
    }

    /// Suspends until all queued speech has finished. Returns immediately
    /// if nothing is playing.
    func waitUntilFinished() async {
        guard isPlaying else { return }

        await withCheckedContinuation { continuation in
            if !isPlaying {
                continuation.resume()
            } else {
                finishedContinuation = continuation
            }
        }
    }

    /// Stops any in-progress speech and clears the queue.
    func stopPlayback() {
        textQueue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        markFinishedIfQueueEmpty()
    }

    // MARK: - Private

    private func speakNow(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        let detectedLanguage = detectLanguage(for: text)
        utterance.voice = AVSpeechSynthesisVoice(language: detectedLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isPlaying = true
        synthesizer.speak(utterance)
        print("🔊 Apple TTS: speaking \(text.count) chars in \(detectedLanguage) (\(textQueue.count) queued)")
    }

    /// Uses macOS linguistic tagger to detect the dominant language of the
    /// text. Falls back to en-US if detection is inconclusive.
    private func detectLanguage(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominantLanguage = recognizer.dominantLanguage else {
            return "en-US"
        }

        // Map NLLanguage codes (e.g. "es") to BCP 47 locale tags that
        // AVSpeechSynthesisVoice expects (e.g. "es-MX").
        switch dominantLanguage {
        case .spanish:
            return "es-MX"
        case .english:
            return "en-US"
        default:
            // Use the raw language code — AVSpeechSynthesisVoice will pick
            // the best available voice for that language.
            return dominantLanguage.rawValue
        }
    }

    private func speakNextOrFinish() {
        if let nextText = textQueue.first {
            textQueue.removeFirst()
            speakNow(nextText)
        } else {
            markFinishedIfQueueEmpty()
        }
    }

    private func markFinishedIfQueueEmpty() {
        isPlaying = false
        if let continuation = finishedContinuation {
            finishedContinuation = nil
            continuation.resume()
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speakNextOrFinish()
        }
    }
}
