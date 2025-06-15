//
//  FaceDetectionView.swift
//  Facy
//
//  Created by Pramuditha Muhammad Ikhwan on 14/06/25.
//
import SwiftUI
import Vision
import AVFoundation

// MARK: - Face Detection View
struct FaceDetectionView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Overlay with circular cutout
            OverlayView()
            
            // Circle Frame (diletakkan secara absolut di tengah layar)
            Circle()
                .stroke(cameraManager.frameColor, lineWidth: 3)
                .frame(width: 340, height: 340)
            
            // UI Elements
            VStack {
                Spacer()
                
                // Warning Label
                Text(cameraManager.warningMessage)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                
                
                // Capture Button
                Button(action: {
                    cameraManager.capturePhoto()
                }) {
                    Text("Continue to drawing step")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(cameraManager.canCapture ? Color.green : Color.blue)
                        .cornerRadius(25)
                        .opacity(cameraManager.canCapture ? 1.0 : 0.5)
                }
                .disabled(!cameraManager.canCapture)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            cameraManager.requestPermission()
        }
        .alert("Photo Captured", isPresented: $cameraManager.showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Face captured successfully with good lighting")
        }
        .alert("Error", isPresented: $cameraManager.showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(cameraManager.errorMessage)
        }
    }
}

// MARK: - Overlay View with Circular Cutout
struct OverlayView: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.6))
            .mask(
                Rectangle()
                    .overlay(
                        Circle()
                            .frame(width: 340, height: 340)
                            .blendMode(.destinationOut)
                    )
            )
            .ignoresSafeArea()
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        cameraManager.setupCamera(in: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}


#Preview {
    FaceDetectionView()
}
