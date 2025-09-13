 //
//  ContentView.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/11/25.
//

import SwiftUI
import CoreData
import MapKit
import CoreLocation
import AVFoundation
import Photos
import UIKit

// Haptic feedback helper
func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    let enableHapticFeedback = UserDefaults.standard.bool(forKey: "enableHapticFeedback")
    guard enableHapticFeedback else { return }
    
    let impactFeedback = UIImpactFeedbackGenerator(style: style)
    impactFeedback.impactOccurred()
}

// Selection haptic feedback helper
func triggerSelectionHaptic() {
    let enableHapticFeedback = UserDefaults.standard.bool(forKey: "enableHapticFeedback")
    guard enableHapticFeedback else { return }
    
    let selectionFeedback = UISelectionFeedbackGenerator()
    selectionFeedback.selectionChanged()
}

struct ContentView: View {
    // Shared metering state
    @State private var meteringPoint: CGPoint?
    @State private var isMeteringLocked: Bool = false
    @State private var currentEV: Double = 12.0
    
    // Shared exposure settings
    @State private var currentAperture: Double = 5.6
    @State private var currentShutterSpeed: Double = 1/125
    @State private var currentISO: Double = 100
    
    // Managers for shot logging
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @ObservedObject private var filmStockManager = FilmStockManager.shared
    @ObservedObject private var reciprocityCalculator = ReciprocityCalculator.shared
    
    // Camera reference for photo capture
    @State private var cameraView: CameraPreviewView?
    
    // Show success message
    @State private var showLoggedMessage = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Camera takes up top 2/3 of screen
            CameraView(
                meteringPoint: $meteringPoint,
                isMeteringLocked: $isMeteringLocked,
                currentEV: $currentEV,
                cameraView: $cameraView
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom controls take up bottom 1/3
            BottomControlsView(
                currentEV: $currentEV,
                currentAperture: $currentAperture,
                currentShutterSpeed: $currentShutterSpeed,
                currentISO: $currentISO,
                onLogShot: logShot
            )
            .frame(height: 300)
            .background(Color.black.opacity(0.8))
        }
        .ignoresSafeArea()
        .onAppear {
            locationManager.requestLocationPermission()
            setupFilmStockCallback()
        }
        .overlay(
            // Success message overlay
            Group {
                if showLoggedMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Shot Logged!")
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 280)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        )
    }
    
    // Setup callback for film stock selection
    private func setupFilmStockCallback() {
        filmStockManager.onFilmStockSelected = { filmStock in
            DispatchQueue.main.async {
                self.updateISOForFilmStock(filmStock)
            }
        }
    }
    
    // Update ISO when film stock is selected
    private func updateISOForFilmStock(_ filmStock: FilmStock?) {
        guard let filmStock = filmStock else { return }
        
        // Update the current ISO to match the film stock's ISO
        currentISO = filmStock.iso
        
        // Trigger haptic feedback to indicate the change
        triggerHaptic(.light)
    }
    
    // Function to log a shot
    private func logShot(aperture: Double, shutterSpeed: Double, iso: Double, ev: Double) {
        // Get current location
        locationManager.getCurrentLocation()
        
        // Capture reference photo
        cameraView?.capturePhoto { imageData in
            DispatchQueue.main.async {
                // Calculate effective ISO and exposure settings with film stock
                let exposureSettings = reciprocityCalculator.calculateExposure(
                    meteredEV: ev,
                    filmStock: filmStockManager.selectedFilmStock,
                    baseISO: iso,
                    pushPullStops: filmStockManager.pushPullStops
                )
                
                // Use effective ISO and corrected exposure time
                let effectiveISO = exposureSettings.effectiveISO
                let correctedShutterSpeed = exposureSettings.correctedExposureTime
                
                // Save to Core Data with film stock relationship
                coreDataManager.saveLoggedShotWithFilmStock(
                    aperture: aperture,
                    shutterSpeed: correctedShutterSpeed,
                    iso: effectiveISO,
                    ev: ev,
                    latitude: locationManager.location?.coordinate.latitude,
                    longitude: locationManager.location?.coordinate.longitude,
                    imageData: imageData,
                    locationName: locationManager.locationName,
                    filmStock: filmStockManager.selectedFilmStock
                )
                
                // Show success message
                withAnimation {
                    showLoggedMessage = true
                }
                
                // Hide message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showLoggedMessage = false
                    }
                }
            }
        }
    }
}

struct CameraView: UIViewRepresentable {
    @Binding var meteringPoint: CGPoint?
    @Binding var isMeteringLocked: Bool
    @Binding var currentEV: Double
    @Binding var cameraView: CameraPreviewView?
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.delegate = context.coordinator
        DispatchQueue.main.async {
            self.cameraView = view
        }
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.meteringPoint = meteringPoint
        uiView.isMeteringLocked = isMeteringLocked
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraPreviewDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func didTapAt(point: CGPoint) {
            parent.meteringPoint = point
            parent.isMeteringLocked = false
        }
        
        func didLongPressAt(point: CGPoint) {
            parent.meteringPoint = point
            parent.isMeteringLocked = true
        }
        
        func didUpdateEV(_ ev: Double) {
            parent.currentEV = ev
        }
    }
}

// Protocol for camera communication
protocol CameraPreviewDelegate: AnyObject {
    func didTapAt(point: CGPoint)
    func didLongPressAt(point: CGPoint)
    func didUpdateEV(_ ev: Double)
}

