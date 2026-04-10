//
//  OpenAITTSClient.swift
//  leanring-buddy
//
//  Sends text-to-speech requests to OpenAI's TTS API via the Worker proxy
//  and plays back the resulting audio through the system audio output.
//  Supports queued playback so multiple sentences play back-to-back
//  without gaps.
//

import AVFoundation
import Foundation

@MainActor
final class OpenAITTSClient: NSObject, AVAudioPlayerDelegate {
    private let proxyURL: URL
    private let session: URLSession

    /// Queue of audio data waiting to be played, in order.
    private var audioQueue: [Data] = []

    /// The audio player for the currently playing chunk.
    private var currentPlayer: AVAudioPlayer?

    /// True while any audio is playing or queued to play.
    private(set) var isPlaying: Bool = false

    /// Continuation resumed when the entire queue finishes playing.
    /// Used by `waitUntilFinished()` so callers can await all queued audio.
    private var finishedContinuation: CheckedContinuation<Void, Never>?

    init(proxyURL: String) {
        self.proxyURL = URL(string: proxyURL)!

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)

        super.init()
    }

    /// Fetches TTS audio for `text` and either plays it immediately (if
    /// nothing is playing) or enqueues it to play after the current audio
    /// finishes. Returns as soon as the audio data is downloaded — it does
    /// NOT wait for playback to complete.
    func enqueueText(_ text: String) async throws {
        let audioData = try await fetchTTSAudio(for: text)

        try Task.checkCancellation()

        if currentPlayer == nil || !isPlaying {
            playAudioData(audioData)
        } else {
            audioQueue.append(audioData)
        }
    }

    /// Sends `text` to OpenAI TTS and plays the resulting audio.
    /// Waits until playback finishes before returning.
    /// For single-shot use when you don't need queued playback.
    func speakText(_ text: String) async throws {
        try await enqueueText(text)
        await waitUntilFinished()
    }

    /// Suspends until all queued audio (including the currently playing
    /// chunk) has finished playing. Returns immediately if nothing is
    /// playing.
    func waitUntilFinished() async {
        guard isPlaying else { return }

        await withCheckedContinuation { continuation in
            // If playback finished between the guard and here, resume now
            if !isPlaying {
                continuation.resume()
            } else {
                finishedContinuation = continuation
            }
        }
    }

    /// Stops any in-progress playback and clears the queue.
    func stopPlayback() {
        audioQueue.removeAll()
        currentPlayer?.stop()
        currentPlayer = nil
        markFinishedIfQueueEmpty()
    }

    // MARK: - Private

    private func fetchTTSAudio(for text: String) async throws -> Data {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": AIModelConfig.ttsModel,
            "voice": AIModelConfig.ttsVoice,
            "input": text
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAITTS", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAITTS", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "TTS API error (\(httpResponse.statusCode)): \(errorBody)"])
        }

        return data
    }

    private func playAudioData(_ audioData: Data) {
        do {
            let player = try AVAudioPlayer(data: audioData)
            player.delegate = self
            self.currentPlayer = player
            self.isPlaying = true
            player.play()
            print("🔊 OpenAI TTS: playing \(audioData.count / 1024)KB audio (\(audioQueue.count) queued)")
        } catch {
            print("⚠️ OpenAI TTS: failed to create player: \(error)")
            playNextOrFinish()
        }
    }

    private func playNextOrFinish() {
        if let nextAudioData = audioQueue.first {
            audioQueue.removeFirst()
            playAudioData(nextAudioData)
        } else {
            currentPlayer = nil
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

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            playNextOrFinish()
        }
    }
}
