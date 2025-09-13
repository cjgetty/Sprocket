//
//  SunCalculatorView.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/13/25.
//

import SwiftUI
import CoreLocation

struct SunCalculatorView: View {
    @StateObject private var sunCalculator = SunCalculatorAPI.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var selectedDate = Date()
    @State private var objectHeight: Double = 1.8 // Default person height in meters
    @State private var shadowLength: Double = 0
    @State private var showingDatePicker = false
    @State private var showingShadowCalculator = false
    @State private var showingLocationSearch = false
    @State private var searchText = ""
    @State private var searchResults: [CLPlacemark] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Location and Date Header
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.accentColor)
                            
                            Button(action: {
                                if locationManager.location == nil {
                                    locationManager.requestLocationPermission()
                                    locationManager.getCurrentLocation()
                                } else {
                                    showingLocationSearch = true
                                }
                            }) {
                                Text(displayLocationText)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(locationManager.location != nil ? .primary : .accentColor)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if locationManager.location == nil {
                                Button(action: {
                                    locationManager.requestLocationPermission()
                                    locationManager.getCurrentLocation()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 16, weight: .medium))
                                }
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.accentColor)
                            Button(action: { showingDatePicker = true }) {
                                Text(selectedDate, style: .date)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Loading State
                    if sunCalculator.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Calculating sun times...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Error State
                    if let errorMessage = sunCalculator.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            Text("Unable to calculate sun times")
                                .font(.system(size: 16, weight: .semibold))
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Sun Times Section
                    if let sunTimes = sunCalculator.sunTimes {
                        SunTimesSection(sunTimes: sunTimes)
                    }
                    
                    // Moon Information Section
                    if let moonTimes = sunCalculator.moonTimes {
                        MoonSection(moonTimes: moonTimes, moonPhase: sunCalculator.moonPhase)
                    }
                    
                    // Shadow Calculator Section
                    ShadowCalculatorSection(
                        objectHeight: $objectHeight,
                        shadowLength: $shadowLength,
                        sunElevation: sunCalculator.calculateSunElevation(for: locationManager.location ?? CLLocation(latitude: 0, longitude: 0), date: selectedDate)
                    )
                    
                    // Interactive Sun Path Section
                    SunPathSection(date: selectedDate)
                }
                .padding()
            }
            .navigationTitle("Sun Calculator")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Request location permission and start location services
                locationManager.requestLocationPermission()
                locationManager.getCurrentLocation()
                updateCalculations()
            }
            .onChange(of: selectedDate) {
                updateCalculations()
            }
            .onReceive(locationManager.$location) { _ in
                updateCalculations()
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchView(
                    searchText: $searchText,
                    searchResults: $searchResults,
                    isSearching: $isSearching,
                    locationManager: locationManager,
                    onLocationSelected: { placemark in
                        locationManager.setLocation(from: placemark)
                        updateCalculations()
                        showingLocationSearch = false
                    }
                )
            }
        }
    }
    
    private var displayLocationText: String {
        return locationManager.displayLocationText
    }
    
    private func updateCalculations() {
        guard let location = locationManager.location else { return }
        
        // Use API-based calculations for accurate sun times
        sunCalculator.calculateSunTimes(for: location, date: selectedDate)
        sunCalculator.moonTimes = sunCalculator.calculateMoonTimes(for: location, date: selectedDate)
        sunCalculator.moonPhase = sunCalculator.calculateMoonPhase(for: selectedDate)
        
        // Update shadow length
        let elevation = sunCalculator.calculateSunElevation(for: location, date: selectedDate)
        shadowLength = sunCalculator.calculateShadowLength(objectHeight: objectHeight, sunElevation: elevation)
    }
}

// MARK: - Sun Path Section
struct SunPathSection: View {
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sun.max.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                
                Text("Sun Path Visualization")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Embed the Sun Path View
            SunPathView(date: date)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Sun Times Section
struct SunTimesSection: View {
    let sunTimes: SunTimes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                
                Text("Sun Times")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                TimeRow(icon: "sunrise.fill", title: "Sunrise", time: sunTimes.sunrise, color: .orange)
                TimeRow(icon: "sun.max.fill", title: "Solar Noon", time: sunTimes.solarNoon, color: .yellow)
                TimeRow(icon: "sunset.fill", title: "Sunset", time: sunTimes.sunset, color: .red)
                
                Divider()
                
                // Golden Hour
                TimeRow(icon: "camera.fill", title: "Golden Hour Begin", time: sunTimes.goldenHourStart, color: .orange)
                TimeRow(icon: "camera.fill", title: "Golden Hour End", time: sunTimes.goldenHourEnd, color: .orange)
                
                // Blue Hour
                TimeRow(icon: "moon.stars.fill", title: "Blue Hour Begin", time: sunTimes.blueHourStart, color: .blue)
                TimeRow(icon: "moon.stars.fill", title: "Blue Hour End", time: sunTimes.blueHourEnd, color: .blue)
                
                Divider()
                
                TimeRow(icon: "moon.fill", title: "Civil Twilight Begin", time: sunTimes.civilTwilightBegin, color: .indigo)
                TimeRow(icon: "moon.fill", title: "Civil Twilight End", time: sunTimes.civilTwilightEnd, color: .purple)
                
                Divider()
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                        .frame(width: 20)
                    
                    Text("Day Length")
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Text(formatDayLength(sunTimes.dayLength))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDayLength(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Moon Section
struct MoonSection: View {
    let moonTimes: MoonTimes
    let moonPhase: MoonPhase?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 20))
                
                Text("Moon Information")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                if let moonPhase = moonPhase {
                    HStack {
                        Image(systemName: moonPhase.icon)
                            .foregroundColor(.purple)
                            .font(.system(size: 16))
                            .frame(width: 20)
                        Text(moonPhase.rawValue)
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                }
                
                if let moonrise = moonTimes.moonrise {
                    TimeRow(icon: "moon.fill", title: "Moonrise", time: moonrise, color: .purple)
                }
                
                if let moonset = moonTimes.moonset {
                    TimeRow(icon: "moon.fill", title: "Moonset", time: moonset, color: .purple)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Shadow Calculator Section
struct ShadowCalculatorSection: View {
    @Binding var objectHeight: Double
    @Binding var shadowLength: Double
    let sunElevation: Double
    
    private func updateShadowLength(_ height: Double) {
        let sunCalculator = SunCalculator.shared
        shadowLength = sunCalculator.calculateShadowLength(objectHeight: height, sunElevation: sunElevation)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                Text("Shadow Calculator")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Object Height (meters)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Slider(value: $objectHeight, in: 0.1...10.0, step: 0.1)
                            .onChange(of: objectHeight) { _, newHeight in
                                updateShadowLength(newHeight)
                            }
                        Text("\(objectHeight, specifier: "%.1f")m")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 50)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Sun Elevation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text("\(sunElevation, specifier: "%.1f")°")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shadow Length")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "ruler")
                            .foregroundColor(.blue)
                        Text("\(shadowLength, specifier: "%.1f")m")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Time Row Component
struct TimeRow: View {
    let icon: String
    let title: String
    let time: Date
    let color: Color
    
    @ObservedObject private var locationManager = LocationManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Text(formattedTime)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        // Use the location's timezone if available, otherwise use local timezone
        if let locationTimeZone = locationManager.locationTimeZone {
            formatter.timeZone = locationTimeZone
        }
        
        return formatter.string(from: time)
    }
}

#Preview {
    SunCalculatorView()
}
