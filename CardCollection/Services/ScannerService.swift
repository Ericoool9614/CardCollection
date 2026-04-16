import Foundation
import AVFoundation
import SwiftUI
    
enum ScannerError: LocalizedError, Sendable {
    case cameraNotAvailable
    case permissionDenied
    case scanningFailed

    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera permission was denied"
        case .scanningFailed:
            return "Failed to scan QR code"
        }
    }
}

@MainActor
class ScannerService: NSObject, ObservableObject {
    @Published var scannedCertNumber: String?
    @Published var isScanning = false
    @Published var error: ScannerError?

    var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    func checkCameraPermission() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return false
        case .denied, .restricted:
            error = .permissionDenied
            return false
        @unknown default:
            return false
        }
    }

    func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startScanning() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            error = .cameraNotAvailable
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            error = .cameraNotAvailable
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            error = .cameraNotAvailable
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            error = .scanningFailed
            return
        }

        self.captureSession = session
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
        isScanning = false
    }

    func extractCertNumber(from qrString: String) -> String? {
        if qrString.contains("psacard.com/cert/") {
            let components = qrString.components(separatedBy: "/").filter { !$0.isEmpty }
            if let certIndex = components.firstIndex(of: "cert"), certIndex + 1 < components.count {
                let certNumber = components[certIndex + 1]
                if !certNumber.isEmpty && certNumber.allSatisfy({ $0.isNumber }) {
                    return certNumber
                }
            }
        }
        if qrString.allSatisfy({ $0.isNumber }) && qrString.count >= 6 {
            return qrString
        }
        return nil
    }
}

extension ScannerService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let stringValue = metadataObjects.first.flatMap {
            ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue
        }
        guard let stringValue else { return }
        Task { @MainActor in
            stopScanning()
            if let certNumber = extractCertNumber(from: stringValue) {
                scannedCertNumber = certNumber
            } else {
                scannedCertNumber = stringValue
            }
        }
    }
}
