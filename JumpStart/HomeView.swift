import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AlarmStore
    @State private var showingChallenge = false
    @State private var showInformation = false

    private let mint = Color(red: 0.57, green: 0.94, blue: 0.66)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("JUMPSTART").font(.caption.weight(.black)).tracking(3).foregroundStyle(mint)
                            Text("Your wake-up ritual").font(.title2.weight(.semibold))
                        }
                        Spacer()
                        Image(systemName: "figure.jumprope")
                            .font(.title2).foregroundStyle(mint)
                            .frame(width: 54, height: 54)
                            .background(mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("YOUR ALARM", systemImage: "alarm").font(.caption.bold()).tracking(1.5)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("Enabled", isOn: Binding(
                                get: { store.settings.enabled },
                                set: { value in Task { await store.updateEnabled(value) } }
                            )).labelsHidden().tint(mint).disabled(store.isBusy)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(String(format: "%02d:%02d", store.settings.hour, store.settings.minute))
                                .font(.system(size: 61, weight: .bold, design: .rounded)).monospacedDigit()
                            Spacer()
                            Text(store.settings.enabled ? "Every day" : "Not scheduled")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        DatePicker("Wake-up time", selection: Binding(
                            get: {
                                Calendar.current.date(from: DateComponents(hour: store.settings.hour, minute: store.settings.minute)) ?? .now
                            },
                            set: { date in
                                store.settings.hour = Calendar.current.component(.hour, from: date)
                                store.settings.minute = Calendar.current.component(.minute, from: date)
                                Task { await store.saveAndReschedule() }
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact).tint(mint)
                    }
                    .padding(22).background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 25))

                    VStack(alignment: .leading, spacing: 19) {
                        Text("CHALLENGE SETTINGS").font(.caption.bold()).tracking(1.5).foregroundStyle(.secondary)
                        HStack {
                            Label("Jumping jacks", systemImage: "figure.highintensity.intervaltraining")
                            Spacer()
                            Text("\(store.settings.repetitions)").font(.headline).foregroundStyle(mint)
                        }
                        Slider(value: Binding(
                            get: { Double(store.settings.repetitions) },
                            set: { store.settings.repetitions = Int($0.rounded()) }
                        ), in: 5...50, step: 5).tint(mint)
                        Divider().overlay(.white.opacity(0.08))
                        HStack {
                            Label("Practice sound volume", systemImage: "speaker.wave.2")
                            Spacer()
                            Text("\(store.settings.volume)%").font(.headline).foregroundStyle(mint)
                        }
                        Slider(value: Binding(
                            get: { Double(store.settings.volume) },
                            set: { store.settings.volume = Int($0.rounded()) }
                        ), in: 0...100, step: 5).tint(mint)
                        Text("AlarmKit's system alarm volume is managed by iOS. This setting applies only to future in-app sounds.")
                            .font(.caption).foregroundStyle(.secondary)
                        Divider().overlay(.white.opacity(0.08))
                        Picker("Preferred sound", selection: $store.settings.sound) {
                            ForEach(AlarmSound.allCases) { sound in
                                Text(sound.rawValue).tag(sound)
                            }
                        }
                        Text("System alarms currently use the iOS default sound; sound options are reserved for a later custom-audio build.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(22).background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 25))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Camera challenge", systemImage: "camera.viewfinder")
                            .font(.headline).foregroundStyle(mint)
                        Text("Prop up your phone, step into frame, and complete \(store.settings.repetitions) jumping jacks. Counting happens entirely on your iPhone.")
                            .foregroundStyle(.secondary)
                        Button { showingChallenge = true } label: {
                            HStack { Spacer(); Image(systemName: "play.fill"); Text("Try the challenge"); Spacer() }
                                .font(.headline).padding(15)
                        }
                        .buttonStyle(.plain).foregroundStyle(.black).background(mint, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(22).background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 25))

                    Button("Important alarm limitations") { showInformation = true }
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(Color(red: 0.06, green: 0.085, blue: 0.10))
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingChallenge) { ChallengeView(target: store.settings.repetitions) }
            .alert("Unable to schedule alarm", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
            .alert("About JumpStart", isPresented: $showInformation) {
                Button("Understood", role: .cancel) {}
            } message: {
                Text("iOS provides a system Stop button, which cannot be removed. Opening the camera challenge does not automatically silence an active system alarm. Never rely on a sideloaded app as your only wake-up alarm; free signing expires after 7 days.")
            }
            .task {
                if UserDefaults.standard.bool(forKey: "openChallenge") {
                    UserDefaults.standard.set(false, forKey: "openChallenge")
                    showingChallenge = true
                }
            }
        }
    }
}
