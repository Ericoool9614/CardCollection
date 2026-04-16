import SwiftUI
import AVFoundation

struct ScanPSACardView: View {
    @StateObject private var scannerService = ScannerService()
    @Environment(\.dismiss) private var dismiss
    @State private var scannedCertToAdd: CertNumberWrapper?
    @State private var cameraPermissionGranted = false

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraPermissionGranted {
                    scannerBody
                } else {
                    permissionView
                }
            }
            .navigationTitle("Scan PSA Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                checkPermission()
            }
            .sheet(item: $scannedCertToAdd) { certNumber in
                NavigationStack {
                    AddPSACardView(certNumber: certNumber.id, autoFetch: true)
                }
            }
        }
    }

    private var scannerBody: some View {
        VStack {
            ZStack {
                ScannerPreviewView(session: scannerService.captureSession)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if scannerService.isScanning {
                    VStack {
                        Spacer()
                        Text("Scanning for QR code...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .padding()

            if let certNumber = scannerService.scannedCertNumber {
                scannedResult(certNumber: certNumber)
            }

            if let error = scannerService.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }

    private func scannedResult(certNumber: String) -> some View {
        VStack(spacing: 12) {
            Label("QR Code Detected!", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Cert Number: \(certNumber)")
                .font(.subheadline)

            HStack(spacing: 16) {
                Button("Add This Card") {
                    scannedCertToAdd = CertNumberWrapper(id: certNumber)
                }
                .buttonStyle(.borderedProminent)

                Button("Scan Again") {
                    scannerService.scannedCertNumber = nil
                    scannerService.startScanning()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)
            Text("Please grant camera access to scan QR codes on PSA cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Grant Permission") {
                Task {
                    cameraPermissionGranted = await scannerService.requestCameraPermission()
                    if cameraPermissionGranted {
                        scannerService.startScanning()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func checkPermission() {
        if scannerService.checkCameraPermission() {
            cameraPermissionGranted = true
            scannerService.startScanning()
        }
    }
}

struct CertNumberWrapper: Identifiable {
    let id: String
}

struct ScannerPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let session = session else { return }

        DispatchQueue.main.async {
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.session = session
                previewLayer.frame = uiView.bounds
            } else {
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = uiView.bounds
                uiView.layer.addSublayer(previewLayer)
            }
        }
    }
}
