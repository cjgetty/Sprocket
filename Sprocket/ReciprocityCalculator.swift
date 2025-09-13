//
//  ReciprocityCalculator.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/12/25.
//

import Foundation
import CoreData

class ReciprocityCalculator: ObservableObject {
    static let shared = ReciprocityCalculator()
    
    private init() {}
    
    /// Calculate the correct exposure settings accounting for reciprocity failure
    /// - Parameters:
    ///   - meteredEV: The metered exposure value
    ///   - filmStock: The selected film stock
    ///   - baseISO: The base ISO setting
    ///   - pushPullStops: Number of stops to push (+) or pull (-)
    /// - Returns: Calculated exposure settings
    func calculateExposure(
        meteredEV: Double,
        filmStock: FilmStock?,
        baseISO: Double = 100,
        pushPullStops: Double = 0
    ) -> ExposureSettings {
        
        let effectiveISO = filmStock?.effectiveISO ?? baseISO
        let isoAdjustment = log2(effectiveISO / baseISO)
        let adjustedEV = meteredEV - isoAdjustment - pushPullStops
        
        // Calculate base exposure time from EV
        let baseExposureTime = pow(2.0, -adjustedEV)
        
        // Apply reciprocity failure correction if film stock is selected
        let correctedExposureTime: Double
        if let filmStock = filmStock {
            correctedExposureTime = filmStock.calculateReciprocityCompensation(for: baseExposureTime)
        } else {
            correctedExposureTime = baseExposureTime
        }
        
        // Calculate aperture and shutter speed combinations
        let apertureOptions = calculateApertureOptions(for: correctedExposureTime, targetEV: adjustedEV)
        let shutterSpeedOptions = calculateShutterSpeedOptions(for: correctedExposureTime)
        
        return ExposureSettings(
            meteredEV: meteredEV,
            adjustedEV: adjustedEV,
            baseExposureTime: baseExposureTime,
            correctedExposureTime: correctedExposureTime,
            effectiveISO: effectiveISO,
            pushPullStops: pushPullStops,
            apertureOptions: apertureOptions,
            shutterSpeedOptions: shutterSpeedOptions,
            reciprocityCompensation: filmStock != nil ? correctedExposureTime - baseExposureTime : 0
        )
    }
    
    /// Calculate aperture options for a given exposure time
    private func calculateApertureOptions(for exposureTime: Double, targetEV: Double) -> [Double] {
        let standardApertures: [Double] = [1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0, 32.0]
        
        // Calculate the ideal aperture for the exposure time
        let idealAperture = sqrt(pow(2.0, targetEV) / exposureTime)
        
        // Find the closest standard apertures
        let sortedApertures = standardApertures.sorted { abs($0 - idealAperture) < abs($1 - idealAperture) }
        
        return Array(sortedApertures.prefix(5)) // Return top 5 closest options
    }
    
    /// Calculate shutter speed options for a given exposure time
    private func calculateShutterSpeedOptions(for exposureTime: Double) -> [Double] {
        let standardShutterSpeeds: [Double] = [
            1/8000, 1/4000, 1/2000, 1/1000, 1/500, 1/250, 1/125, 1/60, 1/30, 1/15, 1/8, 1/4, 1/2, 1, 2, 4, 8, 15, 30, 60, 120, 240, 480, 960
        ]
        
        // Find the closest standard shutter speeds
        let sortedSpeeds = standardShutterSpeeds.sorted { abs($0 - exposureTime) < abs($1 - exposureTime) }
        
        return Array(sortedSpeeds.prefix(5)) // Return top 5 closest options
    }
    
    /// Get reciprocity failure warning for long exposures
    func getReciprocityWarning(for exposureTime: Double, filmStock: FilmStock?) -> ReciprocityWarning? {
        guard let filmStock = filmStock else { return nil }
        
        let correctedTime = filmStock.calculateReciprocityCompensation(for: exposureTime)
        let compensation = correctedTime - exposureTime
        
        if compensation > 0.5 { // More than 0.5 seconds compensation
            return ReciprocityWarning(
                originalTime: exposureTime,
                correctedTime: correctedTime,
                compensation: compensation,
                severity: compensation > 2.0 ? .high : .medium,
                message: generateWarningMessage(compensation: compensation)
            )
        }
        
        return nil
    }
    
