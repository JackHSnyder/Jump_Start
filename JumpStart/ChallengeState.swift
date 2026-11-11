import Foundation

/// Only the exercise state is persisted; no camera imagery is ever stored.
struct PendingChallenge: Codable {
    var goal: Int
    var completed: Int
    var startedAt: Date
}

enum ChallengePersistence {
    private static let key = "pendingJumpStartChallenge"

    static var pending: PendingChallenge? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PendingChallenge.self, from: data)
    }

    static func begin(goal: Int) -> PendingChallenge {
        let existing = pending
        let value = existing ?? PendingChallenge(goal: goal, completed: 0, startedAt: .now)
        save(value)
        return value
    }

    static func save(_ state: PendingChallenge) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
