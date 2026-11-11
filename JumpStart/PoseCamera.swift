import AVFoundation
import Vision
import SwiftUI

/// A deliberately conservative two-phase counter: arms above shoulders and feet
/// apart, followed by arms down and feet together, counts as one repetition.
struct JumpingJackCounter {
    enum Phase { case closed, open }
    private(set) var phase: Phase = .closed
    private(set) var count = 0
    private var lastTransition = Date.distantPast

    mutating func update(_ observation: VNHumanBodyPoseObservation, at now: Date) -> Bool {
        func joint(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let point = try? observation.recognizedPoint(name), point.confidence > 0.38 else { return nil }
            return point.location
        }
        guard let lw = joint(.leftWrist), let rw = joint(.rightWrist),
              let ls = joint(.leftShoulder), let rs = joint(.rightShoulder),
              let la = joint(.leftAnkle), let ra = joint(.rightAnkle),
              let lh = joint(.leftHip), let rh = joint(.rightHip) else { return false }
        let shoulderWidth = max(0.07, abs(ls.x - rs.x))
        let hipWidth = max(0.06, abs(lh.x - rh.x))
        let anklesApart = abs(la.x - ra.x)
        let wristsHigh = lw.y > ls.y + 0.08 && rw.y > rs.y + 0.08
        let wristsLow = lw.y < ls.y - 0.07 && rw.y < rs.y - 0.07
        let spread = anklesApart > max(hipWidth * 1.65, shoulderWidth * 1.55)
        let together = anklesApart < max(hipWidth * 1.45, shoulderWidth * 1.2)
        guard now.timeIntervalSince(lastTransition) > 0.35 else { return true }

        if phase == .closed && wristsHigh && spread {
            phase = .open
            lastTransition = now
        } else if phase == .open && wristsLow && together {
            phase = .closed
            count += 1
            lastTransition = now
        }
        return true
    }

    mutating func reset() { self = JumpingJackCounter() }
    mutating func restore(_ completed: Int) {
        self = JumpingJackCounter()
        count = max(0, completed)
    }
}

@MainActor
final class PoseCamera: NSObject, ObservableObject {
    @Published private(set) var count = 0
    @Published private(set) var tracking = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var cameraError: String?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "JumpStart.camera", qos: .userInitiated)
    private var counter = JumpingJackCounter()
    private var lastSeen = Date.distantPast
    private var lastFrame = Date.distantPast
    private let request = VNDetectHumanBodyPoseRequest()

    func start() async {
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        let granted: Bool
        if authorization == .authorized {
            granted = true
        } else if authorization == .notDetermined {
            granted = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            granted = false
        }
        guard granted else { permissionDenied = true; return }
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                self.session.sessionPreset = .medium
                defer { self.session.commitConfiguration() }
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    Task { @MainActor in self.cameraError = "Front camera unavailable." }
                    return
                }
                self.session.addInput(input)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.queue)
                if self.session.canAddOutput(output) { self.session.addOutput(output) }
            }
            self.session.startRunning()
        }
    }

    func stop() { queue.async { [weak self] in self?.session.stopRunning() } }
    func reset() { counter.reset(); count = 0; tracking = false }
    func restore(_ completed: Int) {
        counter.restore(completed)
        count = max(0, completed)
        tracking = false
    }

    private func publish(_ observation: VNHumanBodyPoseObservation?) {
        let now = Date()
        if let observation, counter.update(observation, at: now) {
            lastSeen = now
            count = counter.count
            tracking = true
        } else if now.timeIntervalSince(lastSeen) > 1.2 {
            tracking = false
        }
    }
}

extension PoseCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // The front camera is portrait-oriented; orientation is adjusted for Vision.
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored)
        do {
            try handler.perform([request])
            let result = request.results?.first
            Task { @MainActor [weak self] in self?.publish(result) }
        } catch {
            Task { @MainActor [weak self] in self?.tracking = false }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
