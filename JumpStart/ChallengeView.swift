import SwiftUI

struct ChallengeView: View {
    let target: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = PoseCamera()
    @State private var started = Date()
    @State private var showEmergency = false
    @State private var emergencyText = ""
    @State private var completed = false

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
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 24))
            }
            .padding(22)
        }
        .task { started = .now; await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.count) { _, value in
            if value >= target { completed = true; camera.stop() }
        }
        .alert("Camera unavailable", isPresented: .constant(camera.permissionDenied || camera.cameraError != nil)) {
            Button("Close") { dismiss() }
        } message: { Text(camera.cameraError ?? "Grant camera access in Settings to count jumping jacks.") }
        .alert("Challenge complete!", isPresented: $completed) {
            Button("Done") { dismiss() }
        } message: {
            Text("You completed \(target) jumping jacks! If a system alarm is still ringing, use the iOS alarm control to stop it.")
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
                    Button("Exit challenge") { showEmergency = false; dismiss() }
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
