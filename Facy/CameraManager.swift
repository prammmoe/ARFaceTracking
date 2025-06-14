//
//  CameraManager.swift
//  Facy
//
//  Created by Pramuditha Muhammad Ikhwan on 14/06/25.
//

import SwiftUI
import AVFoundation
import Vision

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var warningMessage = "Posisikan wajah Anda di dalam frame"
    @Published var frameColor = Color.white
    @Published var canCapture = false
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    private var captureSession: AVCaptureSession!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated)
    
    private var currentFaceObservation: VNFaceObservation?
    private var isLightingSufficient = false
    private var isFaceInFrame = false
    private let lightingThreshold: Float = 0.3
    private let circleFrameSize: CGFloat = 280
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    // MARK: - Camera Setup
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startCamera()
                } else {
                    self?.showError("Akses kamera diperlukan untuk menggunakan fitur ini")
                }
            }
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            showError("Front camera tidak tersedia")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            }
            
        } catch {
            showError("Gagal setup camera: \(error.localizedDescription)")
        }
    }
    
    func setupCamera(in view: UIView) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Update frame when view bounds change
        DispatchQueue.main.async {
            self.previewLayer.frame = view.bounds
        }
    }
    
    private func startCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    // MARK: - Face Detection
    private func detectFaces(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleFaceDetectionResults(request.results)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    private func handleFaceDetectionResults(_ results: [VNObservation]?) {
        guard let faceObservations = results as? [VNFaceObservation] else {
            currentFaceObservation = nil
            updateUI(faceDetected: false, inFrame: false)
            return
        }
        
        if let firstFace = faceObservations.first {
            currentFaceObservation = firstFace
            let inFrame = isFaceInCircularFrame(firstFace)
            updateUI(faceDetected: true, inFrame: inFrame)
        } else {
            currentFaceObservation = nil
            updateUI(faceDetected: false, inFrame: false)
        }
    }
    
    private func isFaceInCircularFrame(_ faceObservation: VNFaceObservation) -> Bool {
        guard let previewLayer = previewLayer else { return false }
        
        // Convert Vision coordinates to UIView coordinates
        let faceRect = previewLayer.layerRectConverted(fromMetadataOutputRect: faceObservation.boundingBox)
        
        // Get screen bounds
        let screenBounds = UIScreen.main.bounds
        
        // Circle frame center and radius (accounting for the offset in UI)
        let circleCenter = CGPoint(x: screenBounds.midX, y: screenBounds.midY - 50)
        let circleRadius = circleFrameSize / 2
        
        // Face center
        let faceCenter = CGPoint(x: faceRect.midX, y: faceRect.midY)
        
        // Calculate distance from face center to circle center
        let distance = sqrt(pow(faceCenter.x - circleCenter.x, 2) + pow(faceCenter.y - circleCenter.y, 2))
        
        // Check if face is within circle and appropriate size
        let faceDiameter = max(faceRect.width, faceRect.height)
        let isInCircle = distance < circleRadius * 0.8
        let isAppropriateSize = faceDiameter > circleRadius * 0.3 && faceDiameter < circleRadius * 1.2
        
        return isInCircle && isAppropriateSize
    }
    
    // MARK: - Lighting Detection
    private func checkLighting(in pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var totalBrightness: Float = 0
        let sampleCount = min(1000, width * height / 4)
        
        for i in stride(from: 0, to: sampleCount * 4, by: 4) {
            let pixelIndex = (i / 4) * bytesPerRow + (i % 4)
            if pixelIndex < width * height * 4 {
                let b = Float(buffer[pixelIndex])
                let g = Float(buffer[pixelIndex + 1])
                let r = Float(buffer[pixelIndex + 2])
                
                // Calculate luminance
                let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                totalBrightness += luminance
            }
        }
        
        let averageBrightness = totalBrightness / Float(sampleCount)
        
        DispatchQueue.main.async { [weak self] in
            self?.isLightingSufficient = averageBrightness > self?.lightingThreshold ?? 0.9
            self?.updateCaptureButton()
        }
    }
    
    // MARK: - UI Updates
    private func updateUI(faceDetected: Bool, inFrame: Bool) {
        isFaceInFrame = inFrame
        
        if !faceDetected {
            warningMessage = "Wajah tidak terdeteksi"
            frameColor = .red
        } else if !isLightingSufficient {
            warningMessage = "Pencahayaan kurang. Pindah ke tempat yang lebih terang"
            frameColor = .yellow
        } else if !inFrame {
            warningMessage = "Posisikan wajah Anda di dalam frame"
            frameColor = .yellow
        } else {
            warningMessage = "Sempurna! Siap untuk mengambil foto"
            frameColor = .green
        }
        
        updateCaptureButton()
    }
    
    private func updateCaptureButton() {
        canCapture = isFaceInFrame && isLightingSufficient
    }
    
    // MARK: - Actions
    func capturePhoto() {
        guard canCapture else { return }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        showSuccessAlert = true
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Check lighting
        checkLighting(in: pixelBuffer)
        
        // Detect faces
        detectFaces(in: pixelBuffer)
    }
}
