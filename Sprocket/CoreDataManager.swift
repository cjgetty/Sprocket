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
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Sprocket")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
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
}
