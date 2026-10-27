// Spike A: compare on-device Korean STT engines on the same recording.
//
// Usage: swift run -c release stt-bench <audio.m4a> [reference.txt] [whisperkit|speech|all]
//
// Prints wall-clock time, real-time factor and, when a reference transcript is given,
// character error rate (CER). Transcripts are written next to the audio file.

import AVFoundation
import Foundation
import Speech
import WhisperKit

struct BenchResult {
    let engine: String
    let text: String
    let seconds: Double
}

func audioDuration(_ url: URL) throws -> Double {
    let file = try AVAudioFile(forReading: url)
    return Double(file.length) / file.processingFormat.sampleRate
}

func runWhisperKit(_ url: URL) async throws -> BenchResult {
    // The first run downloads the model from Hugging Face; later runs are fully offline.
    // Time is measured after loading so the comparison reflects transcription only.
    let pipe = try await WhisperKit(WhisperKitConfig(model: "large-v3-v20240930_turbo"))
    let start = Date()
    let results = try await pipe.transcribe(audioPath: url.path, decodeOptions: DecodingOptions(language: "ko"))
    let text = results.map(\.text).joined(separator: "\n")
    return BenchResult(engine: "whisperkit", text: text, seconds: Date().timeIntervalSince(start))
}

func runSpeechAnalyzer(_ url: URL) async throws -> BenchResult {
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "ko-KR")) else {
        throw NSError(domain: "stt-bench", code: 1, userInfo: [NSLocalizedDescriptionKey: "SpeechTranscriber does not support ko-KR on this OS"])
    }
    let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try await request.downloadAndInstall()
    }
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    let audioFile = try AVAudioFile(forReading: url)

    let start = Date()
    async let collected: String = transcriber.results.reduce(into: "") { text, result in
        text += String(result.text.characters)
    }
    if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
        try await analyzer.finalizeAndFinish(through: lastSample)
    } else {
        await analyzer.cancelAndFinishNow()
    }
    let text = try await collected
    return BenchResult(engine: "speechanalyzer", text: text, seconds: Date().timeIntervalSince(start))
}

/// Character error rate, ignoring whitespace and punctuation (Korean spacing varies a lot between engines).
func characterErrorRate(hypothesis: String, reference: String) -> Double {
    func normalize(_ s: String) -> [Character] {
        Array(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }
    let h = normalize(hypothesis), r = normalize(reference)
    guard !r.isEmpty else { return h.isEmpty ? 0 : 1 }
    var previous = Array(0...h.count)
    for i in 1...r.count {
        var current = [i] + Array(repeating: 0, count: h.count)
        for j in stride(from: 1, through: h.count, by: 1) {
            let cost = r[i - 1] == h[j - 1] ? 0 : 1
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        }
        previous = current
    }
    return Double(previous[h.count]) / Double(r.count)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: stt-bench <audio> [reference.txt] [whisperkit|speech|all]")
    exit(2)
}
let audioURL = URL(fileURLWithPath: args[1])
let reference: String? = if args.count >= 3, args[2] != "-" {
    try String(contentsOfFile: args[2], encoding: .utf8)
} else {
    nil
}
let engine = args.count >= 4 ? args[3] : "all"
let duration = try audioDuration(audioURL)
print(String(format: "audio: %@ (%.1f min)", audioURL.lastPathComponent, duration / 60))

var runs: [() async throws -> BenchResult] = []
if engine == "all" || engine == "whisperkit" { runs.append { try await runWhisperKit(audioURL) } }
if engine == "all" || engine == "speech" { runs.append { try await runSpeechAnalyzer(audioURL) } }

for run in runs {
    do {
        let result = try await run()
        let out = audioURL.deletingPathExtension().appendingPathExtension("\(result.engine).txt")
        try result.text.write(to: out, atomically: true, encoding: .utf8)
        var line = String(format: "%-15@ time %6.1fs  RTF %.3f", result.engine, result.seconds, result.seconds / duration)
        if let reference {
            line += String(format: "  CER %.1f%%", characterErrorRate(hypothesis: result.text, reference: reference) * 100)
        }
        print(line + "  → \(out.lastPathComponent)")
    } catch {
        print("error: \(error.localizedDescription)")
    }
}
