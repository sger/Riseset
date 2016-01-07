//
//  RSLocationController.swift
//  Riseset
//
//  Created by Spiros Gerokostas on 23/12/15.
//  Copyright © 2015 Spiros Gerokostas. All rights reserved.
//

import UIKit
import CoreLocation
import RxSwift

class RSLocationController: NSObject, CLLocationManagerDelegate {
    
    enum Action {
        case UpdateLocation
        case FailWithError
    }
    
    var disposeBag = DisposeBag()
    
    let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
    }
    
    func requestAlwaysAuthorization() -> Observable<Bool> {
        if needsAuthorization() {
            locationManager.requestAlwaysAuthorization()
            return didAuthorize()
        } else {
            return authorized()
        }
    }
    
    private func authorized() -> Observable<Bool> {
        return Observable.create { observer in
            let authorized = CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse || CLLocationManager.authorizationStatus() == .AuthorizedAlways
            if authorized {
                observer.onNext(authorized)
            } else {
                observer.onError(NSError(domain: "RxSwiftErrorDomain", code: 1, userInfo: nil))
            }
            return NopDisposable.instance
        }
    }
    
    private func needsAuthorization() -> Bool {
        return CLLocationManager.authorizationStatus() == .NotDetermined
    }

    private func didAuthorize() -> Observable<Bool> {
        return Observable.create { observer in
            self.locationManager.rx_didChangeAuthorizationStatus
                .take(1)
                .subscribe { status in
                    switch status {
                    case .Next(let status):
                        observer.onNext(status == .AuthorizedWhenInUse || status == .AuthorizedAlways)
                        break
                    case .Error(let error):
                        observer.onError(error)
                        break
                    default: break
                    }
            }.addDisposableTo(self.disposeBag)
            
            return NopDisposable.instance
        }
    }

    func updateLocationAction()->Observable<CLLocation> {
        return Observable.create { observer in
            self.locationManager.rx_didUpdateLocations.take(1).subscribe { event in
                switch event {
                case .Next(let value):
                    let location = value.last!
                    observer.onNext(location)
                    break
                case .Completed:
                    observer.onCompleted()
                    break
                default: break
                }
            }.addDisposableTo(self.disposeBag)
            return NopDisposable.instance
        }
    }
    
    func failWithErrorAction()->Observable<NSError> {
        return Observable.create { observer in
            self.locationManager.rx_didFailWithError
                .subscribeNext { error in
                observer.onError(error)
            }.addDisposableTo(self.disposeBag)
            return NopDisposable.instance
        }
    }
    
    
    func updateLocationAction2()->Observable<CLLocation> {
        return self.locationManager
            .rx_didUpdateLocations
            .take(1)
            .map {
                $0.last!
            }
    }
    
    func failWithErrorAction2()->Observable<NSError> {
        return self.locationManager
            .rx_didFailWithError
            .flatMap { Observable.error($0) }
    }
    

    
    func runActions2() -> Observable <CLLocation> {
        return Observable.create {observer in
            
            let actions:[Observable<Action>] = [
                self.updateLocationAction2().map { _ in .UpdateLocation },
                self.failWithErrorAction2().map { _ in .FailWithError }
            ]
            
            actions
                .toObservable()
                .merge()
                .debug("actions")
                .take(1)
                .subscribe { event in
                    print("EVENT ACTION \(event)")
                    switch event {
                    case .Next(let value):
                        print("next value \(value)")
                        if value == .UpdateLocation {
                            self.fetchCurrentLocation().subscribeNext { location in
                                observer.onNext(location)
                                observer.onCompleted()
                                }.addDisposableTo(self.disposeBag)
                        }
                        break
                    case .Completed:
                        break
                    case .Error(let value):
                        observer.onError(value)
                        break
                    }
                }.addDisposableTo(self.disposeBag)
            return NopDisposable.instance
        }
    }
    
    func fetchCurrentLocation()->Observable<CLLocation> {
        return Observable.create { observer in
            self.locationManager.rx_didUpdateLocations.take(1).subscribe { event in
                switch event {
                    case .Next(let value):
                        let location = value.last!
                        observer.onNext(location)
                        break
                    case .Completed:
                        self.locationManager.stopUpdatingLocation()
                        observer.onCompleted()
                        break
                    case .Error(let error):
                        observer.onError(error)
                    break
                }
            }.addDisposableTo(self.disposeBag)
            return NopDisposable.instance
        }
    }
    
    func runActions() -> Observable <CLLocation> {
        return Observable.create {observer in
        
            let actions:[Observable<Action>] = [
                self.updateLocationAction().map { _ in return .UpdateLocation },
                self.failWithErrorAction().map { _ in return .FailWithError }
            ]
            
            actions
                .toObservable()
                .merge()
                .debug("actions")
                .take(1)
                .subscribe { event in
                    print("EVENT ACTION \(event)")
                    switch event {
                    case .Next(let value):
                        print("next value \(value)")
                        if value == .UpdateLocation {
                            self.fetchCurrentLocation().subscribeNext { location in
                                observer.onNext(location)
                                observer.onCompleted()
                            }.addDisposableTo(self.disposeBag)
                        }
                        break
                    case .Completed:
                        break
                    case .Error(let value):
                        observer.onError(value)
                        break
                    }
                }.addDisposableTo(self.disposeBag)
            return NopDisposable.instance
        }
    }
    
    func authorizationStatusEqualTo(status:CLAuthorizationStatus)->Bool {
        return CLLocationManager.authorizationStatus() == status
    }
}
