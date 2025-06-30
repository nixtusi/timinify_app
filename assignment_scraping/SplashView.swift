//
//  SplashView.swift
//  assignment_scraping
//
//  Created by Yuta Nisimatsu on 2025/07/01.
//

import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isActive = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0.0
    
    var body: some View {
        Group {
            if isActive {
                if appState.isLoggedIn {
                    MainTabView()
                } else {
                    InitialSetupView {
                        appState.isLoggedIn = true
                    }
                }
            } else {
                ZStack {
                    Color.white.ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        Image("SplashLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 25)) // アイコン風に角丸
                        
                        Text("Uni Time")
                            .font(.system(size: 29, weight: .semibold)) // 少し大きめ・太字
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center) // 中央揃えを明示
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 中央に配置
                    .onAppear {
                        // 0.5秒後に画面遷移（アニメーションなし）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}
