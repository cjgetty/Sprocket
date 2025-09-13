//
//  PhotoCaptureManager.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/12/25.
//

import Foundation
import AVFoundation
import UIKit

class PhotoCaptureManager: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var completion: ((Data?) -> Void)?
    
    func setupPhotoCapture(with session: AVCaptureSession) {
        self.captureSession = session
        
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput,
           session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
    }
    
    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(nil)
            return
        }
        
        self.completion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension PhotoCaptureManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            completion?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            completion?(nil)
            return
        }
        
        completion?(imageData)
    }
}
