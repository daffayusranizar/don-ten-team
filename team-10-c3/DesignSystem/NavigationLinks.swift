//
//  NavigationLinks.swift
//  team-10-c3
//
//  Created by Huy Tran on 01/06/26.
//

import SwiftUI

struct NavLink<Destination: View>: View {
    let icon: String?
    let title: String
    @Binding var changePage: Bool
    let destination: Destination

    init(
        icon: String? = nil,
        title: String,
        changePage: Binding<Bool>,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.title = title
        self._changePage = changePage
        self.destination = destination()
    }

    var body: some View {
        Button {
            changePage.toggle()
        } label: {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                }

                Text(title)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.textPrimary)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .navigationDestination(isPresented: $changePage) {
            destination
        }
        .buttonStyle(.plain)
    }
}