// Custom UIView for camera with tap detection and photo capture
class CameraPreviewView: UIView {
    weak var delegate: CameraPreviewDelegate?
    var meteringPoint: CGPoint?
    var isMeteringLocked: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var meteringCircle: CAShapeLayer?
    
    // Photo capture
    private var photoOutput: AVCapturePhotoOutput?
    private var photoCaptureCompletion: ((Data?) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCamera() {
        backgroundColor = .black
        
        captureSession = AVCaptureSession()
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get camera device")
            return
        }
        
        self.captureDevice = captureDevice
        
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Failed to create camera input")
            return
        }
        
        captureSession?.addInput(input)
        
        // Add photo output for capturing reference images
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput,
           captureSession?.canAddOutput(photoOutput) == true {
            captureSession?.addOutput(photoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer.frame = bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        // Start capture session on background thread to avoid UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    // Function to capture photo
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(nil)
            return
        }
        
        photoCaptureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func setupGestures() {
        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // Long press gesture
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        
        // Light haptic for tap
        triggerHaptic(.light)
        
        if isMeteringLocked {
            // If locked, unlock and meter new point
            delegate?.didTapAt(point: point)
        } else {
            // Regular tap to meter
            delegate?.didTapAt(point: point)
        }
        
        meterAtPoint(point)
        showMeteringCircle(at: point, locked: false)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let point = gesture.location(in: self)
            delegate?.didLongPressAt(point: point)
            meterAtPoint(point)
            showMeteringCircle(at: point, locked: true)
            
            // Medium haptic for lock (stronger feedback)
            triggerHaptic(.medium)
        }
    }
    
    private func meterAtPoint(_ point: CGPoint) {
        guard let captureDevice = captureDevice else { return }
        
        // Convert UI point to camera coordinates (0-1 range)
        let devicePoint = CGPoint(
            x: point.y / bounds.height, // Note: x and y are swapped for camera orientation
            y: 1.0 - (point.x / bounds.width)
        )
        
        do {
            try captureDevice.lockForConfiguration()
            
            // Set focus and exposure point
            if captureDevice.isFocusPointOfInterestSupported {
                captureDevice.focusPointOfInterest = devicePoint
                captureDevice.focusMode = .continuousAutoFocus
            }
            
            if captureDevice.isExposurePointOfInterestSupported {
                captureDevice.exposurePointOfInterest = devicePoint
                captureDevice.exposureMode = isMeteringLocked ? .locked : .continuousAutoExposure
            }
            
            captureDevice.unlockForConfiguration()
            
            // Calculate and report EV after a brief delay for camera to adjust
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.calculateAndReportEV()
            }
            
        } catch {
            print("Error setting focus/exposure point: \(error)")
        }
    }
    
    private func calculateAndReportEV() {
        guard let captureDevice = captureDevice else { return }
        
        // Get current camera settings
        let currentISO = captureDevice.iso
        let exposureDuration = captureDevice.exposureDuration
        let currentAperture = captureDevice.lensAperture
        
        // Convert exposure duration to seconds
        let shutterSpeed = CMTimeGetSeconds(exposureDuration)
        
        // Calculate EV using the standard formula
        // EV = log2(N²/t) + log2(S/100)
        // Where N = aperture, t = shutter speed in seconds, S = ISO
        let ev = log2(pow(Double(currentAperture), 2) / shutterSpeed) + log2(Double(currentISO) / 100.0)
        
        delegate?.didUpdateEV(ev)
    }
    
    private func showMeteringCircle(at point: CGPoint, locked: Bool) {
        // Remove existing circle
        meteringCircle?.removeFromSuperlayer()
        
        // Create new circle
        let circleRadius: CGFloat = 50
        let circlePath = UIBezierPath(
            arcCenter: point,
            radius: circleRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        
        let circle = CAShapeLayer()
        circle.path = circlePath.cgPath
        circle.fillColor = UIColor.clear.cgColor
        circle.strokeColor = locked ? UIColor.systemOrange.cgColor : UIColor.systemYellow.cgColor
        circle.lineWidth = 2.0
        
        layer.addSublayer(circle)
        meteringCircle = circle
        
        // Add pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.2
        pulseAnimation.toValue = 1.0
        pulseAnimation.duration = 0.3
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        circle.add(pulseAnimation, forKey: "pulse")
        
        // Auto-hide circle after 3 seconds if not locked
        if !locked {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                circle.removeFromSuperlayer()
                if self.meteringCircle == circle {
                    self.meteringCircle = nil
                }
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// Add photo capture delegate
extension CameraPreviewView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            photoCaptureCompletion?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            photoCaptureCompletion?(nil)
            return
        }
        
        photoCaptureCompletion?(imageData)
        photoCaptureCompletion = nil
    }
}

struct BottomControlsView: View {
    @Binding var currentEV: Double
    @Binding var currentAperture: Double
    @Binding var currentShutterSpeed: Double
    @Binding var currentISO: Double
    let onLogShot: (Double, Double, Double, Double) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - Exposure controls (2/3 of width)
            SimpleLightMeterView(
                currentEV: $currentEV,
                currentAperture: $currentAperture,
                currentShutterSpeed: $currentShutterSpeed,
                currentISO: $currentISO,
                onLogShot: onLogShot
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Right side - Action button (1/3 of width)
            ActionButtonView(
                currentAperture: currentAperture,
                currentShutterSpeed: currentShutterSpeed,
                currentISO: currentISO,
                currentEV: currentEV,
                onLogShot: onLogShot
            )
            .frame(maxWidth: 120, maxHeight: .infinity)
        }
    }
}

