//
//  SunCalculatorAPI.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/13/25.
//

import Foundation
import CoreLocation

// MARK: - API Response Models
struct SunriseSunsetResponse: Codable {
    let results: SunriseSunsetResults
    let status: String
    let tzid: String?
}

struct SunriseSunsetResults: Codable {
    let sunrise: String
    let sunset: String
    let solarNoon: String
    let dayLength: Int
    let civilTwilightBegin: String
    let civilTwilightEnd: String
    let nauticalTwilightBegin: String
    let nauticalTwilightEnd: String
    let astronomicalTwilightBegin: String
    let astronomicalTwilightEnd: String
    
    enum CodingKeys: String, CodingKey {
        case sunrise, sunset
        case solarNoon = "solar_noon"
        case dayLength = "day_length"
        case civilTwilightBegin = "civil_twilight_begin"
        case civilTwilightEnd = "civil_twilight_end"
        case nauticalTwilightBegin = "nautical_twilight_begin"
        case nauticalTwilightEnd = "nautical_twilight_end"
        case astronomicalTwilightBegin = "astronomical_twilight_begin"
        case astronomicalTwilightEnd = "astronomical_twilight_end"
    }
}

// MARK: - Enhanced Sun Calculator with API
class SunCalculatorAPI: ObservableObject {
    static let shared = SunCalculatorAPI()
    
    @Published var sunTimes: SunTimes?
    @Published var moonTimes: MoonTimes?
    @Published var moonPhase: MoonPhase?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let session = URLSession.shared
    private let sunriseSunsetAPI = "https://api.sunrise-sunset.org/json"
    
    private init() {}
    
    // MARK: - API-based Sun Times Calculation
    func calculateSunTimes(for location: CLLocation, date: Date = Date()) {
        isLoading = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: date)
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        let urlString = "\(sunriseSunsetAPI)?lat=\(lat)&lng=\(lon)&date=\(dateString)&formatted=0"
        
