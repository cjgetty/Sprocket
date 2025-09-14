import SwiftUI
import UIKit
import AVFoundation

// MARK: - iPhone Camera Specifications
struct iPhoneCameraSpec {
    let focalLength: Double // in mm
    let fieldOfView: Double // horizontal FOV in degrees
    let sensorFormat: String
}

// MARK: - Camera Frame Overlay Manager
class CameraFrameOverlayManager: ObservableObject {
    @Published var isOverlayEnabled: Bool = false
    @Published var selectedTargetFormat: CameraFormat = CameraFormat.fullFrame
    @Published var selectedTargetFocalLength: Double = 50.0
    @Published var overlayOpacity: Double = 0.7
    @Published var showMultipleFrames: Bool = false
    
    // iPhone camera specifications (using iPhone 16 as baseline)
    static let iPhoneMainCamera = iPhoneCameraSpec(
        focalLength: 26.0, // iPhone 16 main camera
        fieldOfView: 77.0, // Approximate horizontal FOV for 26mm on iPhone sensor
        sensorFormat: "iPhone"
    )
    
    static let iPhoneUltraWideCamera = iPhoneCameraSpec(
        focalLength: 13.0,
        fieldOfView: 120.0, // Specified by Apple
        sensorFormat: "iPhone"
    )
    
    // Calculate the crop factor needed to show target lens FOV within iPhone's FOV
    func calculateOverlayScale(for targetFormat: CameraFormat, targetFocalLength: Double) -> CGFloat {
        // Calculate target lens FOV
        let targetHorizontalFOV = 2 * atan(targetFormat.sensorWidth / (2 * targetFocalLength)) * 180 / .pi
        
        // Use iPhone main camera as reference
        let iPhoneFOV = Self.iPhoneMainCamera.fieldOfView
        
        // If target FOV is wider than iPhone, we can't show it (would need to zoom out)
        guard targetHorizontalFOV <= iPhoneFOV else {
            return 1.0 // Show full frame if target is wider
        }
        
        // Calculate scale factor: smaller FOV = larger scale (crop in)
        let scaleFactor = targetHorizontalFOV / iPhoneFOV
        return CGFloat(scaleFactor)
    }
    
    // Calculate aspect ratio for different camera formats
    func calculateAspectRatio(for format: CameraFormat) -> CGFloat {
        return CGFloat(format.sensorWidth / format.sensorHeight)
    }
    
    // Get multiple focal lengths for comparison
    func getComparisonFocalLengths() -> [Double] {
        return [24, 35, 50, 85, 135]
    }
}

// MARK: - Camera Frame Overlay View
struct CameraFrameOverlayView: UIViewRepresentable {
    @ObservedObject var overlayManager: CameraFrameOverlayManager
    
    func makeUIView(context: Context) -> CameraOverlayUIView {
        let overlayView = CameraOverlayUIView()
        overlayView.overlayManager = overlayManager
        return overlayView
    }
    
    func updateUIView(_ uiView: CameraOverlayUIView, context: Context) {
        uiView.updateOverlay()
    }
}

// MARK: - Custom UIView for Frame Overlay
class CameraOverlayUIView: UIView {
    var overlayManager: CameraFrameOverlayManager?
    private var frameViews: [UIView] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateOverlay() {
        // Clear existing frame views
        frameViews.forEach { $0.removeFromSuperview() }
        frameViews.removeAll()
        
        guard let manager = overlayManager, manager.isOverlayEnabled else { return }
        
        if manager.showMultipleFrames {
            // Show multiple focal length comparisons
            let focalLengths = manager.getComparisonFocalLengths()
            for (index, focalLength) in focalLengths.enumerated() {
                let frameView = createFrameView(
                    for: manager.selectedTargetFormat,
                    focalLength: focalLength,
                    color: getColorForIndex(index),
                    label: "\(Int(focalLength))mm"
                )
                addSubview(frameView)
                frameViews.append(frameView)
            }
        } else {
            // Show single focal length frame
            let frameView = createFrameView(
                for: manager.selectedTargetFormat,
                focalLength: manager.selectedTargetFocalLength,
                color: .systemBlue,
                label: "\(Int(manager.selectedTargetFocalLength))mm"
            )
            addSubview(frameView)
            frameViews.append(frameView)
        }
        
        layoutFrameViews()
    }
    