// SIMPLE LIGHT METER - Drag one, other two adjust (with lockable ISO and settings)
struct SimpleLightMeterView: View {
    @Binding var currentEV: Double
    @Binding var currentAperture: Double
    @Binding var currentShutterSpeed: Double
    @Binding var currentISO: Double
    let onLogShot: (Double, Double, Double, Double) -> Void
    
    // Settings
    @AppStorage("defaultISO") private var defaultISO = 100.0
    @AppStorage("stopSize") private var stopSize = "third"
    @AppStorage("showReciprocityFailure") private var showReciprocityFailure = true
    
    // Film stock integration
    @ObservedObject private var filmStockManager = FilmStockManager.shared
    @ObservedObject private var reciprocityCalculator = ReciprocityCalculator.shared
    @State private var showingFilmStockSettings = false
    @State private var calculatedExposure: ExposureSettings?
    @State private var reciprocityWarning: ReciprocityWarning?
    
    // Dynamic photography values based on stop size
    private var apertureStops: [Double] {
        switch stopSize {
        case "full":
            return [1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
        case "half":
            return [1.0, 1.2, 1.4, 1.7, 2.0, 2.4, 2.8, 3.3, 4.0, 4.8, 5.6, 6.7, 8.0, 9.5, 11.0, 13.0, 16.0, 19.0, 22.0]
        case "third":
            return [1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5, 4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10.0, 11.0, 13.0, 14.0, 16.0, 18.0, 20.0, 22.0]
        default:
            return [1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5, 4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10.0, 11.0, 13.0, 14.0, 16.0, 18.0, 20.0, 22.0]
        }
    }
    
    private var shutterSpeeds: [Double] {
        switch stopSize {
        case "full":
            return [30.0, 15.0, 8.0, 4.0, 2.0, 1.0, 1/2.0, 1/4.0, 1/8.0, 1/15.0, 1/30.0, 1/60.0, 1/125.0, 1/250.0, 1/500.0, 1/1000.0, 1/2000.0, 1/4000.0, 1/8000.0]
        case "half":
            return [30.0, 20.0, 15.0, 10.0, 8.0, 6.0, 4.0, 3.0, 2.0, 1.5, 1.0, 0.7, 1/2.0, 1/3.0, 1/4.0, 1/6.0, 1/8.0, 1/10.0, 1/15.0, 1/20.0, 1/30.0, 1/45.0, 1/60.0, 1/90.0, 1/125.0, 1/180.0, 1/250.0, 1/350.0, 1/500.0, 1/750.0, 1/1000.0, 1/1500.0, 1/2000.0, 1/3000.0, 1/4000.0, 1/6000.0, 1/8000.0]
        case "third":
            return [30.0, 25.0, 20.0, 15.0, 13.0, 10.0, 8.0, 6.0, 5.0, 4.0, 3.2, 2.5, 2.0, 1.6, 1.3, 1.0, 0.8, 0.6, 0.5, 0.4, 1/3.0, 1/4.0, 1/5.0, 1/6.0, 1/8.0, 1/10.0, 1/13.0, 1/15.0, 1/20.0, 1/25.0, 1/30.0, 1/40.0, 1/50.0, 1/60.0, 1/80.0, 1/100.0, 1/125.0, 1/160.0, 1/200.0, 1/250.0, 1/320.0, 1/400.0, 1/500.0, 1/640.0, 1/800.0, 1/1000.0, 1/1250.0, 1/1600.0, 1/2000.0, 1/2500.0, 1/3200.0, 1/4000.0, 1/5000.0, 1/6400.0, 1/8000.0]
        default:
            return [30.0, 25.0, 20.0, 15.0, 13.0, 10.0, 8.0, 6.0, 5.0, 4.0, 3.2, 2.5, 2.0, 1.6, 1.3, 1.0, 0.8, 0.6, 0.5, 0.4, 1/3.0, 1/4.0, 1/5.0, 1/6.0, 1/8.0, 1/10.0, 1/13.0, 1/15.0, 1/20.0, 1/25.0, 1/30.0, 1/40.0, 1/50.0, 1/60.0, 1/80.0, 1/100.0, 1/125.0, 1/160.0, 1/200.0, 1/250.0, 1/320.0, 1/400.0, 1/500.0, 1/640.0, 1/800.0, 1/1000.0, 1/1250.0, 1/1600.0, 1/2000.0, 1/2500.0, 1/3200.0, 1/4000.0, 1/5000.0, 1/6400.0, 1/8000.0]
        }
    }
    
    private var isoValues: [Double] {
        switch stopSize {
        case "full":
            return [25, 50, 100, 200, 400, 800, 1600, 3200, 6400, 12800]
        case "half":
            return [25, 32, 50, 64, 100, 125, 200, 250, 400, 500, 800, 1000, 1600, 2000, 3200, 4000, 6400, 8000, 12800]
        case "third":
            return [25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800]
        default:
            return [25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800]
        }
    }
    
    // Current indices for each setting
    @State private var apertureIndex: Int = 15  // Will be adjusted based on stop size
    @State private var shutterSpeedIndex: Int = 36  // Will be adjusted based on stop size
    @State private var isoIndex: Int = 6  // Will be adjusted based on default ISO
    
    // ISO lock state - locked by default for film workflow
    @State private var isoIsLocked: Bool = true
    
    // The baseline EV established by metering
    @State private var baselineEV: Double = 12.0
    @State private var hasMeterReading: Bool = false
    
    // Track which slider is being dragged
    @State private var isDraggingAperture: Bool = false
    @State private var isDraggingShutter: Bool = false
    @State private var isDraggingISO: Bool = false
    
    // Track if we need to reset to default ISO
    @State private var lastDefaultISO: Double = 100.0
    @State private var lastStopSize: String = "third"
    
    // Helper functions to get current values
    private var localCurrentAperture: Double {
        guard apertureIndex < apertureStops.count else { return 5.6 }
        return apertureStops[apertureIndex]
    }
    private var localCurrentShutterSpeed: Double {
        guard shutterSpeedIndex < shutterSpeeds.count else { return 1/125 }
        return shutterSpeeds[shutterSpeedIndex]
    }
    private var localCurrentISO: Double {
        guard isoIndex < isoValues.count else { return 100 }
        return isoValues[isoIndex]
    }
    
    // Update parent state when local values change
    private func updateParentState() {
        currentAperture = localCurrentAperture
        currentShutterSpeed = localCurrentShutterSpeed
        currentISO = localCurrentISO
    }
    
    // Update indices when settings change
    private func updateIndicesForSettings() {
        // Update ISO index to match default ISO setting
        if defaultISO != lastDefaultISO {
            isoIndex = findClosestIndex(defaultISO, in: isoValues)
            lastDefaultISO = defaultISO
        }
        
        // Update indices when stop size changes
        if stopSize != lastStopSize {
            let currentApertureValue = localCurrentAperture
            let currentShutterValue = localCurrentShutterSpeed
            let currentISOValue = localCurrentISO
            
            apertureIndex = findClosestIndex(currentApertureValue, in: apertureStops)
            shutterSpeedIndex = findClosestIndex(currentShutterValue, in: shutterSpeeds)
            isoIndex = findClosestIndex(currentISOValue, in: isoValues)
            
            lastStopSize = stopSize
        }
        
        updateParentState()
    }
    
    // Calculate reciprocity failure adjusted exposure time
    private var reciprocityAdjustedTime: Double {
        let baseTime = localCurrentShutterSpeed
        
        // Only apply reciprocity failure for exposures longer than 1 second
        guard baseTime >= 1.0 else { return baseTime }
        
        // Generic reciprocity failure formula (varies by film)
        // This is a simplified calculation - real reciprocity varies by film stock
        let reciprocityFactor = pow(baseTime, 0.15) // Typical reciprocity failure curve
        return baseTime * reciprocityFactor
    }
    
    // Function to format shutter speed display
    private func formatShutterSpeed(_ speed: Double) -> String {
        if speed >= 1.0 {
            if speed == floor(speed) {
                return "\(Int(speed))s"
            } else {
                return String(format: "%.1fs", speed)
            }
        } else {
            let denominator = Int(1.0 / speed)
            return "1/\(denominator)"
        }
    }
    
    // Find closest index for a value in an array
    private func findClosestIndex(_ value: Double, in array: [Double]) -> Int {
        var closestIndex = 0
        var smallestDiff = abs(value - array[0])
        
        for (index, arrayValue) in array.enumerated() {
            let diff = abs(value - arrayValue)
            if diff < smallestDiff {
                smallestDiff = diff
                closestIndex = index
            }
        }
        return closestIndex
    }
    
    // When user drags aperture, adjust the other unlocked setting
    private func adjustForApertureChange() {
        guard hasMeterReading && !isDraggingShutter && !isDraggingISO else { return }
        
        let targetEV = baselineEV
        let aperture = localCurrentAperture
        let iso = localCurrentISO
        
        if isoIsLocked {
            // ISO locked - adjust shutter speed
            let newShutterSpeed = pow(aperture, 2) / pow(2, targetEV - log2(iso / 100))
            shutterSpeedIndex = findClosestIndex(newShutterSpeed, in: shutterSpeeds)
        } else {
            // ISO unlocked - adjust ISO (keep current shutter speed)
            let shutter = localCurrentShutterSpeed
            let newISO = 100 * pow(2, targetEV - log2(pow(aperture, 2) / shutter))
            isoIndex = findClosestIndex(newISO, in: isoValues)
        }
        
        updateParentState()
    }
    
    // When user drags shutter, adjust the other unlocked setting
    private func adjustForShutterChange() {
        guard hasMeterReading && !isDraggingAperture && !isDraggingISO else { return }
        
        let targetEV = baselineEV
        let shutter = localCurrentShutterSpeed
        let iso = localCurrentISO
        
        if isoIsLocked {
            // ISO locked - adjust aperture
            let newAperture = sqrt(pow(2, targetEV - log2(iso / 100)) * shutter)
            apertureIndex = findClosestIndex(newAperture, in: apertureStops)
        } else {
            // ISO unlocked - adjust ISO (keep current aperture)
            let aperture = localCurrentAperture
            let newISO = 100 * pow(2, targetEV - log2(pow(aperture, 2) / shutter))
            isoIndex = findClosestIndex(newISO, in: isoValues)
        }
        
        updateParentState()
    }
    
    // When user drags ISO (only if unlocked), adjust shutter speed (prefer shutter over aperture)
    private func adjustForISOChange() {
        guard hasMeterReading && !isoIsLocked && !isDraggingAperture && !isDraggingShutter else { return }
        
        let targetEV = baselineEV
        let iso = localCurrentISO
        let aperture = localCurrentAperture
        
        // Adjust shutter speed to maintain EV
        let newShutterSpeed = pow(aperture, 2) / pow(2, targetEV - log2(iso / 100))
        shutterSpeedIndex = findClosestIndex(newShutterSpeed, in: shutterSpeeds)
        
        updateParentState()
    }
    
    // Handle new meter reading
    private func handleNewMeterReading() {
        baselineEV = currentEV
        hasMeterReading = true
    }
    
    // Setup callback for film stock selection
    private func setupFilmStockCallback() {
        filmStockManager.onFilmStockSelected = { filmStock in
            DispatchQueue.main.async {
                self.updateISOForFilmStock(filmStock)
            }
        }
    }
    
    // Update ISO when film stock is selected
    private func updateISOForFilmStock(_ filmStock: FilmStock?) {
        guard let filmStock = filmStock else { return }
        
        // Update the ISO index to match the film stock's ISO
        let newISOIndex = findClosestIndex(filmStock.iso, in: isoValues)
        isoIndex = newISOIndex
        
        // Update parent state
        updateParentState()
        
        // Trigger haptic feedback to indicate the change
        triggerHaptic(.light)
    }
    
    var body: some View {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 12) {
                    // EV Display at top
                    HStack {
                        Text("EV")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f", hasMeterReading ? baselineEV : currentEV))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if !hasMeterReading {
                            Text("TAP TO METER")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.leading, 6)
                        }
                    }
                    
