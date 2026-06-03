import AVFoundation
import SwiftUI
import UIKit
import Vision

@MainActor
final class CameraChallengeController: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case ready
        case analyzing
        case captured
        case matched
        case rejected
        case unavailable(String)

        var message: String {
            switch self {
            case .idle: return "准备拍照"
            case .requestingPermission: return "正在请求相机权限"
            case .ready: return "相机已就绪"
            case .analyzing: return "正在识别照片内容"
            case .captured: return "已拍摄，等待识别结果"
            case .matched: return "识别通过，可以关闭闹钟"
            case .rejected: return "没识别到目标，请重拍"
            case .unavailable(let reason): return reason
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published var capturedImage: UIImage?
    @Published var isShowingCamera = false
    @Published private(set) var recognitionSummary = "等待拍照"
    @Published private(set) var recognitionConfidence: Float = 0
    @Published private(set) var recognizedLabels: [String] = []

    var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var canMockCapture: Bool {
        if ProcessInfo.processInfo.arguments.contains("--debugPhotoMock") { return true }
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func requestCameraAccessThenOpen() {
        guard canUseCamera else {
            state = .unavailable("当前设备没有可用相机，可使用模拟拍照验证")
            return
        }
        state = .requestingPermission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            openCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    granted ? self?.openCamera() : self?.denyCamera()
                }
            }
        case .denied, .restricted:
            denyCamera()
        @unknown default:
            denyCamera()
        }
    }

    var didMatchTarget: Bool {
        state == .matched
    }

    func accept(image: UIImage, targetLabel: String) {
        capturedImage = image
        isShowingCamera = false
        analyze(image: image, targetLabel: targetLabel)
    }

    func retake() {
        capturedImage = nil
        recognitionSummary = "等待拍照"
        recognitionConfidence = 0
        recognizedLabels = []
        requestCameraAccessThenOpen()
    }

    func mockCapture(targetLabel: String) {
        capturedImage = Self.makeMockImage(targetLabel: targetLabel)
        recognitionSummary = "模拟照片命中「\(targetLabel)」"
        recognitionConfidence = 1
        recognizedLabels = [targetLabel]
        state = .matched
    }

    private func openCamera() {
        state = .ready
        isShowingCamera = true
    }

    private func denyCamera() {
        state = .unavailable("需要开启相机权限才能完成拍照挑战")
        isShowingCamera = false
    }

    private func analyze(image: UIImage, targetLabel: String) {
        state = .analyzing
        recognitionSummary = "正在寻找「\(targetLabel)」"
        recognitionConfidence = 0
        recognizedLabels = []

        guard let cgImage = image.cgImage else {
            state = .rejected
            recognitionSummary = "照片格式无法识别，请重拍"
            return
        }

        let normalizedTarget = Alarm.normalizedPhotoTarget(targetLabel)
        let aliases = Self.aliases(for: normalizedTarget)
        Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let observations = request.results ?? []
                let labels = observations.map(\.identifier)
                let bestMatch = observations
                    .filter { observation in
                        let identifier = observation.identifier.lowercased()
                        return aliases.contains { identifier.contains($0) }
                    }
                    .max { $0.confidence < $1.confidence }
                await MainActor.run {
                    self.recognizedLabels = labels
                    if let bestMatch, bestMatch.confidence >= 0.08 {
                        self.recognitionConfidence = bestMatch.confidence
                        self.recognitionSummary = "识别到 \(bestMatch.identifier)，匹配「\(normalizedTarget)」"
                        self.state = .matched
                    } else {
                        self.recognitionConfidence = observations.first?.confidence ?? 0
                        let top = observations.first?.identifier ?? "未知内容"
                        self.recognitionSummary = "最高识别为 \(top)，没有命中「\(normalizedTarget)」"
                        self.state = .rejected
                    }
                }
            } catch {
                await MainActor.run {
                    self.recognitionSummary = "识别失败：\(error.localizedDescription)"
                    self.state = .rejected
                }
            }
        }
    }

    private static func aliases(for targetLabel: String) -> [String] {
        switch Alarm.normalizedPhotoTarget(targetLabel) {
        case "床头灯":
            return ["lamp", "lampshade", "light", "desk lamp", "table lamp", "nightstand"]
        case "洗手台":
            return ["sink", "basin", "bathroom", "washbasin", "faucet"]
        case "书桌":
            return ["desk", "table", "office", "computer", "keyboard"]
        case "牙刷":
            return ["toothbrush", "tooth paste", "toothpaste"]
        case "门":
            return ["door", "doorknob", "handle", "doorway"]
        default:
            return ["lamp"]
        }
    }

    private static func makeMockImage(targetLabel: String) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1).cgColor,
                          UIColor(red: 0.82, green: 0.52, blue: 0.25, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
            UIColor(white: 1, alpha: 0.16).setFill()
            UIBezierPath(roundedRect: CGRect(x: 210, y: 280, width: 480, height: 620), cornerRadius: 60).fill()
            UIColor(red: 1, green: 0.72, blue: 0.38, alpha: 0.9).setFill()
            UIBezierPath(ovalIn: CGRect(x: 340, y: 390, width: 220, height: 220)).fill()
            UIColor(white: 1, alpha: 0.9).setFill()
            let text = "\(targetLabel)\n模拟照片"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            text.draw(in: CGRect(x: 0, y: 720, width: size.width, height: 220), withAttributes: attrs)
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
