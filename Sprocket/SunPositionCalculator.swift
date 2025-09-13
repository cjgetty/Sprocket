import Foundation
import CoreLocation

// MARK: - Sun Position Data Models
struct SunPosition {
    let azimuth: Double      // Degrees from North (0° = North, 90° = East, 180° = South, 270° = West)
    let elevation: Double    // Degrees above horizon (negative = below horizon)
    let time: Date
    let eventType: SunEventType?
    
    var isKeyEvent: Bool {
        eventType != nil
    }
    
    var compassDirection: String {
        switch azimuth {
        case 0..<22.5, 337.5...360: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default: return "N"
        }
    }
}

enum SunEventType {
    case sunrise
    case sunset
    case solarNoon
    case goldenHour
    case blueHour
    case civilTwilight
    case nauticalTwilight
    case astronomicalTwilight
}

// MARK: - Sun Position Calculator
class SunPositionCalculator {
    
    /// Calculate sun position for a specific location and time
    static func calculateSunPosition(for location: CLLocation, at time: Date) -> SunPosition {
        let coordinates = location.coordinate
        let julianDay = julianDayNumber(for: time)
        
        // Calculate sun's position using astronomical algorithms
        let (azimuth, elevation) = calculateSolarPosition(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            julianDay: julianDay
        )
        
        // Determine if this is a key event time
        let eventType = determineEventType(elevation: elevation, time: time)
        
        return SunPosition(
            azimuth: azimuth,
            elevation: elevation,
            time: time,
            eventType: eventType
        )
    }
    
    /// Calculate sun path for entire day with hourly intervals
    static func calculateDailySunPath(for location: CLLocation, date: Date) async -> [SunPosition] {
        return await withTaskGroup(of: SunPosition.self) { group in
            var positions: [SunPosition] = []
            
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            
            // Calculate positions every 15 minutes for smooth arc
            for minute in stride(from: 0, to: 1440, by: 15) {
                group.addTask {
                    let time = calendar.date(byAdding: .minute, value: minute, to: startOfDay)!
                    return calculateSunPosition(for: location, at: time)
                }
            }
            
            for await position in group {
                positions.append(position)
            }
            
            return positions.sorted { $0.time < $1.time }
        }
    }
    
    // MARK: - Private Calculation Methods
    
    private static func julianDayNumber(for date: Date) -> Double {
        let timeInterval = date.timeIntervalSince1970
        let julianDay = (timeInterval / 86400.0) + 2440587.5
        return julianDay
    }
    
    private static func calculateSolarPosition(latitude: Double, longitude: Double, julianDay: Double) -> (azimuth: Double, elevation: Double) {
        // Convert to radians
        let lat = latitude * .pi / 180.0
        let lon = longitude * .pi / 180.0
        
        // Calculate number of days since J2000.0
        let n = julianDay - 2451545.0
        
        // Calculate mean solar longitude
        let L = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        
        // Calculate mean anomaly
        let g = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360.0) * .pi / 180.0
        
        // Calculate ecliptic longitude
        let lambda = L + (1.915 * sin(g) + 0.020 * sin(2 * g)) * .pi / 180.0
        
        // Calculate obliquity of ecliptic
        let epsilon = (23.439 - 0.0000004 * n) * .pi / 180.0
        
        // Calculate right ascension and declination
        let alpha = atan2(cos(epsilon) * sin(lambda), cos(lambda))
        let delta = asin(sin(epsilon) * sin(lambda))
        
        // Calculate Greenwich Mean Sidereal Time
        let GMST = (6.697375 + 0.0657098242 * n + (julianDay - floor(julianDay) - 0.5) * 24.0).truncatingRemainder(dividingBy: 24.0)
        let GMSTRad = GMST * 15.0 * .pi / 180.0
        
        // Calculate Local Sidereal Time
        let LST = GMSTRad + lon
        
        // Calculate hour angle
        let H = LST - alpha
        
        // Calculate elevation (altitude)
        let elevation = asin(sin(lat) * sin(delta) + cos(lat) * cos(delta) * cos(H))
        
        // Calculate azimuth
        let azimuthRad = atan2(-sin(H), tan(delta) * cos(lat) - sin(lat) * cos(H))
        let azimuth = (azimuthRad * 180.0 / .pi + 180.0).truncatingRemainder(dividingBy: 360.0)
        
        return (azimuth: azimuth, elevation: elevation * 180.0 / .pi)
    }
    
    private static func determineEventType(elevation: Double, time: Date) -> SunEventType? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        let timeInMinutes = hour * 60 + minute
        
        // Approximate event detection based on elevation and time
        if elevation > -0.833 && elevation < 0.833 {
            if timeInMinutes < 720 { // Before noon
                return .sunrise
            } else {
                return .sunset
            }
        }
        
        if elevation > 0 && timeInMinutes >= 720 - 30 && timeInMinutes <= 720 + 30 {
            return .solarNoon
        }
        
        // Golden hour: sun elevation between -4° and 6°
        if elevation > -4 && elevation < 6 {
            return .goldenHour
        }
        
        // Blue hour: sun elevation between -6° and -4°
        if elevation > -6 && elevation < -4 {
            return .blueHour
        }
        
        // Civil twilight: sun elevation between -6° and 0°
        if elevation > -6 && elevation < 0 {
            return .civilTwilight
        }
        
        // Nautical twilight: sun elevation between -12° and -6°
        if elevation > -12 && elevation < -6 {
            return .nauticalTwilight
        }
        
        // Astronomical twilight: sun elevation between -18° and -12°
        if elevation > -18 && elevation < -12 {
            return .astronomicalTwilight
        }
        
        return nil
    }
}
