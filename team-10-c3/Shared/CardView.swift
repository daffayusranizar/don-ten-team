//
//  CardView.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 05/06/26.
//

import SwiftUI

struct CardView<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let content: Content

    init(
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.height = height
        self.content = content()
    }

    var body: some View {
        content
            .frame(minWidth: width, minHeight: height, alignment: .top)
            
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.82, green: 0.83, blue: 0.88), lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.1), radius: 2)
    }
}



