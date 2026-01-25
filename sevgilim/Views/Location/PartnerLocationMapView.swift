//
//  PartnerLocationMapView.swift
//  sevgilim
//
//  Harita görünümü - User ve partner konumlarını gösteren MapKit view
//

import SwiftUI
import MapKit
import CoreLocation

struct PartnerLocationMapView: View {
    let userLocation: UserLocation?
    let partnerLocation: UserLocation?
    @Binding var region: MKCoordinateRegion
    let isNearPartner: Bool
    var onPinTapped: ((LocationAnnotation) -> Void)? = nil
    
    @State private var showUserCallout = false
    @State private var showPartnerCallout = false
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
            MapAnnotation(coordinate: annotation.coordinate, anchorPoint: CGPoint(x: 0.5, y: 1.0)) {
                LocationPinView(
                    annotation: annotation,
                    isNear: isNearPartner && annotation.type == .partner
                )
                .onTapGesture {
                    // Pin'e t\u0131kland\u0131\u011f\u0131nda o konuma odaklan
                    withAnimation(.easeInOut(duration: 0.5)) {
                        region = MKCoordinateRegion(
                            center: annotation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )
                    }
                    onPinTapped?(annotation)
                }
            }
        }
    }
    
    private var annotations: [LocationAnnotation] {
        var result: [LocationAnnotation] = []
        
        if let userLoc = userLocation {
            result.append(LocationAnnotation(
                id: "user",
                coordinate: userLoc.coordinate,
                title: "Sen",
                type: .user,
                lastUpdated: userLoc.lastUpdated
            ))
        }
        
        if let partnerLoc = partnerLocation {
            result.append(LocationAnnotation(
                id: "partner",
                coordinate: partnerLoc.coordinate,
                title: "Sevgilin",
                type: .partner,
                lastUpdated: partnerLoc.lastUpdated,
                batteryLevel: partnerLoc.batteryLevel
            ))
        }
        
        return result
    }
}

// MARK: - Location Pin View
struct LocationPinView: View {
    let annotation: LocationAnnotation
    let isNear: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Callout (opsiyonel)
            calloutView
            
            // Pin
            pinView
        }
        .onAppear {
            if isNear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private var calloutView: some View {
        VStack(spacing: 2) {
            Text(annotation.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let lastUpdated = annotation.lastUpdated {
                Text(formatLastUpdated(lastUpdated))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            annotation.type == .user ? Color.blue : Color.pink,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .offset(y: -4)
    }
    
    private var pinView: some View {
        ZStack {
            // Yakınlık animasyonu
            if isNear && annotation.type == .partner {
                Circle()
                    .fill(Color.pink.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .scaleEffect(isAnimating ? 1.5 : 1.0)
                    .opacity(isAnimating ? 0 : 0.5)
            }
            
            // Pin gölgesi
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 20, height: 6)
                .offset(y: 20)
            
            // Ana pin
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(
                            annotation.type == .user
                            ? LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: annotation.type == .user ? "person.fill" : "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                // Pin altı (pointer)
                LocationPinTriangle()
                    .fill(annotation.type == .user ? Color.blue : Color.pink)
                    .frame(width: 12, height: 10)
                    .rotationEffect(.degrees(180))
                    .offset(y: -2)
            }
        }
    }
    
    private func formatLastUpdated(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Şimdi"
        } else if interval < 3600 {
            return "\(Int(interval / 60))dk"
        } else {
            return "\(Int(interval / 3600))sa"
        }
    }
}

// MARK: - Triangle Shape for Location Pin
struct LocationPinTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - iOS 17+ Map Style Extension
extension View {
    @ViewBuilder
    func mapStyle(_ style: MapStyleType) -> some View {
        if #available(iOS 17.0, *) {
            self.modifier(MapStyleModifier(style: style))
        } else {
            self
        }
    }
}

enum MapStyleType {
    case standard(elevation: ElevationType = .flat, pointsOfInterest: PointsOfInterestType = .all)
    case satellite
    case hybrid
    
    enum ElevationType {
        case flat
        case realistic
    }
    
    enum PointsOfInterestType {
        case all
        case none
        case including([POICategory])
        case excluding([POICategory])
    }
    
    enum POICategory {
        case cafe
        case restaurant
        case park
        case hotel
        case museum
    }
}

@available(iOS 17.0, *)
struct MapStyleModifier: ViewModifier {
    let style: MapStyleType
    
    func body(content: Content) -> some View {
        content
    }
}

// MARK: - Map Route Overlay (Opsiyonel - iki konum arasında çizgi)
struct MapRouteOverlay: View {
    let userLocation: CLLocationCoordinate2D
    let partnerLocation: CLLocationCoordinate2D
    
    var body: some View {
        // Bu özellik daha sonra eklenebilir
        EmptyView()
    }
}

// MARK: - Preview
#Preview {
    PartnerLocationMapView(
        userLocation: UserLocation(
            userId: "user1",
            latitude: 41.0082,
            longitude: 28.9784,
            accuracy: 10,
            isSharing: true
        ),
        partnerLocation: UserLocation(
            userId: "user2",
            latitude: 41.0100,
            longitude: 28.9800,
            accuracy: 10,
            isSharing: true,
            batteryLevel: 75
        ),
        region: .constant(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.009, longitude: 28.979),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )),
        isNearPartner: true
    )
    .frame(height: 300)
}
