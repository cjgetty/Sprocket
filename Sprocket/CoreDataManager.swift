//
//  CoreDataManager.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/12/25.
//

import Foundation
import CoreData
import UIKit

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // Use the same persistent container as PersistenceController to avoid conflicts
    var persistentContainer: NSPersistentContainer {
        return PersistenceController.shared.container
    }
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {
        // Initialize film stock database on first launch
        initializeFilmStockDatabase()
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    // Save a new logged shot
    func saveLoggedShot(
        aperture: Double,
        shutterSpeed: Double,
        iso: Double,
        ev: Double,
        latitude: Double?,
        longitude: Double?,
        imageData: Data?,
        locationName: String? = nil,
        cameraBody: String? = nil,
        lens: String? = nil,
        filmStock: String? = nil,
        frameNumber: Int16? = nil,
        notes: String? = nil
    ) {
        let newShot = LoggedShot(context: context)
        
        // Required fields
        newShot.id = UUID()
        newShot.timestamp = Date()
        newShot.aperture = aperture
        newShot.shutterSpeed = shutterSpeed
        newShot.iso = iso
        newShot.ev = ev
        
        // Optional location
        if let lat = latitude { newShot.latitude = lat }
        if let lon = longitude { newShot.longitude = lon }
        if let locName = locationName { newShot.locationName = locName }
        
        // Optional image
        if let imgData = imageData { newShot.imageData = imgData }
        
        // Optional metadata
        if let camera = cameraBody { newShot.cameraBody = camera }
        if let lensInfo = lens { newShot.lens = lensInfo }
        if let film = filmStock { newShot.filmStock = film }
        if let frame = frameNumber { newShot.frameNumber = frame }
        if let noteText = notes { newShot.notes = noteText }
        
        save()
        print("Shot logged successfully!")
    }
    
    // Fetch all logged shots
    func fetchLoggedShots() -> [LoggedShot] {
        let request: NSFetchRequest<LoggedShot> = LoggedShot.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggedShot.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
    
    // Delete a logged shot
    func deleteLoggedShot(_ shot: LoggedShot) {
        context.delete(shot)
        save()
    }
    
    // Initialize film stock database
    private func initializeFilmStockDatabase() {
        // Check if film stocks already exist
        let request: NSFetchRequest<FilmStock> = FilmStock.fetchRequest()
        do {
            let existingStocks = try context.fetch(request)
            if existingStocks.isEmpty {
                // Create sample film stocks
                FilmStock.createSampleFilmStocks(in: context)
                save()
                print("Film stock database initialized with sample data")
            }
        } catch {
            print("Error checking film stocks: \(error)")
        }
    }
    
    // Save a new logged shot with film stock relationship
    func saveLoggedShotWithFilmStock(
        aperture: Double,
        shutterSpeed: Double,
        iso: Double,
        ev: Double,
        latitude: Double?,
        longitude: Double?,
        imageData: Data?,
        locationName: String? = nil,
        cameraBody: String? = nil,
        lens: String? = nil,
        filmStock: FilmStock? = nil,
        frameNumber: Int16? = nil,
        notes: String? = nil
    ) {
        let newShot = LoggedShot(context: context)
        
        // Required fields
        newShot.id = UUID()
        newShot.timestamp = Date()
        newShot.aperture = aperture
        newShot.shutterSpeed = shutterSpeed
        newShot.iso = iso
        newShot.ev = ev
        
        // Optional location
        if let lat = latitude { newShot.latitude = lat }
        if let lon = longitude { newShot.longitude = lon }
        if let locName = locationName { newShot.locationName = locName }
        
        // Optional image
        if let imgData = imageData { newShot.imageData = imgData }
        
        // Optional metadata
        if let camera = cameraBody { newShot.cameraBody = camera }
        if let lensInfo = lens { newShot.lens = lensInfo }
        if let film = filmStock { 
            newShot.filmStock = film.name // Keep string for backward compatibility
            newShot.selectedFilmStock = film // Set relationship
        }
        if let frame = frameNumber { newShot.frameNumber = frame }
        if let noteText = notes { newShot.notes = noteText }
        
        save()
        print("Shot logged successfully with film stock relationship!")
    }
}
