import SwiftUI
import MapKit

struct MapDetailView: View {
    let targetLocation: MapLocation
    
    private let allLocations = SearchDataProvider.shared.locations
    
    @State private var position: MapCameraPosition
    @State private var userLocation: CLLocationCoordinate2D? = nil
    
    // 現在地取得用
    @State private var locationManager = CLLocationManager()

    init(location: MapLocation) {
        self.targetLocation = location
        
        _position = State(initialValue: .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.003,
                                       longitudeDelta: 0.003)
            )
        ))
    }
    
    var body: some View {
        ZStack {
            if #available(iOS 17.0, *) {
                Map(position: $position) {
                    
                    // 🔵 現在地
                    UserAnnotation()
                    
                    // ① その他ピン
                    ForEach(allLocations.filter { $0.id != targetLocation.id }) { location in
                        Marker(location.name, coordinate: location.coordinate)
                            .tint(.blue)
                    }
                    
                    // ② 選択中のピン（赤・最前面）
                    if let selected = allLocations.first(where: { $0.id == targetLocation.id }) {
                        Marker(selected.name, coordinate: selected.coordinate)
                            .tint(.red)
                    }
                }
                .onAppear {
                    requestLocationPermission()
                    
                    // ターゲットにズーム
                    position = .region(MKCoordinateRegion(
                        center: targetLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.003,
                                               longitudeDelta: 0.003)
                    ))
                }
                
                // ⭐️ 純正風の丸い「現在地へ移動」ボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            moveToUserLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.blue)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 20)
                    }
                }
            } else {
                Text("iOS17以上が必要です")
            }
        }
        .navigationTitle(targetLocation.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 👉 現在地許可リクエスト
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        if let loc = locationManager.location?.coordinate {
            self.userLocation = loc
        }
    }
    
    // 👉 ボタン押したら現在地へジャンプ
    private func moveToUserLocation() {
        guard let userLoc = locationManager.location?.coordinate else { return }
        
        withAnimation {
            position = .region(
                MKCoordinateRegion(
                    center: userLoc,
                    span: MKCoordinateSpan(latitudeDelta: 0.002,
                                           longitudeDelta: 0.002)
                )
            )
        }
    }
}
