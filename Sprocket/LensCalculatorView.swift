import SwiftUI
import Foundation

// MARK: - Camera Format Definitions
struct CameraFormat: Hashable {
    let name: String
    let sensorWidth: Double // in mm
    let sensorHeight: Double // in mm
    let cropFactor: Double
    let commonName: String
    
    var diagonalSize: Double {
        sqrt(sensorWidth * sensorWidth + sensorHeight * sensorHeight)
    }
}

// MARK: - Lens Calculator Manager
class LensCalculatorManager: ObservableObject {
    @Published var selectedFormat: CameraFormat = CameraFormat.fullFrame
    @Published var focalLength: Double = 50.0
    @Published var subjectDistance: Double = 5.0 // meters
    @Published var comparisonFormat: CameraFormat = CameraFormat.apsc15x
    @Published var showComparison: Bool = false
    
    // Common camera formats
    static let formats: [CameraFormat] = [
        CameraFormat(name: "Full Frame", sensorWidth: 36.0, sensorHeight: 24.0, cropFactor: 1.0, commonName: "35mm"),
        CameraFormat(name: "APS-C Canon", sensorWidth: 22.3, sensorHeight: 14.9, cropFactor: 1.6, commonName: "Canon APS-C"),
        CameraFormat(name: "APS-C Nikon/Sony", sensorWidth: 23.5, sensorHeight: 15.6, cropFactor: 1.5, commonName: "APS-C"),
        CameraFormat(name: "Micro Four Thirds", sensorWidth: 17.3, sensorHeight: 13.0, cropFactor: 2.0, commonName: "M4/3"),
        CameraFormat(name: "Medium Format", sensorWidth: 44.0, sensorHeight: 33.0, cropFactor: 0.79, commonName: "645"),
        CameraFormat(name: "Large Format", sensorWidth: 102.0, sensorHeight: 127.0, cropFactor: 0.3, commonName: "4x5")
    ]
    
    // Field of view calculations
    func horizontalFOV(for format: CameraFormat) -> Double {
        let angle = 2 * atan(format.sensorWidth / (2 * focalLength))
        return angle * 180 / .pi
    }
    
    func verticalFOV(for format: CameraFormat) -> Double {
        let angle = 2 * atan(format.sensorHeight / (2 * focalLength))
        return angle * 180 / .pi
    }
    
    func diagonalFOV(for format: CameraFormat) -> Double {
        let angle = 2 * atan(format.diagonalSize / (2 * focalLength))
        return angle * 180 / .pi
    }
    
    // Equivalent focal length
    func equivalentFocalLength(from sourceFormat: CameraFormat, to targetFormat: CameraFormat) -> Double {
        return focalLength * (targetFormat.cropFactor / sourceFormat.cropFactor)
    }
    
    // Frame coverage at distance
    func frameCoverage(for format: CameraFormat) -> (width: Double, height: Double) {
        let hFOV = horizontalFOV(for: format) * .pi / 180
        let vFOV = verticalFOV(for: format) * .pi / 180
        
        let width = 2 * subjectDistance * tan(hFOV / 2)
        let height = 2 * subjectDistance * tan(vFOV / 2)
        
        return (width: width, height: height)
    }
}

// MARK: - Extensions for predefined formats
extension CameraFormat {
    static let fullFrame = CameraFormat(name: "Full Frame", sensorWidth: 36.0, sensorHeight: 24.0, cropFactor: 1.0, commonName: "35mm")
    static let apsc15x = CameraFormat(name: "APS-C Nikon/Sony", sensorWidth: 23.5, sensorHeight: 15.6, cropFactor: 1.5, commonName: "APS-C")
    static let apsc16x = CameraFormat(name: "APS-C Canon", sensorWidth: 22.3, sensorHeight: 14.9, cropFactor: 1.6, commonName: "Canon APS-C")
    static let microFourThirds = CameraFormat(name: "Micro Four Thirds", sensorWidth: 17.3, sensorHeight: 13.0, cropFactor: 2.0, commonName: "M4/3")
}

// MARK: - Main Lens Calculator View
struct LensCalculatorView: View {
    @StateObject private var calculator = LensCalculatorManager()
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    private var currentColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Focal Length Input
                    focalLengthSection
                    
                    // Camera Format Selection
                    formatSelectionSection
                    
                    // Field of View Results
                    fieldOfViewSection
                    
                    // Crop Factor Conversions
                    cropFactorSection
                    
                    // Subject Distance & Frame Coverage
                    frameCoverageSection
                    
