//
//  ViewController.swift
//  Google Places API
//
//  Created by Alper Koçyiğit on 19.06.2024.
//

import UIKit
import GoogleMaps
import GooglePlaces
import CoreLocation

class ViewController: UIViewController {
    
    var currentRoutePolyline: GMSPolyline?
    var mapView: GMSMapView!
    var placesClient: GMSPlacesClient!
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation?
    var circle: GMSCircle?
    var circleRadius: CLLocationDistance = 100.0
    var toggleTableViewButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tableView = UITableView(frame: CGRect(x: 20, y: 50, width: 200, height: 160))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.cornerRadius = 10.0
        tableView.rowHeight = 50
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
     
        view.addSubview(tableView)
    
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 17.0)
        mapView = GMSMapView.map(withFrame: view.frame, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.settings.zoomGestures = true
        mapView.settings.allowScrollGesturesDuringRotateOrZoom = true
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.isMyLocationEnabled = true
        mapView.delegate = self
        view.addSubview(mapView)
        view.bringSubviewToFront(tableView)

        // Add radius slider
        let radiusSlider = UISlider(frame: CGRect(x: 20, y: view.bounds.height - 120, width: view.bounds.width - 40, height: 20))
        radiusSlider.minimumValue = 50.0
        radiusSlider.maximumValue = 200.0
        radiusSlider.value = Float(circleRadius)
        radiusSlider.addTarget(self, action: #selector(radiusSliderValueChanged(_:)), for: .valueChanged)
        view.addSubview(radiusSlider)

        
        let radiusLabel = UILabel(frame: CGRect(x: 20, y: view.bounds.height - 150, width: view.bounds.width - 40, height: 20))
        radiusLabel.textAlignment = .center
        radiusLabel.textColor = .black
        radiusLabel.text = "Radius: \(Int(circleRadius)) meters"
        view.addSubview(radiusLabel)
        
        // Initialize Google Places Client
        placesClient = GMSPlacesClient.shared()
    }
    

    @objc func radiusSliderValueChanged(_ sender: UISlider) {
        
        circleRadius = CLLocationDistance(sender.value)
        
        fetchNearbyPlaces()
        
        
        if let radiusLabel = view.subviews.compactMap({ $0 as? UILabel }).first {
            radiusLabel.text = "Radius: \(Int(circleRadius)) meters"
        }
    }

    func fetchNearbyPlaces() {
        guard let currentLocation = currentLocation else { return }

        let circleCenter = currentLocation.coordinate

        let filter = GMSPlaceField(rawValue: UInt64(GMSPlaceField.name.rawValue) |
                                                UInt64(GMSPlaceField.coordinate.rawValue) |
                                                UInt64(GMSPlaceField.formattedAddress.rawValue) |
                                   UInt64(GMSPlaceField.types.rawValue))
        
        placesClient.findPlaceLikelihoodsFromCurrentLocation(withPlaceFields: filter, callback: { (placeLikelihoods, error) in
            if let error = error {
                print("Error fetching nearby places: \(error.localizedDescription)")
                return
            }

            guard let placeLikelihoods = placeLikelihoods else {
                print("No nearby places found.")
                return
            }

            self.mapView.clear()
            self.drawCircle(at: circleCenter, withRadius: self.circleRadius)
            
            self.currentRoutePolyline?.map = self.mapView
            
            for likelihood in placeLikelihoods {
                let place = likelihood.place
                
                let placeLocation = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                let distance = currentLocation.distance(from: placeLocation)
                
                if distance <= self.circleRadius {
                    if let types = place.types, let type = types.first(where: { ["restaurant", "cafe", "bar", "bakery", "meal_takeaway","supermarket","liquor_store","university"].contains($0)}) {
                        let marker = GMSMarker(position: place.coordinate)
                        marker.title = place.name
                        marker.snippet = place.formattedAddress
                        marker.icon = self.markerImage(for: type)
                        marker.map = self.mapView
                        marker.userData = place
                    }
                }
            }
        })
    }
    
    func markerImage(for type: String) -> UIImage? {
        switch type {
        case "restaurant":
            return GMSMarker.markerImage(with: .red)
        case "cafe":
            return GMSMarker.markerImage(with: .blue)
        case "bar":
            return GMSMarker.markerImage(with: .yellow)
        case "bakery":
            return GMSMarker.markerImage(with: .purple)
        case "meal_takeaway":
            return GMSMarker.markerImage(with: .orange)
        case "supermarket":
            return GMSMarker.markerImage(with: .green)
        case "liquor_store":
            return GMSMarker.markerImage(with: .black)
        case "university":
            return GMSMarker.markerImage(with: .darkGray)
        default:
            return GMSMarker.markerImage(with: .gray)
        }
    }

    func drawCircle(at coordinate: CLLocationCoordinate2D, withRadius radius: CLLocationDistance) {
        circle?.map = nil

        circle = GMSCircle(position: coordinate, radius: radius)
        circle?.fillColor = UIColor(red: 0, green: 0.7, blue: 0, alpha: 0.1) // Transparent green color
        circle?.strokeColor = .red
        circle?.strokeWidth = 2
        circle?.map = mapView
    }

    func openDirections(for place: GMSPlace) {
        guard let currentLocation = currentLocation else {
            print("Current location is nil.")
            return
        }
        
        
        let origin = "\(currentLocation.coordinate.latitude),\(currentLocation.coordinate.longitude)"
        let destination = "\(place.coordinate.latitude),\(place.coordinate.longitude)"
        let apiKey = "API_KEY2"
        
    
        let url = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)&key=\(apiKey)"
        
        // Perform request
        URLSession.shared.dataTask(with: URL(string: url)!) { data, response, error in
            if let error = error {
                print("Error performing request: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
             
                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                
        
                guard let routes = json["routes"] as? [[String: Any]], !routes.isEmpty else {
                    print("No routes found in JSON response")
                    return
                }
                
   
                guard let route = routes.first, let legs = route["legs"] as? [[String: Any]], !legs.isEmpty else {
                    print("No valid route found in JSON response")
                    return
                }
                
                guard let duration = legs.first?["duration"] as? [String: Any], let durationText = duration["text"] as? String else {
                    print("No valid duration found in JSON response")
                    return
                }
                
                guard let distance = legs.first?["distance"] as? [String: Any], let distanceText = distance["text"] as? String else {
                    print("No valid distance found in JSON response")
                    return
                }
                
     
                DispatchQueue.main.async {
                   
                    if let route = routes.first, let overviewPolyline = route["overview_polyline"] as? [String: Any], let points = overviewPolyline["points"] as? String {
                 
                        let path = GMSPath(fromEncodedPath: points)
                        self.currentRoutePolyline?.map = nil
                        let polyline = GMSPolyline(path: path)
                        polyline.strokeColor = .blue
                        polyline.strokeWidth = 5
                        polyline.map = self.mapView
                        self.currentRoutePolyline = polyline
                        
                        self.showDurationAndDistanceAlert(durationText, distanceText)
                        self.adjustCameraToShowRoute(path)
                    } else {
                        print("No valid route found in JSON response")
                    }
                }
                
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
            }
        }.resume()
    }

    func adjustCameraToShowRoute(_ path: GMSPath?) {
        guard let path = path else { return }
        let bounds = GMSCoordinateBounds(path: path)
        let update = GMSCameraUpdate.fit(bounds, withPadding: 80.0)
        mapView.animate(with: update)
    }

    func showDurationAndDistanceAlert(_ durationText: String, _ distanceText: String) {
        let alert = UIAlertController(title: "Estimated Time and Distance", message: "Estimated travel time: \(durationText)\nDistance: \(distanceText)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        currentLocation = location

        fetchNearbyPlaces()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager did fail with error: \(error.localizedDescription)")
    }
}

extension ViewController: GMSMapViewDelegate {

    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        if let place = marker.userData as? GMSPlace {
            
            let googleMapsAction = UIAlertAction(title: "Detail", style: .default) { (_) in
                if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(place.coordinate.latitude),\(place.coordinate.longitude)") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            
            
            let directionsAction = UIAlertAction(title: "Go to Location", style: .default) { (_) in
                self.openDirections(for: place)
            }

           
            let alert = UIAlertController(title: "\(place.name ?? "")", message: "\(place.formattedAddress ?? "")", preferredStyle: .actionSheet)
            alert.addAction(directionsAction)
            alert.addAction(googleMapsAction)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
            
            return true
        }
        return false
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 8
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = .white
        cell.selectionStyle = .none
        cell.textLabel?.textColor = .black
        
        // Marker türlerine göre renkler ve metinleri ata
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Restaurant"
            cell.imageView?.image = GMSMarker.markerImage(with: .red)
           
        case 1:
            cell.textLabel?.text = "Cafe"
            cell.imageView?.image = GMSMarker.markerImage(with: .blue)
           
        case 2:
            cell.textLabel?.text = "Bar"
            cell.imageView?.image = GMSMarker.markerImage(with: .yellow)
        case 3:
            cell.textLabel?.text = "Bakery"
            cell.imageView?.image = GMSMarker.markerImage(with: .purple)
           
        case 4:
            cell.textLabel?.text = "Meal Takeaway"
            cell.imageView?.image = GMSMarker.markerImage(with: .orange)
            
        case 5:
            cell.textLabel?.text = "Supermarket"
            cell.imageView?.image = GMSMarker.markerImage(with: .green)
            
        case 6:
            cell.textLabel?.text = "Liquor Store"
            cell.imageView?.image = GMSMarker.markerImage(with: .black)
            
        case 7:
            cell.textLabel?.text = "University"
            cell.imageView?.image = GMSMarker.markerImage(with: .darkGray)
            
        default:
            break
        }
        
        return cell
    }
}