    private func generateWarningMessage(compensation: Double) -> String {
        if compensation > 5.0 {
            return "⚠️ Significant reciprocity failure detected. Consider using a tripod and cable release."
        } else if compensation > 2.0 {
            return "⚠️ Moderate reciprocity failure. Exposure time will be longer than metered."
        } else {
            return "ℹ️ Minor reciprocity compensation applied."
        }
    }
}

// MARK: - Data Structures
struct ExposureSettings {
    let meteredEV: Double
    let adjustedEV: Double
    let baseExposureTime: Double
    let correctedExposureTime: Double
    let effectiveISO: Double
    let pushPullStops: Double
    let apertureOptions: [Double]
    let shutterSpeedOptions: [Double]
    let reciprocityCompensation: Double
    
    var primaryAperture: Double {
        return apertureOptions.first ?? 5.6
    }
    
    var primaryShutterSpeed: Double {
        return shutterSpeedOptions.first ?? 1/125
    }
}

struct ReciprocityWarning {
    let originalTime: Double
    let correctedTime: Double
    let compensation: Double
    let severity: WarningSeverity
    let message: String
}

enum WarningSeverity {
    case low
    case medium
    case high
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - Film Stock Manager
class FilmStockManager: ObservableObject {
    static let shared = FilmStockManager()
    
    @Published var selectedFilmStock: FilmStock?
    @Published var availableFilmStocks: [FilmStock] = []
    @Published var pushPullStops: Double = 0
    
    private let coreDataManager = CoreDataManager.shared
    
    // Callback for when film stock is selected
    var onFilmStockSelected: ((FilmStock?) -> Void)?
    
    private init() {
        loadFilmStocks()
        loadSelectedFilmStock()
    }
    
    func loadFilmStocks() {
        let request: NSFetchRequest<FilmStock> = FilmStock.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FilmStock.manufacturer, ascending: true),
            NSSortDescriptor(keyPath: \FilmStock.name, ascending: true)
        ]
        
        do {
            availableFilmStocks = try coreDataManager.context.fetch(request)
        } catch {
            print("Error loading film stocks: \(error)")
            availableFilmStocks = []
        }
    }
    
    func loadSelectedFilmStock() {
        let selectedFilmStockName = UserDefaults.standard.string(forKey: "selectedFilmStock")
        selectedFilmStock = availableFilmStocks.first { $0.name == selectedFilmStockName }
    }
    
    func selectFilmStock(_ filmStock: FilmStock) {
        selectedFilmStock = filmStock
        UserDefaults.standard.set(filmStock.name, forKey: "selectedFilmStock")
        
        // Notify that film stock was selected
        onFilmStockSelected?(filmStock)
    }
    
    func setPushPullStops(_ stops: Double) {
        pushPullStops = stops
        UserDefaults.standard.set(stops, forKey: "pushPullStops")
    }
    
    func loadPushPullStops() {
        pushPullStops = UserDefaults.standard.double(forKey: "pushPullStops")
    }
    
    func createCustomFilmStock(
        name: String,
        manufacturer: String,
        iso: Double,
        type: String,
        format: String,
        reciprocityConstant: Double,
        reciprocityExponent: Double,
        developmentTime: Double,
        temperature: Double,
        notes: String?
    ) -> FilmStock {
        let filmStock = FilmStock(context: coreDataManager.context)
        filmStock.name = name
        filmStock.manufacturer = manufacturer
        filmStock.iso = iso
        filmStock.type = type
        filmStock.format = format
        filmStock.reciprocityConstant = reciprocityConstant
        filmStock.reciprocityExponent = reciprocityExponent
        filmStock.pushPullCompensation = 0
        filmStock.developmentTime = developmentTime
        filmStock.temperature = temperature
        filmStock.notes = notes
        filmStock.isActive = true
        filmStock.createdDate = Date()
        
        coreDataManager.save()
        loadFilmStocks()
        
        return filmStock
    }
}
