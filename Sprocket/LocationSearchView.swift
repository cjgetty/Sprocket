//
//  LocationSearchView.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/13/25.
//

import SwiftUI
import CoreLocation

// MARK: - Location Search View
struct LocationSearchView: View {
    @Binding var searchText: String
    @Binding var searchResults: [CLPlacemark]
    @Binding var isSearching: Bool
    @ObservedObject var locationManager: LocationManager
    let onLocationSelected: (CLPlacemark) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for a location...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) {
                            performSearch(query: searchText)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Search Results
                if isSearching {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No locations found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && searchText.isEmpty {
                    // Show recent searches when no search text
                    if !locationManager.recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Recent Searches")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button("Clear") {
                                    locationManager.clearRecentSearches()
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            List(locationManager.recentSearches, id: \.self) { placemark in
                                LocationSearchRow(placemark: placemark) {
                                    onLocationSelected(placemark)
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "location.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Search for a location")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Enter a city, landmark, or address")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    // Show search results
                    VStack(alignment: .leading, spacing: 0) {
                        if !searchText.isEmpty {
                            HStack {
                                Text("Search Results")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(searchResults.count) found")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }
                        
                        List(searchResults, id: \.self) { placemark in
                            LocationSearchRow(placemark: placemark) {
                                onLocationSelected(placemark)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                searchTask?.cancel()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Current Location") {
                        locationManager.useCurrentLocation()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch(query: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        // Even faster debounce for MapKit search (more responsive)
        searchTask = Task {
            isSearching = true
            
            // Wait for only 100ms before searching for instant response
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            locationManager.searchLocation(query: query) { results in
                DispatchQueue.main.async {
                    searchResults = results
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Location Search Row
struct LocationSearchRow: View {
    let placemark: CLPlacemark
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryLocationName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let secondaryName = secondaryLocationName {
                        Text(secondaryName)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var primaryLocationName: String {
        // Show full address if available, otherwise city/state
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            return "\(subThoroughfare) \(thoroughfare)"
        } else if let thoroughfare = placemark.thoroughfare {
            return thoroughfare
        } else {
            // Fall back to city, state for non-address locations
            var components: [String] = []
            
            if let city = placemark.locality {
                components.append(city)
            }
            
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            if !components.isEmpty {
                return components.joined(separator: ", ")
            } else if let name = placemark.name {
                return name
            }
        }
        
        return "Unknown Location"
    }
    
    private var secondaryLocationName: String? {
        var components: [String] = []
        
        // If we're showing an address in primary, show city/state/country in secondary
        if placemark.subThoroughfare != nil || placemark.thoroughfare != nil {
            if let city = placemark.locality {
                components.append(city)
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            if let country = placemark.country {
                components.append(country)
            }
        } else {
            // If showing city/state in primary, just show country in secondary
            if let country = placemark.country {
                components.append(country)
            }
        }
        
        // Add additional context if available
        if let subLocality = placemark.subLocality {
            components.insert(subLocality, at: 0)
        }
        
        return components.isEmpty ? nil : components.joined(separator: " • ")
    }
}

#Preview {
    LocationSearchView(
        searchText: .constant(""),
        searchResults: .constant([]),
        isSearching: .constant(false),
        locationManager: LocationManager.shared,
        onLocationSelected: { _ in }
    )
}
