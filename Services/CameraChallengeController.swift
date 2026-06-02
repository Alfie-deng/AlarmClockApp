import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class CameraChallengeController: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case ready
        case captured
        case unavailable(String)
        
        var message: String {
            switch self {
            case .idle: return "准备拍照"
            case .requestingPermission: return "正在请求相机权限"
            case .ready: return "相机已就绪"
            case .captured: return "已拍摄，确认后关闭闹钟"
            case .unavailable(let reason): return reason
            }
        }
    }
    
    @Published private(set) var state: State = .idle
    @Published var capturedImage: UIImage?
    @Published var isShowingCamera = false
    
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
    
    func accept(image: UIImage) {
        capturedImage = image
        state = .captured
        isShowingCamera = false
    }
    
    func retake() {
        capturedImage = nil
        requestCameraAccessThenOpen()
    }
    
    func mockCapture() {
        capturedImage = Self.makeMockImage()
        state = .captured
    }
    
    private func openCamera() {
        state = .ready
        isShowingCamera = true
    }
    
    private func denyCamera() {
        state = .unavailable("需要开启相机权限才能完成拍照挑战")
        isShowingCamera = false
    }
    
    private static func makeMockImage() -> UIImage {
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
            let text = "床头灯\n模拟照片"
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
