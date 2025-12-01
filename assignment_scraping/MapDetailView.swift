//
//  MapDetailView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/12/01.
//

import SwiftUI
import MapKit

struct MapDetailView: View {
    let location: MapLocation
    
    // iOS 17以降のMapKitに対応したカメラ位置
    @State private var position: MapCameraPosition

    init(location: MapLocation) {
        self.location = location
        // 初期表示位置を該当の場所に設定
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )))
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            Map(position: $position) {
                Marker(location.name, coordinate: location.coordinate)
                    .tint(.red)
            }
            .navigationTitle("地図詳細")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            // iOS 16以下向けのフォールバック（必要であれば）
            Text("マップ表示にはiOS 17以降が必要です")
        }
    }
}
