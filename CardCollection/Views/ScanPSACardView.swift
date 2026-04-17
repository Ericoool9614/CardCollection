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
            .navigationTitle("扫码添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
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
                        Text("正在扫描二维码...")
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
                    .stroke(Color.orange, lineWidth: 2)
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
            Label("检测到二维码！", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("认证编号：\(certNumber)")
                .font(.subheadline)

            HStack(spacing: 16) {
                Button("添加此卡") {
                    scannedCertToAdd = CertNumberWrapper(id: certNumber)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("重新扫描") {
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
            Text("需要相机权限")
                .font(.title2)
                .fontWeight(.bold)
            Text("请授予相机访问权限以扫描PSA卡上的二维码。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("授予权限") {
                Task {
                    cameraPermissionGranted = await scannerService.requestCameraPermission()
                    if cameraPermissionGranted {
                        scannerService.startScanning()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
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