                    // Film Stock Display
                    if let selectedFilmStock = filmStockManager.selectedFilmStock {
                        HStack {
                            Button(action: {
                                showingFilmStockSettings = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "film")
                                        .foregroundColor(.blue)
                                    Text(selectedFilmStock.name ?? "Unknown")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("ISO \(Int(selectedFilmStock.iso))")
                                        .font(.caption2)
                                        .foregroundColor(.blue.opacity(0.8))
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.blue.opacity(0.6))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    } else {
                        HStack {
                            Button(action: {
                                showingFilmStockSettings = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.orange)
                                    Text("Select Film Stock")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }
                    
                    // Exposure controls in middle
                    VStack(spacing: 8) {
                        // Calculate responsive width based on available space
                        let labelWidth = max(55, min(90, geometry.size.width * 0.22))
                        
                        // Aperture
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Text("f/")
                                    .foregroundColor(.white)
                                Text(String(format: "%.1f", localCurrentAperture))
                                    .foregroundColor(.white)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .frame(minWidth: labelWidth, alignment: .leading)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(apertureIndex) },
                                    set: { newValue in
                                        let newIndex = Int(newValue)
                                        if newIndex != apertureIndex {
                                            // Haptic feedback for each step change
                                            triggerSelectionHaptic()
                                            apertureIndex = newIndex
                                            updateParentState()
                                            if !isDraggingAperture {
                                                adjustForApertureChange()
                                            }
                                        }
                                    }
                                ),
                                in: 0...Double(apertureStops.count - 1),
                                step: 1,
                                onEditingChanged: { isEditing in
                                    isDraggingAperture = isEditing
                                    if !isEditing {
                                        adjustForApertureChange()
                                        triggerHaptic(.light) // Final haptic when slider stops
                                    }
                                }
                            )
                        }
                        
