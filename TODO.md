# Clicky Performance Optimizations

## 1. Stream TTS in chunks (biggest win)
Split chat response into sentences as they stream in and fire TTS for each sentence independently. First sentence plays while the rest are still generating. Could cut perceived latency from ~8s to ~3-4s.

**Status: DONE**

## 2. Switch to Apple Speech for transcription
Use on-device Speech framework instead of OpenAI Whisper. Saves 1-2s of network round-trip. Accuracy is worse but usually fine for short push-to-talk commands. Change `VoiceTranscriptionProvider` in Info.plist to `apple`.

**Status: TODO**

## 3. Use a faster chat model
Gemma 4 26B works but isn't the fastest. Smaller/faster models on OpenRouter could improve time-to-first-token.

**Status: TODO**

## 4. Parallelize screenshot + transcription
Screenshot is captured after transcription finishes. These should happen simultaneously — capture the screenshot when the user releases the key, in parallel with the transcription upload.

**Status: DONE**

## 5. Use OpenAI TTS streaming
OpenAI has streaming TTS support. Instead of downloading the full MP3 before playback, start playing audio as chunks arrive. Investigate cost difference vs standard TTS.

**Status: TODO**
