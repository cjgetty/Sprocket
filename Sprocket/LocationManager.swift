//
//  LocationManager.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/12/25.
//

import Foundation
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var locationName: String?
    @Published var fullLocationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var recentSearches: [CLPlacemark] = []
    @Published var isUsingCurrentLocation: Bool = true
    @Published var locationTimeZone: TimeZone?
    
    private let maxRecentSearches = 5
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        loadPersistedLocation()
        loadRecentSearches()
        loadTimeZoneFromUserDefaults()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
        
        // Get location name
        if let location = locations.first {
            getLocationName(from: location)
            saveLocationToUserDefaults(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
    
    private func getLocationName(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks: [CLPlacemark]?, error: Error?) in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    // Create short location name (City, State)
                    if let city = placemark.locality, let state = placemark.administrativeArea {
                        self?.locationName = "\(city), \(state)"
                    } else if let name = placemark.name {
                        self?.locationName = name
                    }
                    
                    // Create full location name (City, State, Country)
                    var fullNameComponents: [String] = []
                    
                    if let city = placemark.locality {
                        fullNameComponents.append(city)
                    }
                    if let state = placemark.administrativeArea {
                        fullNameComponents.append(state)
                    }
                    if let country = placemark.country {
                        fullNameComponents.append(country)
                    }
                    
                    if !fullNameComponents.isEmpty {
                        self?.fullLocationName = fullNameComponents.joined(separator: ", ")
                    } else if let name = placemark.name {
                        self?.fullLocationName = name
                    }
                    
                    // Save location names to UserDefaults
                    self?.saveLocationNamesToUserDefaults()
                    
                    // Get timezone for the location
                    self?.getTimeZone(for: location)
                }
            }
        }
    }
    
    // MARK: - Location Search
    
    func searchLocation(query: String, completion: @escaping ([CLPlacemark]) -> Void) {
        // Cancel any previous search
        currentSearchTask?.cancel()
        currentGeocoderTask?.cancelGeocode()
        
        // Use dual search strategy: MapKit + CLGeocoder for comprehensive results
        performDualSearch(query: query, completion: completion)
    }
    
    private func performDualSearch(query: String, completion: @escaping ([CLPlacemark]) -> Void) {
        let group = DispatchGroup()
        var mapKitResults: [CLPlacemark] = []
        var geocoderResults: [CLPlacemark] = []
        
        // MapKit Search (better for cities, POIs, partial matches)
        group.enter()
        performMapKitSearch(query: query) { results in
            mapKitResults = results
            group.leave()
        }
        
        // CLGeocoder Search (better for specific addresses)
        group.enter()
        performGeocoderSearch(query: query) { results in
            geocoderResults = results
            group.leave()
        }
        
        group.notify(queue: .main) {
            // Combine and deduplicate results
            let combinedResults = self.combineAndDeduplicateResults(
                mapKitResults: mapKitResults,
                geocoderResults: geocoderResults,
                query: query
            )
            completion(combinedResults)
        }
    }
    
    private func performMapKitSearch(query: String, completion: @escaping ([CLPlacemark]) -> Void) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.resultTypes = [.address, .pointOfInterest]
        
        // Expand search region for better global coverage
        if let currentLocation = location {
            let region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                latitudinalMeters: 500000, // 500km radius for better coverage
                longitudinalMeters: 500000
            )
            searchRequest.region = region
        } else {
            // Default to worldwide search if no current location
            searchRequest.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                latitudinalMeters: 20000000, // Global search
                longitudinalMeters: 20000000
            )
        }
        
        let search = MKLocalSearch(request: searchRequest)
        currentSearchTask = search
        
        search.start { response, error in
            self.currentSearchTask = nil
            
            if let error = error as? MKError, error.code == .loadingThrottled {
                completion([])
                return
            }
            
            guard let response = response else {
                completion([])
                return
            }
            
            let placemarks = response.mapItems.compactMap { $0.placemark }
            completion(placemarks)
        }
    }
    
    private func performGeocoderSearch(query: String, completion: @escaping ([CLPlacemark]) -> Void) {
        let geocoder = CLGeocoder()
        currentGeocoderTask = geocoder
        
        geocoder.geocodeAddressString(query) { placemarks, error in
            self.currentGeocoderTask = nil
            
            if let error = error as? CLError, error.code == .geocodeCanceled {
                completion([])
                return
            }
            
            completion(placemarks ?? [])
        }
    }
    
    private func combineAndDeduplicateResults(
        mapKitResults: [CLPlacemark],
        geocoderResults: [CLPlacemark],
        query: String
    ) -> [CLPlacemark] {
        var allResults: [CLPlacemark] = []
        
        // Add MapKit results first (usually better for partial matches)
        allResults.append(contentsOf: mapKitResults)
        
        // Add geocoder results that aren't duplicates
        for geocoderResult in geocoderResults {
            let isDuplicate = allResults.contains { existingResult in
                return arePlacemarksEqual(existingResult, geocoderResult)
            }
            
            if !isDuplicate {
                allResults.append(geocoderResult)
            }
        }
        
        // Sort by relevance and limit results
        let sortedResults = sortPlacemarksByRelevance(allResults, query: query)
        return Array(sortedResults.prefix(20)) // Limit to top 20 results
    }
    
    private var currentSearchTask: MKLocalSearch?
    private var currentGeocoderTask: CLGeocoder?
    
    private func sortPlacemarksByRelevance(_ placemarks: [CLPlacemark], query: String) -> [CLPlacemark] {
        let queryLowercased = query.lowercased()
        
        return placemarks.sorted { placemark1, placemark2 in
            let score1 = calculateRelevanceScore(for: placemark1, query: queryLowercased)
            let score2 = calculateRelevanceScore(for: placemark2, query: queryLowercased)
            return score1 > score2
        }
    }
    
    private func calculateRelevanceScore(for placemark: CLPlacemark, query: String) -> Double {
        var score: Double = 0
        
        // Check if this looks like a specific address (contains numbers)
        let isAddressQuery = query.rangeOfCharacter(from: .decimalDigits) != nil
        
        // For address queries, prioritize thoroughfare matches
        if isAddressQuery {
            if let thoroughfare = placemark.thoroughfare?.lowercased() {
                if thoroughfare.contains(query) {
                    score += 1500 // High priority for street matches
                }
            }
            
            if let subThoroughfare = placemark.subThoroughfare?.lowercased() {
                if subThoroughfare.contains(query) {
                    score += 1200 // High priority for house number matches
                }
            }
        }
        
        // Exact name matches get highest priority
        if let name = placemark.name?.lowercased(), name.hasPrefix(query) {
            score += 1000
            if name == query {
                score += 500 // Exact match bonus
            }
        }
        
        // City matches
        if let city = placemark.locality?.lowercased() {
            if city.hasPrefix(query) {
                score += 800
                if city == query {
                    score += 300
                }
            } else if city.contains(query) {
                score += 400
            }
        }
        
        // State/Province matches
        if let state = placemark.administrativeArea?.lowercased() {
            if state.hasPrefix(query) {
                score += 600
            } else if state.contains(query) {
                score += 200
            }
        }
        
        // Country matches (lower priority)
        if let country = placemark.country?.lowercased() {
            if country.hasPrefix(query) {
                score += 300
            } else if country.contains(query) {
                score += 100
            }
        }
        
        // Postal code matches (important for addresses)
        if let postalCode = placemark.postalCode?.lowercased() {
            if postalCode.hasPrefix(query) {
                score += 700
            } else if postalCode.contains(query) {
                score += 350
            }
        }
        
        // Proximity bonus (if current location available)
        if let currentLocation = location, let placemarkLocation = placemark.location {
            let distance = currentLocation.distance(from: placemarkLocation)
            let maxDistance: Double = 1000000 // 1000km
            let proximityScore = max(0, (maxDistance - distance) / maxDistance * 200)
            score += proximityScore
        }
        
        // Population/importance bonus (major cities typically have shorter names)
        if let city = placemark.locality {
            // Favor well-known cities (this is a heuristic)
            if city.count <= 10 { // Shorter city names are often major cities
                score += 50
            }
        }
        
        return score
    }
    
    private func arePlacemarksEqual(_ placemark1: CLPlacemark, _ placemark2: CLPlacemark) -> Bool {
        // Check if two placemarks represent the same location
        guard let location1 = placemark1.location, let location2 = placemark2.location else {
            return false
        }
        
        // Consider placemarks equal if they're within 100 meters of each other
        let distance = location1.distance(from: location2)
        if distance < 100 {
            return true
        }
        
        // Also check if they have the same name and city
        if let name1 = placemark1.name, let name2 = placemark2.name,
           let city1 = placemark1.locality, let city2 = placemark2.locality {
            return name1 == name2 && city1 == city2
        }
        
        return false
    }
    
    func setLocation(from placemark: CLPlacemark) {
        if let location = placemark.location {
            self.location = location
            self.locationName = createLocationName(from: placemark)
            self.fullLocationName = createFullLocationName(from: placemark)
            self.isUsingCurrentLocation = false
            addToRecentSearches(placemark)
            saveLocationToUserDefaults(location)
            saveLocationNamesToUserDefaults()
            getTimeZone(for: location)
        }
    }
    
    func useCurrentLocation() {
        isUsingCurrentLocation = true
        getCurrentLocation()
        UserDefaults.standard.set(true, forKey: "isUsingCurrentLocation")
    }
    
    func addToRecentSearches(_ placemark: CLPlacemark) {
        // Remove if already exists
        recentSearches.removeAll { existingPlacemark in
            arePlacemarksEqual(existingPlacemark, placemark)
        }
        
        // Add to beginning
        recentSearches.insert(placemark, at: 0)
        
        // Keep only the most recent searches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
    }
    
    
    func clearRecentSearches() {
        recentSearches.removeAll()
    }
    
    private func createLocationName(from placemark: CLPlacemark) -> String {
        // Check if this is a specific address (has street number and name)
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare,
           let city = placemark.locality,
           let state = placemark.administrativeArea {
            return "\(subThoroughfare) \(thoroughfare), \(city), \(state)"
        }
        // Check if it has just a street name
        else if let thoroughfare = placemark.thoroughfare,
                let city = placemark.locality,
                let state = placemark.administrativeArea {
            return "\(thoroughfare), \(city), \(state)"
        }
        // Fall back to city, state
        else if let city = placemark.locality, let state = placemark.administrativeArea {
            return "\(city), \(state)"
        }
        // Use the name if available
        else if let name = placemark.name {
            return name
        }
        return "Unknown Location"
    }
    
    private func createFullLocationName(from placemark: CLPlacemark) -> String {
        var fullNameComponents: [String] = []
        
        // Include full address if available
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            fullNameComponents.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            fullNameComponents.append(thoroughfare)
        }
        
        if let city = placemark.locality {
            fullNameComponents.append(city)
        }
        
        if let state = placemark.administrativeArea {
            fullNameComponents.append(state)
        }
        
        if let country = placemark.country {
            fullNameComponents.append(country)
        }
        
        return fullNameComponents.joined(separator: ", ")
    }
    
    // MARK: - Persistence
    
    private func saveLocationToUserDefaults(_ location: CLLocation) {
        UserDefaults.standard.set(location.coordinate.latitude, forKey: "savedLatitude")
        UserDefaults.standard.set(location.coordinate.longitude, forKey: "savedLongitude")
        UserDefaults.standard.set(isUsingCurrentLocation, forKey: "isUsingCurrentLocation")
    }
    
    private func saveLocationNamesToUserDefaults() {
        if let locationName = locationName {
            UserDefaults.standard.set(locationName, forKey: "savedLocationName")
        }
        if let fullLocationName = fullLocationName {
            UserDefaults.standard.set(fullLocationName, forKey: "savedFullLocationName")
        }
    }
    
    private func loadPersistedLocation() {
        isUsingCurrentLocation = UserDefaults.standard.bool(forKey: "isUsingCurrentLocation")
        
        let latitude = UserDefaults.standard.double(forKey: "savedLatitude")
        let longitude = UserDefaults.standard.double(forKey: "savedLongitude")
        
        if latitude != 0 && longitude != 0 {
            location = CLLocation(latitude: latitude, longitude: longitude)
            locationName = UserDefaults.standard.string(forKey: "savedLocationName")
            fullLocationName = UserDefaults.standard.string(forKey: "savedFullLocationName")
        }
        
        // Auto-request current location if using current location or no saved location
        if isUsingCurrentLocation || location == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestLocationPermission()
                self.getCurrentLocation()
            }
        }
    }
    
    private func loadRecentSearches() {
        // Load recent searches from UserDefaults if needed
        // For now, we'll keep them in memory only
    }
    
    // MARK: - Display Helpers
    
    var displayLocationText: String {
        if isUsingCurrentLocation {
            if let fullLocationName = fullLocationName {
                return "Current Location (\(fullLocationName))"
            } else if let locationName = locationName {
                return "Current Location (\(locationName))"
            } else if location != nil {
                return "Current Location (Getting name...)"
            } else {
                switch authorizationStatus {
                case .notDetermined:
                    return "Tap to enable location"
                case .denied, .restricted:
                    return "Location access denied"
                default:
                    return "Getting location..."
                }
            }
        } else {
            return fullLocationName ?? locationName ?? "Unknown Location"
        }
    }
    
    // MARK: - Timezone Handling
    
    private func getTimeZone(for location: CLLocation) {
        // Use CLGeocoder to get timezone information
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first,
                   let timeZone = placemark.timeZone {
                    self?.locationTimeZone = timeZone
                    self?.saveTimeZoneToUserDefaults(timeZone)
                } else {
                    // Fallback: estimate timezone from coordinates
                    self?.locationTimeZone = self?.estimateTimeZone(for: location)
                    if let timeZone = self?.locationTimeZone {
                        self?.saveTimeZoneToUserDefaults(timeZone)
                    }
                }
            }
        }
    }
    
    private func estimateTimeZone(for location: CLLocation) -> TimeZone? {
        // Rough estimation: 15 degrees longitude = 1 hour
        let longitude = location.coordinate.longitude
        let offsetHours = Int(round(longitude / 15.0))
        let offsetSeconds = offsetHours * 3600
        return TimeZone(secondsFromGMT: offsetSeconds)
    }
    
    private func saveTimeZoneToUserDefaults(_ timeZone: TimeZone) {
        UserDefaults.standard.set(timeZone.identifier, forKey: "savedTimeZoneIdentifier")
    }
    
    private func loadTimeZoneFromUserDefaults() {
        if let identifier = UserDefaults.standard.string(forKey: "savedTimeZoneIdentifier") {
            locationTimeZone = TimeZone(identifier: identifier)
        }
    }
}
