import AVFoundation
import Foundation
import SwiftUI

/// Plays a generated tone, so no external audio assets or network are required.
/// The iOS audio background mode lets an active player keep sounding while
/// switching apps or locking the screen; force-quit remains outside our control.
@MainActor
final class AlarmAudio: ObservableObject {
    static let shared = AlarmAudio()
    @Published private(set) var isSounding = false
    @Published private(set) var errorMessage: String?
    private var player: AVAudioPlayer?

    func start(sound: AlarmSound, volume: Int) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            let data = Self.makeTone(sound: sound)
            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            player.numberOfLoops = -1
            player.volume = Float(max(0.05, Double(volume) / 100.0))
            player.prepareToPlay()
            guard player.play() else { throw AudioFailure.playbackFailed }
            self.player = player
            isSounding = true
            errorMessage = nil
        } catch {
            errorMessage = "Alarm sound could not start: \(error.localizedDescription)"
            isSounding = false
        }
    }

    func silence() {
        player?.pause()
        isSounding = false
    }

    func resume() {
        guard let player else { return }
        isSounding = player.play()
    }

    func stop() {
        player?.stop()
        player = nil
        isSounding = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private enum AudioFailure: LocalizedError {
        case playbackFailed
        var errorDescription: String? { "iOS did not start audio playback." }
    }

    private static func makeTone(sound: AlarmSound) -> Data {
        let sampleRate = 22_050
        let seconds = 2
        let samples = sampleRate * seconds
        var pcm = Data(capacity: samples * 2)
        for i in 0..<samples {
            let t = Double(i) / Double(sampleRate)
            let frequency: Double
            let envelope: Double
            switch sound {
            case .digital:
                frequency = 880
                envelope = (t.truncatingRemainder(dividingBy: 0.44) < 0.3) ? 1 : 0
            case .classic:
                frequency = (t.truncatingRemainder(dividingBy: 0.5) < 0.25) ? 720 : 920
                envelope = 1
            case .intense:
                frequency = (t.truncatingRemainder(dividingBy: 0.23) < 0.115) ? 1050 : 790
                envelope = 1
            }
            let wave = sin(2 * Double.pi * frequency * t)
            var value = Int16((wave * envelope * 13_000).rounded()).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }

        var data = Data()
        func ascii(_ string: String) { data.append(contentsOf: string.utf8) }
        func u16(_ number: UInt16) {
            var little = number.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func u32(_ number: UInt32) {
            var little = number.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        ascii("RIFF"); u32(UInt32(36 + pcm.count)); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1); u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        ascii("data"); u32(UInt32(pcm.count)); data.append(pcm)
        return data
    }
}
