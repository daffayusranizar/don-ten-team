//
//  SplashScreenView.swift
//  team-10-c3
//
//  Created by Huy Tran on 10/06/26.
//

import SwiftUI

struct SplashScreenView: View {
    
    
    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.primaryMediumBlue, .primaryTeal],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .ignoresSafeArea()
            
            Image("SplashLogo")
            
            VStack(alignment: .trailing) {
                Spacer()
                
                HStack {
                    Spacer()
                    Image("SplashCorner")
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashScreenView()
}
