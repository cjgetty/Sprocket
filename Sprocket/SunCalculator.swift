//
//  SunCalculator.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/13/25.
//

import Foundation
import CoreLocation

// MARK: - Sun Calculator
class SunCalculator: ObservableObject {
    static let shared = SunCalculator()
    
    @Published var currentLocation: CLLocation?
    @Published var selectedDate = Date()
    @Published var sunTimes: SunTimes?
    @Published var moonTimes: MoonTimes?
    @Published var moonPhase: MoonPhase?
    
    private init() {}
    
    // MARK: - Sun Times Calculation
    func calculateSunTimes(for location: CLLocation, date: Date = Date()) -> SunTimes? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return nil }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Calculate sunrise and sunset
        guard let sunrise = calculateSunrise(lat: lat, lon: lon, year: year, month: month, day: day),
              let sunset = calculateSunset(lat: lat, lon: lon, year: year, month: month, day: day) else { return nil }
        
        // Calculate golden hour times (1 hour before sunset, 1 hour after sunrise)
        let goldenHourStart = sunrise.addingTimeInterval(3600) // 1 hour after sunrise
        let goldenHourEnd = sunset.addingTimeInterval(-3600)   // 1 hour before sunset
        
        // Calculate blue hour times (30 minutes before sunrise, 30 minutes after sunset)
        let blueHourStart = sunset.addingTimeInterval(1800)    // 30 minutes after sunset
        let blueHourEnd = sunrise.addingTimeInterval(-1800)    // 30 minutes before sunrise
        
        // Calculate civil twilight (sun 6° below horizon)
        let civilTwilightStart = calculateCivilTwilight(lat: lat, lon: lon, year: year, month: month, day: day, isSunrise: false) ?? sunset.addingTimeInterval(1800)
        let civilTwilightEnd = calculateCivilTwilight(lat: lat, lon: lon, year: year, month: month, day: day, isSunrise: true) ?? sunrise.addingTimeInterval(-1800)
        
        // Calculate solar noon (midpoint between sunrise and sunset)
        let solarNoon = Date(timeIntervalSince1970: (sunrise.timeIntervalSince1970 + sunset.timeIntervalSince1970) / 2)
        
        // Calculate day length in seconds
        let dayLength = Int(sunset.timeIntervalSince(sunrise))
        
        return SunTimes(
            sunrise: sunrise,
            sunset: sunset,
            solarNoon: solarNoon,
            dayLength: dayLength,
            goldenHourStart: goldenHourStart,
            goldenHourEnd: goldenHourEnd,
            blueHourStart: blueHourStart,
            blueHourEnd: blueHourEnd,
            civilTwilightBegin: civilTwilightEnd,
            civilTwilightEnd: civilTwilightStart
        )
    }
    
    // MARK: - Moon Times Calculation
    func calculateMoonTimes(for location: CLLocation, date: Date = Date()) -> MoonTimes? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return nil }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        let moonrise = calculateMoonrise(lat: lat, lon: lon, year: year, month: month, day: day)
        let moonset = calculateMoonset(lat: lat, lon: lon, year: year, month: month, day: day)
        
        return MoonTimes(moonrise: moonrise, moonset: moonset)
    }
    
    // MARK: - Moon Phase Calculation
    func calculateMoonPhase(for date: Date = Date()) -> MoonPhase {
        // Simple moon phase calculation based on days since known new moon
        let knownNewMoon = DateComponents(year: 2000, month: 1, day: 6)
        let calendar = Calendar.current
        guard let referenceDate = calendar.date(from: knownNewMoon) else { return .new }
        
        let daysSinceNewMoon = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
        let moonCycle = 29.53059 // Average lunar cycle in days
        let phase = Double(daysSinceNewMoon % Int(moonCycle)) / moonCycle
        
        if phase < 0.0625 { return .new }
        else if phase < 0.1875 { return .waxingCrescent }
        else if phase < 0.3125 { return .firstQuarter }
        else if phase < 0.4375 { return .waxingGibbous }
        else if phase < 0.5625 { return .full }
        else if phase < 0.6875 { return .waningGibbous }
        else if phase < 0.8125 { return .lastQuarter }
        else { return .waningCrescent }
    }
    
    // MARK: - Shadow Length Calculator
    func calculateShadowLength(objectHeight: Double, sunElevation: Double) -> Double {
        guard sunElevation > 0 && sunElevation < 90 else { return 0 }
        let elevationRadians = sunElevation * .pi / 180
        return objectHeight / tan(elevationRadians)
    }
    
    // MARK: - Sun Elevation Calculator
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
        
        return calculateSunElevation(lat: lat, lon: lon, year: year, month: month, day: day, hour: hour, minute: minute)
    }
    
    // MARK: - Private Calculation Methods
    private func calculateSunrise(lat: Double, lon: Double, year: Int, month: Int, day: Int) -> Date? {
        return calculateSunTime(lat: lat, lon: lon, year: year, month: month, day: day, isSunrise: true)
    }
    
    private func calculateSunset(lat: Double, lon: Double, year: Int, month: Int, day: Int) -> Date? {
        return calculateSunTime(lat: lat, lon: lon, year: year, month: month, day: day, isSunrise: false)
    }
    
    private func calculateSunTime(lat: Double, lon: Double, year: Int, month: Int, day: Int, isSunrise: Bool) -> Date? {
        let n = calculateDayOfYear(year: year, month: month, day: day)
        let lngHour = lon / 15.0
        let t: Double
        if isSunrise {
            t = Double(n) + ((6 - lngHour) / 24)
        } else {
            t = Double(n) + ((18 - lngHour) / 24)
        }
        
        let m = (0.9856 * t) - 3.289
        var l = m + (1.916 * sin(m * .pi / 180)) + (0.020 * sin(2 * m * .pi / 180)) + 282.634
        l = l.truncatingRemainder(dividingBy: 360)
        
        let ra = atan(0.91764 * tan(l * .pi / 180)) * 180 / .pi
        let lQuadrant = (floor(l / 90)) * 90
        let raQuadrant = (floor(ra / 90)) * 90
        let raAdjusted = ra + (lQuadrant - raQuadrant)
        let raFinal = raAdjusted / 15
        
        let sinDec = 0.39782 * sin(l * .pi / 180)
        let cosDec = cos(asin(sinDec))
        
        let cosH = (cos(90 * .pi / 180) - (sinDec * sin(lat * .pi / 180))) / (cosDec * cos(lat * .pi / 180))
        
        guard cosH >= -1 && cosH <= 1 else {
            return nil // Sun never rises or sets
        }
        
        let h = isSunrise ? 360 - acos(cosH) * 180 / .pi : acos(cosH) * 180 / .pi
        let hFinal = h / 15
        
        let tFinal = hFinal + raFinal - (0.06571 * t) - 6.622
        let ut = tFinal - lngHour
        let utFinal = ut.truncatingRemainder(dividingBy: 24)
        
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = Int(utFinal)
        components.minute = Int((utFinal - floor(utFinal)) * 60)
        
        return calendar.date(from: components)
    }
    
    private func calculateCivilTwilight(lat: Double, lon: Double, year: Int, month: Int, day: Int, isSunrise: Bool) -> Date? {
        // Similar to sun calculation but with sun 6° below horizon
        return calculateSunTimeWithElevation(lat: lat, lon: lon, year: year, month: month, day: day, isSunrise: isSunrise, elevation: -6)
    }
    
    private func calculateSunTimeWithElevation(lat: Double, lon: Double, year: Int, month: Int, day: Int, isSunrise: Bool, elevation: Double) -> Date? {
        // Simplified calculation for civil twilight
        let sunTime = calculateSunTime(lat: lat, lon: lon, year: year, month: month, day: day, isSunrise: isSunrise)
        let offset = isSunrise ? -30 : 30 // Approximate 30 minutes offset for civil twilight
        return sunTime?.addingTimeInterval(TimeInterval(offset * 60))
    }
    
    private func calculateMoonrise(lat: Double, lon: Double, year: Int, month: Int, day: Int) -> Date? {
        // Simplified moonrise calculation
        return calculateMoonTime(lat: lat, lon: lon, year: year, month: month, day: day, isMoonrise: true)
    }
    
    private func calculateMoonset(lat: Double, lon: Double, year: Int, month: Int, day: Int) -> Date? {
        // Simplified moonset calculation
        return calculateMoonTime(lat: lat, lon: lon, year: year, month: month, day: day, isMoonrise: false)
    }
    
    private func calculateMoonTime(lat: Double, lon: Double, year: Int, month: Int, day: Int, isMoonrise: Bool) -> Date? {
        // Very simplified moon calculation - in a real app, you'd use a proper astronomical library
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = isMoonrise ? 6 : 18 // Placeholder times
        components.minute = 0
        
        return calendar.date(from: components)
    }
    
    private func calculateSunElevation(lat: Double, lon: Double, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Double {
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
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }
}

// MARK: - Data Models
struct SunTimes {
    let sunrise: Date
    let sunset: Date
    let solarNoon: Date
    let dayLength: Int
    let goldenHourStart: Date
    let goldenHourEnd: Date
    let blueHourStart: Date
    let blueHourEnd: Date
    let civilTwilightBegin: Date
    let civilTwilightEnd: Date
}

struct MoonTimes {
    let moonrise: Date?
    let moonset: Date?
}

enum MoonPhase: String, CaseIterable {
    case new = "New Moon"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case full = "Full Moon"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"
    
    var icon: String {
        switch self {
        case .new: return "moon"
        case .waxingCrescent: return "moon.circle"
        case .firstQuarter: return "moon.lefthalf.fill"
        case .waxingGibbous: return "moon.circle.fill"
        case .full: return "moon.fill"
        case .waningGibbous: return "moon.circle.fill"
        case .lastQuarter: return "moon.righthalf.fill"
        case .waningCrescent: return "moon.circle"
        }
    }
}
