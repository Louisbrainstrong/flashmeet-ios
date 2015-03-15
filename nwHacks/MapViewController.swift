//
//  MapViewController.swift
//  nwHacks
//
//  Created by Andrew Richardson on 3/14/15.
//  Copyright (c) 2015 Andrew Richardson. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import QuartzCore

class RacerAnnotation: MKPointAnnotation {
    var racerLocation: RacerLocation {
        didSet {
            locationWillChange?(self)
            coordinate = racerLocation.location
            locationDidChange?(self)
        }
    }

    var locationWillChange: ((RacerAnnotation) -> ())?
    var locationDidChange: ((RacerAnnotation) -> ())?

    init(racerLocation: RacerLocation) {
        self.racerLocation = racerLocation
        super.init()
        coordinate = racerLocation.location
    }
}

class RacerAnnotationView: SVPulsingAnnotationView {
    private var animatePositionChanges = false

    override init!(annotation: MKAnnotation!, reuseIdentifier: String!) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        updateAnnotationObserver()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override var annotation: MKAnnotation! {
        didSet {
            if let oldAnnotation = oldValue as? RacerAnnotation {
                oldAnnotation.locationWillChange = nil
                oldAnnotation.locationDidChange = nil
            }
            updateAnnotationObserver()
        }
    }

    func updateAnnotationObserver() {
        if let racerAnnotation = annotation as? RacerAnnotation {
            racerAnnotation.locationWillChange = { [unowned self] annotation in
                self.animatePositionChanges = true

                let oldVal = annotation.coordinate
                let newVal = annotation.racerLocation.location

                // TODO: Animte position
                let positionAnimation = CABasicAnimation(keyPath: "position")
//                positionAnimation.fromValue = oldVal
//                positionAnimation.toValue = newVal
            }
            racerAnnotation.locationDidChange = { [unowned self] annotation in
                self.animatePositionChanges = false
            }
        }
    }

//    override var center: CGPoint {
//        get { return super.center }
//        set {
//            if animatePositionChanges {
//                UIView.beginAnimations("frameChange", context: nil)
//                UIView.setAnimationDuration(0.3)
//                super.center = newValue
//                UIView.commitAnimations()
//            } else {
//                super.center = newValue
//            }
//        }
//    }
}

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    @IBOutlet var mapView: MKMapView!
    lazy var locationManager = CLLocationManager()

    var updateTimer: NSTimer!
    var racerLocations: [Racer: RacerAnnotation] = [:]
    var destLocation: DestinationLocation?
    var currentLocation: CLLocationCoordinate2D? {
        didSet {
            handleLocationUpdate()
        }
    }

    var hasUpdatedMapVisibility = false
    var arrivedAtDestination = false

    let fakeUserLocation = true

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        mapView.pitchEnabled = false
        mapView.delegate = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        DataController.sharedController.fetchRaceInfo { destLocation in
            self.updateDestination(destLocation)
        }

        updateRacerData()
        if updateTimer == nil {
            updateTimer = NSTimer(timeInterval: 3, target: self, selector: "updateRacerData", userInfo: nil, repeats: true)
            NSRunLoop.mainRunLoop().addTimer(updateTimer, forMode: NSDefaultRunLoopMode)
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if CLLocationManager.authorizationStatus() != .AuthorizedAlways {
            locationManager.requestAlwaysAuthorization()
        } else {
            showUserLocation()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        if updateTimer != nil {
            updateTimer.invalidate()
            updateTimer = nil
        }
    }

    func showUserLocation() {
        if !fakeUserLocation {
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
        }
//        mapView.showsUserLocation = true
//        mapView.setUserTrackingMode(.None, animated: false)
    }

    dynamic func updateRacerData() {
        DataController.sharedController.fetchRacers { racers in
            self.updateRacerLocations(racers)
        }
    }

    func isLocationAtDestination(loc: CLLocationCoordinate2D) -> Bool {
        if let dest = destLocation?.location {
            let distanceThreshold = 100.0 // meters
            return loc.distanceFromCoordinate(dest) < distanceThreshold
        } else {
            return false
        }
    }

    func currentUserArrivedAtDestination() {
        if arrivedAtDestination { return }
        arrivedAtDestination = true

        let raceID = DataController.sharedController.raceID!
        let userID = DataController.sharedController.user!.userID

        let timestamp = leaderboardDateFormatter.stringFromDate(NSDate())
        leaderboardEndpoint(raceID).childByAppendingPath(userID).setValue(timestamp, withCompletionBlock: { eror, endpoint in
            self.performSegueWithIdentifier("showLeaderboard", sender: self)
        })
    }

    func updateRacerLocations(newLocations: [RacerLocation]) {
        for loc in newLocations {
            if let annotation = racerLocations[loc.racer] {
                annotation.racerLocation = loc
            } else {
                let annotation = RacerAnnotation(racerLocation: loc)
                racerLocations[loc.racer] = annotation
                mapView.addAnnotation(annotation)
            }

            if isLocationAtDestination(loc.location) {
                // TODO: Handle other user arriving at destination
            }

            if loc.racer.userID == "currentUser" {
                currentLocation = loc.location
            }
        }
        updateMapVisibility()
    }

    func updateMapVisibility() {
        let animated = hasUpdatedMapVisibility
        mapView.showAnnotations(mapView.annotations, animated: animated)
        hasUpdatedMapVisibility = true
    }

    func updateDestination(dest: DestinationLocation) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = dest.location
        mapView.addAnnotation(annotation)
        destLocation = dest
    }

    func handleLocationUpdate() {
        updateMapVisibility()
        DataController.sharedController.pushLocation(currentLocation!)
        if isLocationAtDestination(currentLocation!) {
            currentUserArrivedAtDestination()
        }
    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedAlways {
            showUserLocation()
        }
    }

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        currentLocation = (locations as? [CLLocation])?.first?.coordinate
    }

//    func mapView(mapView: MKMapView!, didUpdateUserLocation userLocation: MKUserLocation!) {
//        currentLocation = userLocation.location.coordinate
//        handleLocationUpdate()
//    }

    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if (annotation is RacerAnnotation) {
            let identifier = "racerLocation"
            var annotationView: RacerAnnotationView
            if let view = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? RacerAnnotationView {
                annotationView = view
            } else {
                func rcc() -> CGFloat {
                    return CGFloat(arc4random_uniform(255)) / 255
                }

                annotationView = RacerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.annotationColor = UIColor(red: rcc(), green: rcc(), blue: rcc(), alpha: 1)
                if (annotation as RacerAnnotation).racerLocation.racer.userID == "currentUser" {
                    annotationView.annotationColor = UIColor.blueColor()
                }
            }
            return annotationView
        }
        return nil
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
}

