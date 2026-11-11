import SwiftUI

struct ChallengeView: View {
    let target: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = PoseCamera()
    @ObservedObject private var audio = AlarmAudio.shared
    @EnvironmentObject private var store: AlarmStore
    @State private var showEmergency = false
    @State private var emergencyText = ""
    @State private var completed = false
    @State private var detectedSince: Date?
    @State private var audioStarted = false

    private let mint = Color(red: 0.57, green: 0.94, blue: 0.66)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.77), .clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("JUMPSTART").font(.caption.bold()).tracking(3).foregroundStyle(mint)
                        Text("Let's get moving").font(.title2.bold())
                    }
                    Spacer()
                    Button { showEmergency = true } label: {
                        Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white.opacity(0.8))
                    }.accessibilityLabel("Emergency dismissal")
                }

                Spacer()
                VStack(spacing: 12) {
                    Text("\(min(camera.count, target)) / \(target)")
                        .font(.system(size: 70, weight: .black, design: .rounded)).monospacedDigit()
                    Text("JUMPING JACKS").font(.caption.bold()).tracking(3).foregroundStyle(.white.opacity(0.85))
                    ProgressView(value: Double(min(camera.count, target)), total: Double(target))
                        .tint(mint).scaleEffect(y: 2)
                    HStack(spacing: 8) {
                        Circle().fill(camera.tracking ? mint : .orange).frame(width: 9, height: 9)
                        Text(camera.tracking ? "Body detected — keep going!" : "Step back so your whole body is visible")
                            .font(.subheadline)
                    }
                    .foregroundStyle(camera.tracking ? mint : .white)
                    if let error = audio.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    } else {
                        Label(audio.isSounding ? "Alarm sounding" : "Alarm temporarily silenced", systemImage: audio.isSounding ? "speaker.wave.3.fill" : "speaker.slash.fill")
                            .font(.caption.bold())
                            .foregroundStyle(audio.isSounding ? .orange : mint)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 24))
            }
            .padding(22)
        }
        .task {
            let pending = ChallengePersistence.begin(goal: target)
            camera.restore(pending.completed)
            // An active audio player is kept by the singleton if this view is re-created.
            if !audio.isSounding { audio.start(sound: store.settings.sound, volume: store.settings.volume) }
            audioStarted = true
            await camera.start()
        }
        .task {
            // Debounce recognition for one second, and never stay silent if the app
            // leaves the foreground (camera tracking cannot continue reliably there).
            while !Task.isCancelled {
                if audioStarted && !completed {
                    if scenePhase != .active || !camera.tracking {
                        detectedSince = nil
                        if !audio.isSounding { audio.resume() }
                    } else if detectedSince == nil {
                        detectedSince = .now
                    } else if let since = detectedSince,
                              Date().timeIntervalSince(since) >= 1.0, audio.isSounding {
                        audio.silence()
                    }
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { detectedSince = nil; audio.resume() }
        }
        .onDisappear { camera.stop() }
        .onChange(of: camera.count) { _, value in
            ChallengePersistence.save(.init(goal: target, completed: value, startedAt: ChallengePersistence.pending?.startedAt ?? .now))
            if value >= target {
                completed = true
                audio.stop()
                camera.stop()
                ChallengePersistence.clear()
            }
        }
        .alert("Camera unavailable", isPresented: .constant(camera.permissionDenied || camera.cameraError != nil)) {
            Button("Close") { showEmergency = true }
        } message: { Text(camera.cameraError ?? "Grant camera access in Settings to count jumping jacks.") }
        .alert("Challenge complete!", isPresented: $completed) {
            Button("Done") { dismiss() }
        } message: {
            Text("You completed \(target) jumping jacks. Your in-app alarm has stopped. If the system AlarmKit alert remains, use its control to dismiss it.")
        }
        .sheet(isPresented: $showEmergency) {
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "cross.case.fill").font(.system(size: 48)).foregroundStyle(.orange)
                    Text("Emergency exit").font(.title.bold())
                    Text("If you're injured, unwell, or the camera can't recognize you, you can always exit. Type DISMISS to confirm. This challenge cannot override iOS system alarm controls.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    TextField("Type DISMISS", text: $emergencyText).textInputAutocapitalization(.characters)
                        .autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    Button("Exit challenge") {
                        ChallengePersistence.clear()
                        audio.stop()
                        camera.stop()
                        showEmergency = false
                        dismiss()
                    }
                        .buttonStyle(.borderedProminent).tint(.orange)
                        .disabled(emergencyText.uppercased() != "DISMISS")
                    Spacer()
                }
                .padding(28)
                .navigationTitle("Safety exit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Cancel") { showEmergency = false } }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
