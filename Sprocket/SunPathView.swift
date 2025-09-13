import SwiftUI
import CoreLocation
import Foundation

struct SunPathView: View {
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var sunAPI = SunCalculatorAPI.shared
    
    @State private var selectedTime = Date()
    @State private var currentSunPosition: SunPosition?
    @State private var sunPathPoints: [SunPosition] = []
    @State private var isLoading = false
    
    private let date: Date
    
    init(date: Date = Date()) {
        self.date = date
        self._selectedTime = State(initialValue: date)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Sun Path Visualization
            ZStack {
                // Background sky gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(skyGradient)
                    .frame(height: 280)
                
                // Sun path arc and indicators
                SunPathArcView(
                    sunPathPoints: sunPathPoints,
                    currentPosition: currentSunPosition,
                    selectedTime: selectedTime
                )
                .frame(height: 280)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .padding(.horizontal, 16)
            
            // Time scrubber section
            VStack(spacing: 16) {
                HStack {
                    Text("Time")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text(DateFormatter.timeFormatter.string(from: selectedTime))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                TimeSlider(
                    selectedTime: $selectedTime,
                    date: date,
                    sunPathPoints: sunPathPoints
                )
            }
            .padding(.horizontal, 16)
            
            // Sun position details
            if let position = currentSunPosition {
                SunPositionDetailsView(position: position, time: selectedTime)
            }
        }
        .padding(.bottom, 16)
        .onAppear {
            calculateSunPath()
        }
        .onChange(of: locationManager.location) { _, _ in
            calculateSunPath()
        }
        .onChange(of: selectedTime) { _, newTime in
            updateCurrentSunPosition(for: newTime)
        }
    }
    
    private var skyGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.3),
                Color.orange.opacity(0.1),
                Color.yellow.opacity(0.05)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func calculateSunPath() {
        guard let location = locationManager.location else { return }
        
        isLoading = true
        
        Task {
            let positions = await SunPositionCalculator.calculateDailySunPath(
                for: location,
                date: date
            )
            
            await MainActor.run {
                self.sunPathPoints = positions
                self.isLoading = false
                updateCurrentSunPosition(for: selectedTime)
            }
        }
    }
    
    private func updateCurrentSunPosition(for time: Date) {
        guard let location = locationManager.location else { return }
        
        let position = SunPositionCalculator.calculateSunPosition(
            for: location,
            at: time
        )
        
        currentSunPosition = position
    }
}

// MARK: - Sun Path Arc View
struct SunPathArcView: View {
    let sunPathPoints: [SunPosition]
    let currentPosition: SunPosition?
    let selectedTime: Date
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Draw sun path arc
                if !sunPathPoints.isEmpty {
                    Path { path in
                        let points = sunPathPoints.compactMap { position -> CGPoint? in
                            guard position.elevation > 0 else { return nil }
                            return convertSunPositionToPoint(
                                position: position,
                                in: CGSize(width: width, height: height)
                            )
                        }
                        
                        if let firstPoint = points.first {
                            path.move(to: firstPoint)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                }
                
                // Key sun event markers
                ForEach(Array(sunPathPoints.enumerated()), id: \.offset) { index, position in
                    if isKeyTimeMarker(position) {
                        Circle()
                            .fill(colorForSunEvent(position))
                            .frame(width: 8, height: 8)
                            .position(
                                convertSunPositionToPoint(
                                    position: position,
                                    in: CGSize(width: width, height: height)
                                ) ?? .zero
                            )
                    }
                }
                
                // Current sun position indicator
                if let position = currentPosition,
                   position.elevation > 0,
                   let point = convertSunPositionToPoint(
                    position: position,
                    in: CGSize(width: width, height: height)
                   ) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                        )
                        .position(point)
                        .shadow(color: .yellow.opacity(0.6), radius: 8)
                }
                
                // Horizon line
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(height: 1)
                    .position(x: width / 2, y: height - 20)
                
                // Compass directions
                HStack {
                    Text("E")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("S")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("W")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .position(x: width / 2, y: height - 10)
            }
        }
        .padding()
    }
    
    private func convertSunPositionToPoint(position: SunPosition, in size: CGSize) -> CGPoint? {
        guard position.elevation > 0 else { return nil }
        
        // Convert azimuth (0° = North, 90° = East) to our coordinate system
        // We want East (90°) on the left, South (180°) in center, West (270°) on right
        let normalizedAzimuth = (position.azimuth + 90).truncatingRemainder(dividingBy: 360)
        let x = size.width * (1 - normalizedAzimuth / 180) // Flip for correct orientation
        
        // Convert elevation to y position (higher elevation = higher on screen)
        let maxElevation: Double = 90
        let y = size.height - 20 - (position.elevation / maxElevation) * (size.height - 40)
        
        return CGPoint(x: max(0, min(size.width, x)), y: max(20, min(size.height - 20, y)))
    }
    
    private func isKeyTimeMarker(_ position: SunPosition) -> Bool {
        // Mark sunrise, sunset, solar noon, and other key times
        return position.isKeyEvent
    }
    
    private func colorForSunEvent(_ position: SunPosition) -> Color {
        switch position.eventType {
        case .sunrise, .sunset:
            return .orange
        case .solarNoon:
            return .yellow
        case .goldenHour:
            return .orange.opacity(0.7)
        case .blueHour:
            return .blue.opacity(0.7)
        default:
            return .gray
        }
    }
}

// MARK: - Time Slider
struct TimeSlider: View {
    @Binding var selectedTime: Date
    let date: Date
    let sunPathPoints: [SunPosition]
    
    private var timeRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return startOfDay...endOfDay
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { selectedTime.timeIntervalSince1970 },
                    set: { selectedTime = Date(timeIntervalSince1970: $0) }
                ),
                in: timeRange.lowerBound.timeIntervalSince1970...timeRange.upperBound.timeIntervalSince1970,
                step: 300 // 5-minute intervals
            )
            .accentColor(.orange)
            
            HStack {
                Text("12:00 AM")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("12:00 PM")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("11:59 PM")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Sun Position Details
struct SunPositionDetailsView: View {
    let position: SunPosition
    let time: Date
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Sun Position")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            
            HStack(spacing: 0) {
                // Azimuth
                VStack(alignment: .leading, spacing: 6) {
                    Text("Azimuth")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(Int(position.azimuth))°")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Elevation
                VStack(alignment: .leading, spacing: 6) {
                    Text("Elevation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(Int(position.elevation))°")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Direction
                VStack(alignment: .leading, spacing: 6) {
                    Text("Direction")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(position.compassDirection)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if position.elevation <= 0 {
                Text("Sun is below horizon")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    SunPathView()
}