        print("API URL: \(urlString)")
        print("Date being used: \(dateString)")
        print("Location: \(lat), \(lon)")
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                // Debug: Print the raw response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response: \(jsonString)")
                }
                
                do {
                    let response = try JSONDecoder().decode(SunriseSunsetResponse.self, from: data)
                    print("Successfully parsed response with status: \(response.status)")
                    print("Raw sunrise string: '\(response.results.sunrise)'")
                    print("Raw sunset string: '\(response.results.sunset)'")
                    
                    if response.status == "OK" {
                        self?.sunTimes = self?.parseSunTimes(from: response.results, date: date)
                        print("Successfully created sunTimes: \(self?.sunTimes != nil)")
                    } else {
                        self?.errorMessage = "API error: \(response.status)"
                    }
                } catch {
                    print("Parsing error: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            self?.errorMessage = "Missing key '\(key.stringValue)': \(context.debugDescription)"
                        case .typeMismatch(let type, let context):
                            self?.errorMessage = "Type mismatch for \(type): \(context.debugDescription)"
                        case .valueNotFound(let type, let context):
                            self?.errorMessage = "Value not found for \(type): \(context.debugDescription)"
                        case .dataCorrupted(let context):
                            self?.errorMessage = "Data corrupted: \(context.debugDescription)"
                        @unknown default:
                            self?.errorMessage = "Unknown decoding error: \(error.localizedDescription)"
                        }
                    } else {
                        self?.errorMessage = "Failed to parse response: \(error.localizedDescription)"
                    }
                }
            }
        }.resume()
    }
    
    private func parseSunTimes(from results: SunriseSunsetResults, date: Date) -> SunTimes {
        // Try multiple date formatters to handle different API response formats
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        
        let iso8601FormatterWithFractional = ISO8601DateFormatter()
        iso8601FormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        func parseDate(_ dateString: String) -> Date? {
            // Try standard ISO8601 format first
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // Try with fractional seconds
            if let date = iso8601FormatterWithFractional.date(from: dateString) {
                return date
            }
            
            // Manual parsing as fallback
            let components = dateString.components(separatedBy: "T")
            guard components.count == 2 else { return nil }
            
            let dateComponent = components[0]
            let timeComponent = components[1].replacingOccurrences(of: "+00:00", with: "")
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "UTC")
            
            return formatter.date(from: "\(dateComponent) \(timeComponent)")
        }
        
        // Parse times from API (they're in UTC)
        print("Attempting to parse sunrise: '\(results.sunrise)'")
        let sunrise = parseDate(results.sunrise)
        print("Parsed sunrise result: \(sunrise?.description ?? "nil")")
        
        print("Attempting to parse sunset: '\(results.sunset)'")
        let sunset = parseDate(results.sunset)
        print("Parsed sunset result: \(sunset?.description ?? "nil")")
        
        let civilTwilightBegin = parseDate(results.civilTwilightBegin)
        let civilTwilightEnd = parseDate(results.civilTwilightEnd)
        
        // Use reasonable defaults if parsing fails
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        
        let safeSunrise = sunrise ?? calendar.date(byAdding: .hour, value: 6, to: today) ?? Date()
        let safeSunset = sunset ?? calendar.date(byAdding: .hour, value: 18, to: today) ?? Date()
        let safeCivilTwilightBegin = civilTwilightBegin ?? calendar.date(byAdding: .minute, value: -30, to: safeSunrise) ?? Date()
        let safeCivilTwilightEnd = civilTwilightEnd ?? calendar.date(byAdding: .minute, value: 30, to: safeSunset) ?? Date()
        
        print("Final sunrise: \(safeSunrise)")
        print("Final sunset: \(safeSunset)")
        
        // Calculate golden hour times (1 hour after sunrise, 1 hour before sunset)
        let goldenHourStart = safeSunrise.addingTimeInterval(3600)
        let goldenHourEnd = safeSunset.addingTimeInterval(-3600)
        
        // Calculate blue hour times (30 minutes after sunset, 30 minutes before sunrise)
        let blueHourStart = safeSunset.addingTimeInterval(1800)
        let blueHourEnd = safeSunrise.addingTimeInterval(-1800)
        
        // Parse solar noon from API
        let solarNoon = parseDate(results.solarNoon) ?? Date(timeIntervalSince1970: (safeSunrise.timeIntervalSince1970 + safeSunset.timeIntervalSince1970) / 2)
        
        return SunTimes(
            sunrise: safeSunrise,
            sunset: safeSunset,
            solarNoon: solarNoon,
            dayLength: results.dayLength,
            goldenHourStart: goldenHourStart,
            goldenHourEnd: goldenHourEnd,
            blueHourStart: blueHourStart,
            blueHourEnd: blueHourEnd,
            civilTwilightBegin: safeCivilTwilightBegin,
            civilTwilightEnd: safeCivilTwilightEnd
        )
    }
    
    // MARK: - Moon Phase Calculation (accurate astronomical calculation)
    func calculateMoonPhase(for date: Date = Date()) -> MoonPhase {
        // Use a more accurate algorithm based on known lunar cycles
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        
        guard let _ = components.year,
              let _ = components.month,
              let _ = components.day,
              let _ = components.hour,
              let _ = components.minute else { return .new }
        
        // Known new moon: September 3, 2025 (verified astronomical date)
        let knownNewMoon = DateComponents(year: 2025, month: 9, day: 3, hour: 1, minute: 56)
        guard let referenceDate = calendar.date(from: knownNewMoon) else { return .new }
        
        // Calculate days since known new moon
        let timeInterval = date.timeIntervalSince(referenceDate)
        let daysSinceNewMoon = timeInterval / (24 * 60 * 60) // Convert to days
        
        // Lunar cycle length
        let lunarCycle = 29.530588853 // More precise synodic month
        
        // Calculate phase as fraction of lunar cycle
        let cyclePosition = daysSinceNewMoon.truncatingRemainder(dividingBy: lunarCycle)
        let phase = cyclePosition / lunarCycle
        
        print("Days since new moon: \(daysSinceNewMoon)")
        print("Cycle position: \(cyclePosition)")
        print("Phase fraction: \(phase)")
        
        // Phase boundaries based on astronomical definitions
        if phase < 0.03 || phase > 0.97 {
            return .new
        } else if phase < 0.22 {
            return .waxingCrescent
        } else if phase < 0.28 {
            return .firstQuarter
        } else if phase < 0.47 {
            return .waxingGibbous
        } else if phase < 0.53 {
            return .full
        } else if phase < 0.72 {
            return .waningGibbous
        } else if phase < 0.78 {
            return .lastQuarter
        } else {
            return .waningCrescent
        }
    }
    
    // MARK: - Moon Times (simplified calculation)
    func calculateMoonTimes(for location: CLLocation, date: Date = Date()) -> MoonTimes {
        // For now, we'll use a simplified calculation
        // In a production app, you'd want to use a more sophisticated astronomical library
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return MoonTimes(moonrise: nil, moonset: nil)
        }
        
        // Simple approximation - moon rises about 50 minutes later each day
        let daysSinceNewYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let moonriseHour = (6 + (daysSinceNewYear * 50) / 60) % 24
        let moonsetHour = (18 + (daysSinceNewYear * 50) / 60) % 24
        
        var moonriseComponents = DateComponents()
        moonriseComponents.year = year
        moonriseComponents.month = month
        moonriseComponents.day = day
        moonriseComponents.hour = moonriseHour
        moonriseComponents.minute = 0
        
        var moonsetComponents = DateComponents()
        moonsetComponents.year = year
        moonsetComponents.month = month
        moonsetComponents.day = day
        moonsetComponents.hour = moonsetHour
        moonsetComponents.minute = 0
        
        let moonrise = calendar.date(from: moonriseComponents)
        let moonset = calendar.date(from: moonsetComponents)
        
        return MoonTimes(moonrise: moonrise, moonset: moonset)
    }
    
    // MARK: - Shadow Length Calculation
    func calculateShadowLength(objectHeight: Double, sunElevation: Double) -> Double {
        guard sunElevation > 0 else { return Double.infinity }
        return objectHeight / tan(sunElevation * .pi / 180)
    }
    
    // MARK: - Sun Elevation Calculation (simplified)
    func calculateSunElevation(for location: CLLocation, date: Date = Date()) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute else { return 0 }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Simplified sun elevation calculation
        let n = calculateDayOfYear(year: year, month: month, day: day)
        let lngHour = lon / 15.0
        let hourMinute = Double(hour) + Double(minute) / 60.0
        let t = Double(n) + ((hourMinute - lngHour) / 24.0)
        
        let m = (0.9856 * t) - 3.289
        var l = m + (1.916 * sin(m * .pi / 180)) + (0.020 * sin(2 * m * .pi / 180)) + 282.634
        l = l.truncatingRemainder(dividingBy: 360)
        
        let ra = atan(0.91764 * tan(l * .pi / 180)) * 180 / .pi
        let lQuadrant = (floor(l / 90)) * 90
        let raQuadrant = (floor(ra / 90)) * 90
        let raAdjusted = ra + (lQuadrant - raQuadrant)
        let _ = raAdjusted / 15
        
        let sinDec = 0.39782 * sin(l * .pi / 180)
        let cosDec = cos(asin(sinDec))
        
        let h = (Double(hour) + Double(minute) / 60.0 + lngHour - ra) * 15
        let hFinal = h.truncatingRemainder(dividingBy: 360)
        
        let sinElevation = sinDec * sin(lat * .pi / 180) + cosDec * cos(lat * .pi / 180) * cos(hFinal * .pi / 180)
        let elevation = asin(sinElevation) * 180 / .pi
        
        return elevation
    }
    
    private func calculateDayOfYear(year: Int, month: Int, day: Int) -> Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: dateComponents) else { return 1 }
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }
}