    private func createFrameView(for format: CameraFormat, focalLength: Double, color: UIColor, label: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Calculate frame dimensions
        let scale = overlayManager?.calculateOverlayScale(for: format, targetFocalLength: focalLength) ?? 1.0
        let aspectRatio = overlayManager?.calculateAspectRatio(for: format) ?? (3.0/2.0)
        
        // Create frame border
        let frameView = UIView()
        frameView.backgroundColor = .clear
        frameView.layer.borderColor = color.cgColor
        frameView.layer.borderWidth = 2.0
        frameView.layer.cornerRadius = 4.0
        frameView.alpha = overlayManager?.overlayOpacity ?? 0.7
        
        // Add label
        let labelView = UILabel()
        labelView.text = label
        labelView.textColor = color
        labelView.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        labelView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        labelView.textAlignment = .center
        labelView.layer.cornerRadius = 8
        labelView.layer.masksToBounds = true
        labelView.alpha = overlayManager?.overlayOpacity ?? 0.7
        
        containerView.addSubview(frameView)
        containerView.addSubview(labelView)
        
        // Store scale and aspect ratio for layout
        containerView.tag = Int(scale * 1000) // Store scale in tag for layout
        frameView.tag = Int(aspectRatio * 1000) // Store aspect ratio in frame tag
        
        return containerView
    }
    
    private func layoutFrameViews() {
        guard !frameViews.isEmpty else { return }
        
        let containerSize = bounds.size
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        for frameView in frameViews {
            let scale = CGFloat(frameView.tag) / 1000.0
            let aspectRatio = CGFloat(frameView.subviews.first?.tag ?? 1500) / 1000.0
            
            // Calculate frame size based on container and scale
            let maxWidth = containerSize.width * 0.8 // Leave some margin
            let maxHeight = containerSize.height * 0.8
            
            var frameWidth = maxWidth * scale
            var frameHeight = frameWidth / aspectRatio
            
            // Ensure frame fits within bounds
            if frameHeight > maxHeight {
                frameHeight = maxHeight * scale
                frameWidth = frameHeight * aspectRatio
            }
            
            // Position frame
            let frameRect = CGRect(
                x: centerX - frameWidth / 2,
                y: centerY - frameHeight / 2,
                width: frameWidth,
                height: frameHeight
            )
            
            frameView.frame = frameRect
            
            // Layout subviews (frame border and label)
            if let borderView = frameView.subviews.first {
                borderView.frame = frameView.bounds
            }
            
            if let labelView = frameView.subviews.last as? UILabel {
                let labelSize = CGSize(width: 60, height: 20)
                labelView.frame = CGRect(
                    x: 8,
                    y: 8,
                    width: labelSize.width,
                    height: labelSize.height
                )
            }
        }
    }
    
    private func getColorForIndex(_ index: Int) -> UIColor {
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemRed, .systemPurple]
        return colors[index % colors.count]
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutFrameViews()
    }
}

// MARK: - Frame Overlay Settings View
struct FrameOverlaySettingsView: View {
    @ObservedObject var overlayManager: CameraFrameOverlayManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    private var currentColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Frame Overlay") {
                    Toggle("Enable Frame Overlay", isOn: $overlayManager.isOverlayEnabled)
                    
                    if overlayManager.isOverlayEnabled {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Slider(value: $overlayManager.overlayOpacity, in: 0.3...1.0, step: 0.1)
                                .frame(width: 120)
                            Text("\(Int(overlayManager.overlayOpacity * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 35)
                        }
                    }
                }
                
                if overlayManager.isOverlayEnabled {
                    Section("Target Lens") {
                        Picker("Camera Format", selection: $overlayManager.selectedTargetFormat) {
                            ForEach(LensCalculatorManager.formats, id: \.name) { format in
                                Text(format.commonName).tag(format)
                            }
                        }
                        
                        HStack {
                            Text("Focal Length")
                            Spacer()
                            Text("\(Int(overlayManager.selectedTargetFocalLength))mm")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $overlayManager.selectedTargetFocalLength, in: 14...200, step: 1)
                    }
                    
                    Section("Display Options") {
                        Toggle("Show Multiple Focal Lengths", isOn: $overlayManager.showMultipleFrames)
                        
                        if overlayManager.showMultipleFrames {
                            Text("Shows 24mm, 35mm, 50mm, 85mm, 135mm comparison")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section("Preview Info") {
                        let targetFOV = 2 * atan(overlayManager.selectedTargetFormat.sensorWidth / (2 * overlayManager.selectedTargetFocalLength)) * 180 / .pi
                        let iPhoneFOV = CameraFrameOverlayManager.iPhoneMainCamera.fieldOfView
                        
                        HStack {
                            Text("Target FOV")
                            Spacer()
                            Text("\(String(format: "%.1f", targetFOV))°")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("iPhone FOV")
                            Spacer()
                            Text("\(String(format: "%.1f", iPhoneFOV))°")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        if targetFOV > iPhoneFOV {
                            Label("Target lens is wider than iPhone camera", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Frame Overlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(currentColorScheme)
    }
}

// MARK: - Preview
struct FrameOverlaySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FrameOverlaySettingsView(overlayManager: CameraFrameOverlayManager())
    }
}
