//
//  StackedBarChartView.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 05/06/26.
//

import SwiftUI

struct CategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

struct StackedBarChartView: View {
    let items: [CategoryItem]

    private var total: Double {
        items.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { geo in
                let total = items.reduce(0) { $0 + $1.value }

                ZStack(alignment: .leading) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let consumed = items.prefix(index).reduce(0) { $0 + $1.value }
                        let remainingWidth = geo.size.width * ((total - consumed) / total)

                        Capsule()
                            .fill(item.color)
                            .frame(width: remainingWidth, height: 24)
                            .shadow(color: .black.opacity(0.1), radius: 2)

                    }
                }
            }
            .frame(height: 24)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    HStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)

                        Text(item.name)
                            .font(.caption)

                        Spacer()

                        Text("\(Int(item.value))%")
                            .font(.caption)
                            .foregroundStyle(item.color)
                    }
                }
            }
        }
    }
}

#Preview {
    StackedBarChartView(items: [
        .init(name: "Entertainment", value: 45, color: .orange),
        .init(name: "Games", value: 15, color: .green),
        .init(name: "Education", value: 25, color: .blue)
    ])
}
