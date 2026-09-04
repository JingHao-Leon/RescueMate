import SwiftUI
import MapKit
import CoreLocation

/// 地图卡片：系统 MapKit 承载（中国大陆底图数据源即高德，无需额外 Key、不占接口额度）。
/// 显示用户位置 + 附近救援点图钉；气泡右侧拨号、左侧导航。
final class POIAnnotation: NSObject, MKAnnotation {
    let poi: POI

    init(poi: POI) { self.poi = poi }

    var coordinate: CLLocationCoordinate2D { poi.coordinate }
    var title: String? { poi.name }
    var subtitle: String? {
        var parts: [String] = []
        if let distance = Fmt.distance(poi.distanceMeters) { parts.append(distance) }
        if !poi.address.isEmpty { parts.append(poi.address) }
        return parts.joined(separator: " · ")
    }
}

struct POIMapView: UIViewRepresentable {
    let pois: [POI]
    var focus: POI?
    var recenterToken: Int
    var fallbackCenter: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = false
        map.isRotateEnabled = false
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "poi")
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator

        // 同步结果标注
        let newIDs = pois.map(\.id)
        if newIDs != coordinator.poiIDs {
            coordinator.poiIDs = newIDs
            map.removeAnnotations(map.annotations.filter { $0 is POIAnnotation })
            let annotations = pois.map(POIAnnotation.init)
            map.addAnnotations(annotations)
            showAll(map, annotations: annotations)
            coordinator.didSetInitialRegion = true
        }

        // 还没搜过时，先落到用户位置（或兜底坐标）
        if !coordinator.didSetInitialRegion,
           let center = map.userLocation.location?.coordinate ?? fallbackCenter {
            setCenter(map, center, meters: 2000)
            coordinator.didSetInitialRegion = true
        }

        // 点了列表某一行 -> 地图聚焦到该点
        if let focus, coordinator.lastFocusID != focus.id {
            coordinator.lastFocusID = focus.id
            setCenter(map, focus.coordinate, meters: 800)
            if let annotation = map.annotations.first(where: { ($0 as? POIAnnotation)?.poi.id == focus.id }) {
                map.selectAnnotation(annotation, animated: true)
            }
        }

        // 回到我的位置按钮
        if recenterToken != coordinator.recenterToken {
            coordinator.recenterToken = recenterToken
            if let user = map.userLocation.location?.coordinate {
                setCenter(map, user, meters: 1500)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func setCenter(_ map: MKMapView, _ center: CLLocationCoordinate2D, meters: Double) {
        map.setRegion(MKCoordinateRegion(center: center,
                                         latitudinalMeters: meters,
                                         longitudinalMeters: meters),
                      animated: true)
    }

    private func showAll(_ map: MKMapView, annotations: [POIAnnotation]) {
        switch annotations.count {
        case 0:
            break
        case 1:
            setCenter(map, annotations[0].coordinate, meters: 1200)
        default:
            map.showAnnotations(annotations, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var poiIDs: [String] = []
        var lastFocusID: String?
        var recenterToken = 0
        var didSetInitialRegion = false

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? POIAnnotation else { return nil }
            guard let view = map.dequeueReusableAnnotationView(withIdentifier: "poi", for: annotation)
                    as? MKMarkerAnnotationView else { return nil }
            view.canShowCallout = true
            view.markerTintColor = UIColor(red: 0.86, green: 0.16, blue: 0.15, alpha: 1)
            view.glyphImage = UIImage(systemName: annotation.poi.hasEmergency ? "cross.case.fill" : "mappin.and.ellipse")

            let phoneButton = UIButton(type: .system)
            phoneButton.setImage(UIImage(systemName: "phone.fill"), for: .normal)
            phoneButton.tintColor = .systemGreen
            view.rightCalloutAccessoryView = annotation.poi.tel?.isEmpty == false ? phoneButton : nil

            let navButton = UIButton(type: .system)
            navButton.setImage(UIImage(systemName: "map.fill"), for: .normal)
            navButton.tintColor = .systemBlue
            view.leftCalloutAccessoryView = navButton
            return view
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            guard let annotation = view.annotation as? POIAnnotation else { return }
            if control === view.rightCalloutAccessoryView, let tel = annotation.poi.tel, !tel.isEmpty {
                DeviceActions.dial(tel)
            } else if control === view.leftCalloutAccessoryView {
                DeviceActions.navigate(to: annotation.poi)
            }
        }
    }
}
