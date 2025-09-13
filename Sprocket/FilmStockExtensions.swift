//
//  FilmStockExtensions.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/12/25.
//

import Foundation
import CoreData

// MARK: - FilmStock Extensions
extension FilmStock {
    
    /// Calculate reciprocity failure compensation for a given exposure time
    /// - Parameter exposureTime: The metered exposure time in seconds
    /// - Returns: The corrected exposure time accounting for reciprocity failure
    func calculateReciprocityCompensation(for exposureTime: Double) -> Double {
        // Reciprocity failure formula: t_corrected = t_metered^p * k
        // where p is the reciprocity exponent and k is the reciprocity constant
        guard exposureTime > 1.0 else { return exposureTime } // No compensation needed for short exposures
        
        let correctedTime = pow(exposureTime, reciprocityExponent) * reciprocityConstant
        return max(correctedTime, exposureTime) // Never go shorter than metered time
    }
    
    /// Get the effective ISO for push/pull processing
    var effectiveISO: Double {
        return iso * pow(2.0, pushPullCompensation)
    }
    
    /// Calculate development time adjustment for push/pull
    /// - Parameter pushPullStops: Number of stops to push (+) or pull (-)
    /// - Returns: Adjusted development time in minutes
    func adjustedDevelopmentTime(for pushPullStops: Double) -> Double {
        let adjustmentFactor = pow(1.4, pushPullStops) // Standard push/pull adjustment
        return developmentTime * adjustmentFactor
    }
}

// MARK: - Sample Data
extension FilmStock {
    static func createSampleFilmStocks(in context: NSManagedObjectContext) {
        let filmStocks = [
            // Black & White Films
            FilmStockData(
                name: "Kodak Tri-X 400",
                manufacturer: "Kodak",
                iso: 400,
                type: "B&W",
                format: "35mm",
                reciprocityConstant: 1.3,
                reciprocityExponent: 1.3,
                pushPullCompensation: 0,
                developmentTime: 6.5,
                temperature: 20,
                notes: "Classic high-speed B&W film with excellent grain structure"
            ),
            FilmStockData(
                name: "Ilford HP5 Plus",
                manufacturer: "Ilford",
                iso: 400,
                type: "B&W",
                format: "35mm",
                reciprocityConstant: 1.4,
                reciprocityExponent: 1.4,
                pushPullCompensation: 0,
                developmentTime: 6.5,
                temperature: 20,
                notes: "Versatile B&W film with good reciprocity characteristics"
            ),
            FilmStockData(
                name: "Kodak T-Max 100",
                manufacturer: "Kodak",
                iso: 100,
                type: "B&W",
                format: "35mm",
                reciprocityConstant: 1.0,
                reciprocityExponent: 1.0,
                pushPullCompensation: 0,
                developmentTime: 5.5,
                temperature: 20,
                notes: "Fine grain B&W film with minimal reciprocity failure"
            ),
            FilmStockData(
                name: "Ilford Delta 3200",
                manufacturer: "Ilford",
                iso: 3200,
                type: "B&W",
                format: "35mm",
                reciprocityConstant: 1.5,
                reciprocityExponent: 1.5,
                pushPullCompensation: 0,
                developmentTime: 8.0,
                temperature: 20,
                notes: "Ultra-high speed B&W film for low light"
            ),
            
            // Color Negative Films
            FilmStockData(
                name: "Kodak Portra 400",
                manufacturer: "Kodak",
                iso: 400,
                type: "Color Negative",
                format: "35mm",
                reciprocityConstant: 1.2,
                reciprocityExponent: 1.2,
                pushPullCompensation: 0,
                developmentTime: 3.5,
                temperature: 38,
                notes: "Professional color negative film with excellent skin tones"
            ),
            FilmStockData(
                name: "Fujifilm Superia 400",
                manufacturer: "Fujifilm",
                iso: 400,
                type: "Color Negative",
                format: "35mm",
                reciprocityConstant: 1.3,
                reciprocityExponent: 1.3,
                pushPullCompensation: 0,
                developmentTime: 3.5,
                temperature: 38,
                notes: "Consumer color negative film with good color saturation"
            ),
            FilmStockData(
                name: "Kodak Ektar 100",
                manufacturer: "Kodak",
                iso: 100,
                type: "Color Negative",
                format: "35mm",
                reciprocityConstant: 1.1,
                reciprocityExponent: 1.1,
                pushPullCompensation: 0,
                developmentTime: 3.5,
                temperature: 38,
                notes: "Ultra-fine grain color negative film"
            ),
            
            // Slide Films
            FilmStockData(
                name: "Fujifilm Velvia 50",
                manufacturer: "Fujifilm",
                iso: 50,
                type: "Slide",
                format: "35mm",
                reciprocityConstant: 1.0,
                reciprocityExponent: 1.0,
                pushPullCompensation: 0,
                developmentTime: 6.0,
                temperature: 38,
                notes: "High saturation slide film with excellent reciprocity"
            ),
            FilmStockData(
                name: "Kodak Ektachrome 100",
                manufacturer: "Kodak",
                iso: 100,
                type: "Slide",
                format: "35mm",
                reciprocityConstant: 1.2,
                reciprocityExponent: 1.2,
                pushPullCompensation: 0,
                developmentTime: 6.0,
                temperature: 38,
                notes: "Professional slide film with good color accuracy"
            )
        ]
        
        for filmData in filmStocks {
            let filmStock = FilmStock(context: context)
            filmStock.name = filmData.name
            filmStock.manufacturer = filmData.manufacturer
            filmStock.iso = filmData.iso
            filmStock.type = filmData.type
            filmStock.format = filmData.format
            filmStock.reciprocityConstant = filmData.reciprocityConstant
            filmStock.reciprocityExponent = filmData.reciprocityExponent
            filmStock.pushPullCompensation = filmData.pushPullCompensation
            filmStock.developmentTime = filmData.developmentTime
            filmStock.temperature = filmData.temperature
            filmStock.notes = filmData.notes
            filmStock.isActive = true
            filmStock.createdDate = Date()
        }
    }
}

// MARK: - Helper Data Structure
struct FilmStockData {
    let name: String
    let manufacturer: String
    let iso: Double
    let type: String
    let format: String
    let reciprocityConstant: Double
    let reciprocityExponent: Double
    let pushPullCompensation: Double
    let developmentTime: Double
    let temperature: Double
    let notes: String?
}
