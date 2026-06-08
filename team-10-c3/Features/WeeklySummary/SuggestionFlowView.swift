//
//  SuggestionFlowView.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 05/06/26.
//

import SwiftUI


enum SuggestionStep {
    case initial
    case response
    case notes
}

struct SuggestionFlowView: View {
    let suggestionText: String
    @State private var currentStep: SuggestionStep = .initial

    var body: some View {
        VStack {
            switch currentStep {
            case .initial:
                TrySuggestionView(
                    suggestionText: suggestionText,
                    onYesTapped: {
                        withAnimation { currentStep = .response }
                    },
                    onNoTapped: {
                        print("Skipped")
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .response:
                DoTheSuggestionView(
                    onOptionSelected: { _ in
                        withAnimation { currentStep = .notes }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .notes:
                AdditionalNotesView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
    }
}

struct TrySuggestionView: View {
    let suggestionText: String
    var onYesTapped: () -> Void
    var onNoTapped: () -> Void

    var body: some View {
        CardView(minHeight: 300) {
            VStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 24, height: 24)

                        Image("checkin-icon")
                    }

                    Text("Last week's suggestion")
                        .font(.heading6)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.primaryMediumBlue.opacity(0.2))

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("primaryMediumBlue").opacity(0.1))
                        .padding(.vertical, 8)
                    Text("\"\(suggestionText)\"")
                        .font(.bodyRegular)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding(.horizontal, 18)

                HStack {
                    Text("Did you try it?")
                        .font(.bodyRegular)
                        .padding(.horizontal, 18)
                    Spacer()
                }

                Button {
                    onYesTapped()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("primaryMediumBlue").opacity(0.1))
                            .frame(height: 44)
                        Text("Yes, we did it")
                            .font(.bodyRegular)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)

                Button {
                    onNoTapped()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("primaryMediumBlue").opacity(0.1))
                            .frame(height: 44)
                        Text("Not this time")
                            .font(.bodyRegular)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
    }
}

struct DoTheSuggestionView: View {
    var onOptionSelected: (String) -> Void

    let responseOptions = [
        "Opened up and talked",
        "Enjoy it, not much talking",
        "Led to a longer conversation",
        "Didn't want to"
    ]

    var body: some View {
        CardView(minHeight: 300) {
            VStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 24, height: 24)

                        Image("checkin-icon")
                    }
                    Text("How did your child respond?")
                        .font(.heading6)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.primaryMediumBlue.opacity(0.2))

                Spacer()

                ForEach(responseOptions, id: \.self) { option in
                    Button {
                        onOptionSelected(option)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color("primaryMediumBlue").opacity(0.1))
                                .frame(height: 44)

                            Text(option)
                                .font(.bodyRegular)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.bottom, 16)
        }
    }
}

struct AdditionalNotesView: View {
    var body: some View {
        CardView(minHeight: 300) {
            VStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 24, height: 24)

                        Image("checkin-icon")
                    }

                    Text("Additional Notes")
                        .font(.heading6)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.primaryMediumBlue.opacity(0.2))

                Spacer()

                CustomTextAreaView()
            }
        }
    }
}

struct CustomTextAreaView: View {
    @State private var notes: String = ""

    var body: some View {
        TextField("Type your notes here...", text: $notes, axis: .vertical)
            .padding()
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18)

        PrimaryButton(
            title: "Save",
            size: .medium,
            systemImage: "",
            action: {}
        )
        .padding(.top, 8)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }
}

#Preview {
    AdditionalNotesView()
}
