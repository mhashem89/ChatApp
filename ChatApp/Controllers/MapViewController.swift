//
//  MapViewController.swift
//  ChatApp
//
//  Created by Mohamed Hashem on 7/31/20.
//  Copyright © 2020 Mohamed Hashem. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

protocol MapViewControllerDelegate: class {
    
    func didSelectLocation(_ location: CLLocationCoordinate2D?)
    
    func didDismiss()
}

class MapViewController: UIViewController, MKMapViewDelegate {
    
    
    var mapView = MKMapView()
    
    weak var delegate: MapViewControllerDelegate?
    
    var locationManager = CLLocationManager()
    
    var showCertainLocation: CLLocation?
    
    var touchedCoordinate: CLLocationCoordinate2D? {
        didSet {
            self.mapView.removeAnnotations(mapView.annotations)
            self.mapView.addAnnotation(MKPlacemark(coordinate: touchedCoordinate!))
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mapView)
        mapView.frame = view.bounds
        mapView.showsBuildings = true
        title = "Select Location"
        
        
        
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            mapView.delegate = self
            mapView.showsUserLocation = true
        default:
            break
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        
        
        if let desiredLocation = showCertainLocation {
            mapView.setCenter(desiredLocation.coordinate, animated: true)
            mapView.setRegion(MKCoordinateRegion(center: desiredLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000), animated: true)
            navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(self.dismissMapVC)), animated: false)
            mapView.addAnnotation(MKPlacemark(coordinate: desiredLocation.coordinate))
        } else if let userLocation = locationManager.location {
            mapView.setCenter(userLocation.coordinate, animated: true)
            mapView.setRegion(MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000), animated: true)
            navigationItem.setRightBarButton(UIBarButtonItem(title: "Send", style: .plain, target: self, action: #selector(sendLocation)), animated: false)
            navigationItem.setLeftBarButton(UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissMapVC)), animated: false)
            view.addGestureRecognizer(tapGesture)
        } else {
            navigationItem.setLeftBarButton(UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissMapVC)), animated: false)
            navigationItem.setRightBarButton(UIBarButtonItem(title: "Send", style: .plain, target: self, action: #selector(sendLocation)), animated: false)
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }
    
    @objc func dismissMapVC() {
        delegate?.didDismiss()
        dismiss(animated: true, completion: nil)
    }
    
    @objc func sendLocation() {
        delegate?.didSelectLocation(touchedCoordinate)
        dismiss(animated: true, completion: nil)
    }
    
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let gestureLocation = gesture.location(in: view)
        let mapCoordinate = mapView.convert(gestureLocation, toCoordinateFrom: view)
        self.touchedCoordinate = mapCoordinate
    }
    
    
    
    
}