                        // Shutter Speed
                        HStack(spacing: 8) {
                            Text(formatShutterSpeed(localCurrentShutterSpeed))
                                .foregroundColor(.white)
                                .font(.system(.body, design: .monospaced))
                                .frame(minWidth: labelWidth, alignment: .leading)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(shutterSpeedIndex) },
                                    set: { newValue in
                                        let newIndex = Int(newValue)
                                        if newIndex != shutterSpeedIndex {
                                            // Haptic feedback for each step change
                                            triggerSelectionHaptic()
                                            shutterSpeedIndex = newIndex
                                            updateParentState()
                                            if !isDraggingShutter {
                                                adjustForShutterChange()
                                            }
                                        }
                                    }
                                ),
                                in: 0...Double(shutterSpeeds.count - 1),
                                step: 1,
                                onEditingChanged: { isEditing in
                                    isDraggingShutter = isEditing
                                    if !isEditing {
                                        adjustForShutterChange()
                                        triggerHaptic(.light) // Final haptic when slider stops
                                    }
                                }
                            )
                        }
                        
                        // ISO (with lock button)
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Text("ISO")
                                    .foregroundColor(.white)
                                Text(String(format: "%.0f", localCurrentISO))
                                    .foregroundColor(.white)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .frame(minWidth: labelWidth, alignment: .leading)
                            
                            if !isoIsLocked {
                                Slider(
                                    value: Binding(
                                        get: { Double(isoIndex) },
                                        set: { newValue in
                                            let newIndex = Int(newValue)
                                            if newIndex != isoIndex {
                                                // Haptic feedback for each step change
                                                triggerSelectionHaptic()
                                                isoIndex = newIndex
                                                updateParentState()
                                                if !isDraggingISO {
                                                    adjustForISOChange()
                                                }
                                            }
                                        }
                                    ),
                                    in: 0...Double(isoValues.count - 1),
                                    step: 1,
                                    onEditingChanged: { isEditing in
                                        isDraggingISO = isEditing
                                        if !isEditing {
                                            adjustForISOChange()
                                            triggerHaptic(.light) // Final haptic when slider stops
                                        }
                                    }
                                )
                            } else {
                                Slider(value: .constant(Double(isoIndex)), in: 0...Double(isoValues.count - 1), step: 1)
                                    .disabled(true)
                                    .opacity(0.6)
                            }
                            
                            // Lock button for ISO
                            Button(action: {
                                isoIsLocked.toggle()
                                triggerHaptic(.medium) // Medium haptic for important state change
                            }) {
                                Image(systemName: isoIsLocked ? "lock.fill" : "lock.open")
                                    .foregroundColor(isoIsLocked ? .yellow : .gray)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    
                    // Reciprocity failure display at bottom (only if setting is enabled)
                    if hasMeterReading && showReciprocityFailure {
                        VStack(alignment: .leading, spacing: 4) {
                            // Calculate exposure settings with film stock
                            let exposureSettings = reciprocityCalculator.calculateExposure(
                                meteredEV: baselineEV,
                                filmStock: filmStockManager.selectedFilmStock,
                                baseISO: defaultISO,
                                pushPullStops: filmStockManager.pushPullStops
                            )
                            
                            // Check for reciprocity warning
                            let warning = reciprocityCalculator.getReciprocityWarning(
                                for: localCurrentShutterSpeed,
                                filmStock: filmStockManager.selectedFilmStock
                            )
                            
                            if let warning = warning {
                                HStack {
                                    Text("Reciprocity:")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    Text("f/\(String(format: "%.1f", localCurrentAperture)) • \(formatShutterSpeed(warning.correctedTime)) • ISO \(String(format: "%.0f", exposureSettings.effectiveISO))")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .fontWeight(.medium)
                                }
                                
                                Text(warning.message)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else {
                                HStack {
                                    Text("Exposure:")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    Text("f/\(String(format: "%.1f", localCurrentAperture)) • \(formatShutterSpeed(localCurrentShutterSpeed)) • ISO \(String(format: "%.0f", exposureSettings.effectiveISO))")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if isoIsLocked {
                                Text("(ISO locked)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else if !hasMeterReading {
                        Text("Tap scene to meter")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: currentEV) { oldValue, newValue in
                // New meter reading - establish baseline
                if abs(newValue - oldValue) > 0.1 {
                    handleNewMeterReading()
                }
            }
            .sheet(isPresented: $showingFilmStockSettings) {
                FilmStockSettingsView()
            }
            .onChange(of: defaultISO) { _, _ in
                updateIndicesForSettings()
            }
            .onChange(of: stopSize) { _, _ in
                updateIndicesForSettings()
            }
            .onAppear {
                baselineEV = currentEV
                hasMeterReading = true
                lastDefaultISO = defaultISO
                lastStopSize = stopSize
                updateIndicesForSettings()
                setupFilmStockCallback()
            }
        }
    }

    struct ActionButtonView: View {
        let currentAperture: Double
        let currentShutterSpeed: Double
        let currentISO: Double
        let currentEV: Double
        let onLogShot: (Double, Double, Double, Double) -> Void
        
        @State private var showingHistory = false
        @State private var showingSettings = false
        
        var body: some View {
            VStack(spacing: 20) {
                // Main Log Shot button
                Button(action: {
                    triggerHaptic(.heavy) // Strong haptic for main action
                    onLogShot(currentAperture, currentShutterSpeed, currentISO, currentEV)
                }) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.title)
                        Text("Log Shot")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.blue)
                    .cornerRadius(40)
                }
                
                // Small settings button
                Button(action: {
                    triggerHaptic(.light) // Light haptic for secondary actions
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                // Small history button
                Button(action: {
                    triggerHaptic(.light) // Light haptic for secondary actions
                    showingHistory = true
                }) {
                    Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showingHistory) {
                ShotHistoryView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Shot History View
    struct ShotHistoryView: View {
        @Environment(\.dismiss) private var dismiss
        @ObservedObject private var coreDataManager = CoreDataManager.shared
        @State private var loggedShots: [LoggedShot] = []
        
        var body: some View {
            NavigationView {
                List {
                    if loggedShots.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No shots logged yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Use the light meter to log your first shot!")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.top, 100)
                    } else {
                        ForEach(loggedShots, id: \.id) { shot in
                            ShotRowView(shot: shot)
                        }
                        .onDelete(perform: deleteShots)
                    }
                }
                .navigationTitle("Shot History")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    
                    if !loggedShots.isEmpty {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                    }
                }
            }
            .onAppear {
                loadShots()
            }
        }
        
        private func loadShots() {
            loggedShots = coreDataManager.fetchLoggedShots()
        }
        
        private func deleteShots(offsets: IndexSet) {
            withAnimation {
                for index in offsets {
                    coreDataManager.deleteLoggedShot(loggedShots[index])
                }
                loadShots() // Refresh the list
            }
        }
    }

    struct ShotRowView: View {
        let shot: LoggedShot
        
        private var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: shot.timestamp ?? Date())
        }
        
        private func formatShutterSpeed(_ speed: Double) -> String {
            if speed >= 1.0 {
                if speed == floor(speed) {
                    return "\(Int(speed))s"
                } else {
                    return String(format: "%.1fs", speed)
                }
            } else {
                let denominator = Int(1.0 / speed)
                return "1/\(denominator)"
            }
        }
        
        var body: some View {
            NavigationLink(destination: ShotDetailView(shot: shot)) {
                HStack(spacing: 12) {
                    // Reference photo thumbnail
                    if let imageData = shot.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "camera")
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Exposure settings
                        HStack {
                            Text("f/\(String(format: "%.1f", shot.aperture))")
                                .fontWeight(.medium)
                            Text("•")
                                .foregroundColor(.gray)
                            Text(formatShutterSpeed(shot.shutterSpeed))
                                .fontWeight(.medium)
                            Text("•")
                                .foregroundColor(.gray)
                            Text("ISO \(String(format: "%.0f", shot.iso))")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        
                        // EV and date
                        HStack {
                            Text("EV \(String(format: "%.1f", shot.ev))")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Location if available
                        if let locationName = shot.locationName {
                            Text(locationName)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    struct ShotDetailView: View {
        let shot: LoggedShot
        @State private var notes: String = ""
        @State private var isEditingNotes = false
        @ObservedObject private var coreDataManager = CoreDataManager.shared
        
        private var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            return formatter.string(from: shot.timestamp ?? Date())
        }
        
        private func formatShutterSpeed(_ speed: Double) -> String {
            if speed >= 1.0 {
                if speed == floor(speed) {
                    return "\(Int(speed))s"
                } else {
                    return String(format: "%.1fs", speed)
                }
            } else {
                let denominator = Int(1.0 / speed)
                return "1/\(denominator)"
            }
        }
        
        private var hasValidLocation: Bool {
            shot.latitude != 0 && shot.longitude != 0
        }
        
        private var shotLocation: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: shot.latitude, longitude: shot.longitude)
        }
        
        private func openInMaps() {
            let coordinate = shotLocation
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = shot.locationName ?? "Photo Location"
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
            ])
        }
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Reference photo
                    if let imageData = shot.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                    
                    // Exposure settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exposure Settings")
                            .font(.headline)
                        
                        HStack {
                            Label("f/\(String(format: "%.1f", shot.aperture))", systemImage: "camera.aperture")
                            Spacer()
                            Label(formatShutterSpeed(shot.shutterSpeed), systemImage: "timer")
                            Spacer()
                            Label("ISO \(String(format: "%.0f", shot.iso))", systemImage: "camera.filters")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        
                        Label("EV \(String(format: "%.1f", shot.ev))", systemImage: "sun.max")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.headline)
                        
                        Label(formattedDate, systemImage: "clock")
                            .font(.subheadline)
                        
                        if let locationName = shot.locationName {
                            Button(action: openInMaps) {
                                Label(locationName, systemImage: "location")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if hasValidLocation {
                            Button(action: openInMaps) {
                                Label("GPS: \(String(format: "%.6f", shot.latitude)), \(String(format: "%.6f", shot.longitude))", systemImage: "globe")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Map view (if location data exists)
                    if hasValidLocation {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.headline)
                            
                            ShotLocationMapView(
                                coordinate: shotLocation,
                                locationName: shot.locationName ?? "Photo Location"
                            )
                            .frame(height: 200)
                            .cornerRadius(12)
                            .onTapGesture {
                                openInMaps()
                            }
                            
                            Button(action: openInMaps) {
                                HStack {
                                    Image(systemName: "map")
                                    Text("Open in Maps")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Notes section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                            Button(isEditingNotes ? "Done" : "Edit") {
                                if isEditingNotes {
                                    saveNotes()
                                }
                                isEditingNotes.toggle()
                            }
                            .foregroundColor(.blue)
                        }
                        
                        if isEditingNotes {
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        } else {
                            if notes.isEmpty {
                                Text("Tap Edit to add notes about this shot...")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                Text(notes)
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Shot Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                notes = shot.notes ?? ""
            }
        }
        
        private func saveNotes() {
            shot.notes = notes.isEmpty ? nil : notes
            coreDataManager.save()
        }
    }

struct ShotLocationMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let locationName: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = true
        mapView.showsUserLocation = false
        
        // Create annotation for the shot location
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = locationName
        annotation.subtitle = "Photo taken here"
        
        mapView.addAnnotation(annotation)
        
        // Set region to show the shot location
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        mapView.setRegion(region, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "ShotLocation"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "camera.fill")
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}

    // MARK: - Settings View
    struct SettingsView: View {
        @Environment(\.dismiss) private var dismiss
        @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
        @AppStorage("enableLocationServices") private var enableLocationServices = true
        @AppStorage("defaultISO") private var defaultISO = 100.0
        @AppStorage("showReciprocityFailure") private var showReciprocityFailure = true
        @AppStorage("stopSize") private var stopSize = "third" // "full", "half", "third"
        @AppStorage("appearanceMode") private var appearanceMode = "system" // "system", "light", "dark"
        
        @Environment(\.colorScheme) private var systemColorScheme
        
        @ObservedObject private var coreDataManager = CoreDataManager.shared
        @State private var showingClearDataAlert = false
        @State private var showingExportSuccessAlert = false
        @State private var showingExportFailureAlert = false
        @State private var isExporting = false
        
        var body: some View {
            NavigationView {
                List {
                    Section("General") {
                        HStack {
                            Image(systemName: "hand.tap")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                        }
                        
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Toggle("Location Services", isOn: $enableLocationServices)
                        }
                    }
                    
                    Section("Appearance") {
                        HStack {
                            Image(systemName: "moon")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            Text("Dark Mode")
                            Spacer()
                            Picker("Appearance", selection: $appearanceMode) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 180)
                        }
                    }
                    
                    Section("Light Meter") {
                        HStack {
                            Image(systemName: "camera.filters")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            Text("Default ISO")
                            Spacer()
                            Picker("", selection: $defaultISO) {
                                Text("25").tag(25.0)
                                Text("50").tag(50.0)
                                Text("100").tag(100.0)
                                Text("200").tag(200.0)
                                Text("400").tag(400.0)
                                Text("800").tag(800.0)
                                Text("1600").tag(1600.0)
                                Text("3200").tag(3200.0)
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        HStack {
                            Image(systemName: "dial.high")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            Text("Stop Size")
                            Spacer()
                            Picker("", selection: $stopSize) {
                                Text("Full Stops").tag("full")
                                Text("Half Stops").tag("half")
                                Text("Third Stops").tag("third")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            Toggle("Show Reciprocity Failure", isOn: $showReciprocityFailure)
                        }
                    }
                    
                    Section("Film Stock") {
                        NavigationLink(destination: FilmStockSettingsView()) {
                            HStack {
                                Image(systemName: "film")
                                    .foregroundColor(.purple)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Film Stock Database")
                                        .foregroundColor(.primary)
                                    if let selectedFilmStock = FilmStockManager.shared.selectedFilmStock {
                                        Text(selectedFilmStock.name ?? "Unknown")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("No film stock selected")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Section("Planning Tools") {
                        NavigationLink(destination: SunCalculatorView()) {
                            HStack {
                                Image(systemName: "sun.max")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text("Sun Calculator")
                                        .foregroundColor(.primary)
                                    Text("Golden hour, blue hour & moon phases")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Section("About") {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.gray)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("Sprocket")
                                    .font(.headline)
                                Text("The Film Photographer's Toolkit")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text("v1.0")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.gray)
                                .frame(width: 30)
                            Text("Send Feedback")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Section("Data") {
                        Button(action: exportShotData) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                if isExporting {
                                    Text("Exporting...")
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Export Shot Data")
                                    Spacer()
                                }
                            }
                        }
                        .disabled(isExporting)
                        
                        Button(action: {
                            showingClearDataAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 30)
                                Text("Clear All Data")
                                Spacer()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .preferredColorScheme(currentColorScheme)
                .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear All", role: .destructive) {
                        clearAllData()
                    }
                } message: {
                    Text("This will permanently delete all logged shots and their reference photos. This action cannot be undone.")
                }
                .alert("Export Successful", isPresented: $showingExportSuccessAlert) {
                    Button("OK") { }
                } message: {
                    Text("Your shot data has been exported successfully. Check your Files app for the CSV file.")
                }
                .alert("Export Failed", isPresented: $showingExportFailureAlert) {
                    Button("OK") { }
                } message: {
                    Text("Unable to export shot data. Please try again.")
                }
            }
        }
        
        private func exportShotData() {
            isExporting = true
            
            let shots = coreDataManager.fetchLoggedShots()
            
            guard !shots.isEmpty else {
                isExporting = false
                showingExportFailureAlert = true
                return
            }
            
            let csvContent = generateCSVContent(from: shots)
            let fileName = "Sprocket_Shots_\(dateString()).csv"
            
            // Create temporary file
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
                
                // Present share sheet immediately
                presentShareSheet(for: fileURL)
                
            } catch {
                print("Export error: \(error)")
                isExporting = false
                showingExportFailureAlert = true
            }
        }
        
        private func dateString() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }
        
        private func presentShareSheet(for fileURL: URL) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                isExporting = false
                showingExportFailureAlert = true
                return
            }
            
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // iPad support
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            // Present from the topmost view controller
            if let rootVC = window.rootViewController {
                var topVC = rootVC
                while let presentedVC = topVC.presentedViewController {
                    topVC = presentedVC
                }
                
                topVC.present(activityViewController, animated: true) {
                    self.isExporting = false
                }
            } else {
                isExporting = false
                showingExportFailureAlert = true
            }
        }
        
        private func generateCSVContent(from shots: [LoggedShot]) -> String {
            var csv = "Date,Time,Aperture,Shutter Speed,ISO,EV,Location,Latitude,Longitude,Notes\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            for shot in shots {
                let date = dateFormatter.string(from: shot.timestamp ?? Date())
                let time = timeFormatter.string(from: shot.timestamp ?? Date())
                let aperture = String(format: "%.1f", shot.aperture)
                let shutter = formatShutterSpeedForCSV(shot.shutterSpeed)
                let iso = String(format: "%.0f", shot.iso)
                            let ev = String(format: "%.1f", shot.ev)
                            let location = shot.locationName?.replacingOccurrences(of: ",", with: " ") ?? ""
                            let lat = shot.latitude == 0 ? "" : String(format: "%.6f", shot.latitude)
                            let lon = shot.longitude == 0 ? "" : String(format: "%.6f", shot.longitude)
                            let notes = shot.notes?.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ") ?? ""
                            
                            csv += "\(date),\(time),f/\(aperture),\(shutter),\(iso),\(ev),\(location),\(lat),\(lon),\"\(notes)\"\n"
                        }
                        
                        return csv
                    }
                    
                    private func formatShutterSpeedForCSV(_ speed: Double) -> String {
                        if speed >= 1.0 {
                            return speed == floor(speed) ? "\(Int(speed))s" : String(format: "%.1fs", speed)
                        } else {
                            let denominator = Int(1.0 / speed)
                            return "1/\(denominator)s"
                        }
                    }
                    
                    private func clearAllData() {
                        coreDataManager.clearAllData()
                    }
                    
                    private var currentColorScheme: ColorScheme? {
                        switch appearanceMode {
                        case "light":
                            return .light
                        case "dark":
                            return .dark
                        default:
                            return nil // System default
                        }
                    }
                }

                #Preview {
                    ContentView()
                }
