//
//  LocationService.swift
//  sevgilim
//

import Foundation
import CoreLocation
import MapKit
import Combine

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = "Konum izni verilmedi"
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Konum servisleri kapalı"
            return
        }
        
        locationError = nil
        // Ana thread'de çalıştır
        DispatchQueue.main.async {
            self.locationManager.requestLocation()
        }
    }
    
    func getPlaceName(for location: CLLocation, completion: @escaping (String?, String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(nil, nil)
                return
            }
            
            var placeName = ""
            var address = ""
            
            // Yer adı için öncelik sırası
            if let name = placemark.name, !name.isEmpty {
                placeName = name
            } else if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                placeName = thoroughfare
            } else if let locality = placemark.locality, !locality.isEmpty {
                placeName = locality
            } else {
                placeName = "Bilinmeyen Yer"
            }
            
            // Adres bilgisi oluştur
            var addressComponents: [String] = []
            
            if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                addressComponents.append(thoroughfare)
            }
            
            if let subThoroughfare = placemark.subThoroughfare, !subThoroughfare.isEmpty {
                addressComponents.append(subThoroughfare)
            }
            
            if let locality = placemark.locality, !locality.isEmpty {
                addressComponents.append(locality)
            }
            
            if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
                addressComponents.append(administrativeArea)
            }
            
            if let country = placemark.country, !country.isEmpty {
                addressComponents.append(country)
            }
            
            address = addressComponents.joined(separator: ", ")
            
            completion(placeName, address.isEmpty ? nil : address)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.isLocationEnabled = true
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
            self.isLocationEnabled = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationEnabled = true
                self.locationError = nil
            case .denied, .restricted:
                self.isLocationEnabled = false
                self.locationError = "Konum izni reddedildi"
            case .notDetermined:
                self.isLocationEnabled = false
                self.locationError = nil
            @unknown default:
                self.isLocationEnabled = false
                self.locationError = "Bilinmeyen konum izni durumu"
            }
        }
    }
}