                    // Comparison Tool
                    comparisonSection
                }
                .padding()
            }
            .navigationTitle("Lens Calculator")
        }
        .preferredColorScheme(currentColorScheme)
    }
    
    // MARK: - Focal Length Section
    private var focalLengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focal Length")
                .font(.headline)
            
            HStack {
                Text("\(Int(calculator.focalLength))mm")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(width: 80, alignment: .leading)
                
                Slider(value: $calculator.focalLength, in: 8...600, step: 1)
                    .accentColor(.blue)
            }
            
            // Common focal length presets
            let focalLengthPresets = [14, 24, 35, 50, 85, 135, 200, 400]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(focalLengthPresets, id: \.self) { focal in
                    Button("\(focal)mm") {
                        calculator.focalLength = Double(focal)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(calculator.focalLength == Double(focal) ? Color.blue : Color(UIColor.systemGray5))
                    .foregroundColor(calculator.focalLength == Double(focal) ? .white : .primary)
                    .cornerRadius(6)
                }
            }
        }
        .padding()
.background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Format Selection Section
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Format")
                .font(.headline)
            
            Picker("Format", selection: $calculator.selectedFormat) {
                ForEach(LensCalculatorManager.formats, id: \.name) { format in
                    VStack(alignment: .leading) {
                        Text(format.name)
                        Text(format.commonName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            // Format details
            HStack {
                VStack(alignment: .leading) {
                    Text("Sensor Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", calculator.selectedFormat.sensorWidth)) × \(String(format: "%.1f", calculator.selectedFormat.sensorHeight))mm")
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Crop Factor")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", calculator.selectedFormat.cropFactor))×")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
.background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Field of View Section
    private var fieldOfViewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field of View")
                .font(.headline)
            
            VStack(spacing: 8) {
                fieldOfViewRow(title: "Horizontal", angle: calculator.horizontalFOV(for: calculator.selectedFormat), icon: "arrow.left.and.right")
                fieldOfViewRow(title: "Vertical", angle: calculator.verticalFOV(for: calculator.selectedFormat), icon: "arrow.up.and.down")
                fieldOfViewRow(title: "Diagonal", angle: calculator.diagonalFOV(for: calculator.selectedFormat), icon: "arrow.up.right.and.arrow.down.left")
            }
        }
        .padding()
.background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private func fieldOfViewRow(title: String, angle: Double, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(String(format: "%.1f", angle))°")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Crop Factor Section
    private var cropFactorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Equivalent Focal Lengths")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(LensCalculatorManager.formats, id: \.name) { format in
                    if format.name != calculator.selectedFormat.name {
                        let equivalent = calculator.equivalentFocalLength(from: calculator.selectedFormat, to: format)
                        
                        HStack {
                            Text(format.commonName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("\(Int(equivalent))mm")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding()
.background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Frame Coverage Section
    private var frameCoverageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frame Coverage")
                .font(.headline)
            
            HStack {
                Text("Distance")
                Spacer()
                Text("\(String(format: "%.1f", calculator.subjectDistance))m")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }
            
            Slider(value: $calculator.subjectDistance, in: 0.5...50, step: 0.1)
                .accentColor(.green)
            
            let coverage = calculator.frameCoverage(for: calculator.selectedFormat)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Width")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(String(format: "%.2f", coverage.width))m")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Height")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(String(format: "%.2f", coverage.height))m")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
.background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Comparison Section
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Format Comparison")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $calculator.showComparison)
                    .labelsHidden()
            }
            
            if calculator.showComparison {
                Picker("Compare with", selection: $calculator.comparisonFormat) {
                    ForEach(LensCalculatorManager.formats, id: \.name) { format in
                        if format.name != calculator.selectedFormat.name {
                            Text(format.commonName).tag(format)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                VStack(spacing: 12) {
                    comparisonRow(title: "Field of View (H)", 
                                primary: calculator.horizontalFOV(for: calculator.selectedFormat),
                                comparison: calculator.horizontalFOV(for: calculator.comparisonFormat))
                    
                    comparisonRow(title: "Frame Width", 
                                primary: calculator.frameCoverage(for: calculator.selectedFormat).width,
                                comparison: calculator.frameCoverage(for: calculator.comparisonFormat).width,
                                unit: "m")
                    
                    let equivalentFocal = calculator.equivalentFocalLength(from: calculator.selectedFormat, to: calculator.comparisonFormat)
                    
                    HStack {
                        Text("Equivalent Focal Length")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(Int(equivalentFocal))mm")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
.background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private func comparisonRow(title: String, primary: Double, comparison: Double, unit: String = "°") -> some View {
        HStack {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", primary))\(unit)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                
                Text("\(String(format: "%.1f", comparison))\(unit)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Preview
struct LensCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        LensCalculatorView()
    }
}
