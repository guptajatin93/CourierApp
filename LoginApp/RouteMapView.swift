import SwiftUI
import MapKit

struct RouteMapView: UIViewRepresentable {
    var route: MKRoute

    // ✅ Keep a single MKMapView instance
    private let mapView = MKMapView()

    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Remove old overlays and add the new route
        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlay(route.polyline)

        // Set visible region only once (not on every update)
        if !context.coordinator.didSetRegion {
            uiView.setVisibleMapRect(
                route.polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 50, left: 20, bottom: 50, right: 20),
                animated: true
            )
            context.coordinator.didSetRegion = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var didSetRegion = false

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}
