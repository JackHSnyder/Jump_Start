import Foundation
import SwiftUI
import AlarmKit
import AppIntents

struct AlarmSettings: Codable {
    var hour = 7
    var minute = 0
    var repetitions = 20
    var volume = 80
    var sound = AlarmSound.digital
    var enabled = false
    var id = UUID()
}

enum AlarmSound: String, Codable, CaseIterable, Identifiable {
    case digital = "Digital"
    case classic = "Classic"
    case intense = "Intense"
    var id: String { rawValue }
}

struct JumpStartMetadata: AlarmMetadata {}

struct OpenChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open JumpStart"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openChallenge")
        return .result()
    }
}

@MainActor
final class AlarmStore: ObservableObject {
    @Published var settings: AlarmSettings {
        didSet { persist() }
    }
    @Published var errorMessage: String?
    @Published var isBusy = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "alarmSettings"),
           let value = try? JSONDecoder().decode(AlarmSettings.self, from: data) {
            settings = value
        } else {
            settings = AlarmSettings()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "alarmSettings")
    }

    func updateEnabled(_ enabled: Bool) async {
        isBusy = true
        defer { isBusy = false }
        do {
            if enabled {
                let state: AlarmManager.AuthorizationState
                do {
                    state = try await AlarmManager.shared.requestAuthorization()
                } catch {
                    throw AlarmSetupError.authorizationFailed(error.localizedDescription)
                }
                guard state == .authorized else {
                    throw AlarmError.notAuthorized
                }
                // Cancel the previous alarm when updating the scheduled time.
                try? AlarmManager.shared.cancel(id: settings.id)

                let alert = AlarmPresentation.Alert(
                    title: "Time to move!",
                    secondaryButton: AlarmButton(
                        text: "Open",
                        textColor: .white,
                        systemImageName: "arrow.right.circle.fill"
                    ),
                    secondaryButtonBehavior: .custom
                )
                let attributes = AlarmAttributes<JumpStartMetadata>(
                    presentation: AlarmPresentation(alert: alert),
                    metadata: JumpStartMetadata(),
                    tintColor: Color(red: 0.57, green: 0.94, blue: 0.66)
                )
                let time = Alarm.Schedule.Relative.Time(hour: settings.hour, minute: settings.minute)
                let schedule = Alarm.Schedule.relative(.init(
                    time: time,
                    repeats: .weekly([.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
                ))
                let configuration = AlarmManager.AlarmConfiguration<JumpStartMetadata>.alarm(
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: nil,
                    secondaryIntent: OpenChallengeIntent(),
                    sound: .default
                )
                do {
                    _ = try await AlarmManager.shared.schedule(id: settings.id, configuration: configuration)
                } catch {
                    throw AlarmSetupError.schedulingFailed(error.localizedDescription)
                }
            } else {
                try AlarmManager.shared.cancel(id: settings.id)
            }
            settings.enabled = enabled
            errorMessage = nil
        } catch {
            settings.enabled = false
            errorMessage = error.localizedDescription
        }
    }

    func saveAndReschedule() async {
        if settings.enabled { await updateEnabled(true) }
    }
}

enum AlarmError: LocalizedError {
    case notAuthorized
    var errorDescription: String? { "Allow alarms in iOS Settings to schedule a wake-up alarm." }
}

enum AlarmSetupError: LocalizedError {
    case authorizationFailed(String)
    case schedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let detail):
            return "Alarm permission request failed: \(detail)"
        case .schedulingFailed(let detail):
            return "Alarm scheduling failed after authorization: \(detail)"
        }
    }
}
