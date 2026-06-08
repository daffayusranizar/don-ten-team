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
    // 2. Track the current step
    @State private var currentStep: SuggestionStep = .initial
    
    var body: some View {
        // 3. Swap the views based on the state
        VStack {
            switch currentStep {
            case .initial:
                TrySuggestionView(
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
                    onOptionSelected: { selectedOption in
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
    // Add these action properties
    var onYesTapped: () -> Void
    var onNoTapped: () -> Void
    
    var body: some View {
        CardView(width: 346, height: 300) {
            VStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 24, height: 24)

                        Image("checkin-icon")
                    }

                    Text("Last week’s suggestion")
                        .font(.heading6)


                    Spacer()

                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.primaryMediumBlue.opacity(0.2))
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("primaryMediumBlue").opacity(0.1))
                        .frame(width: 307, height: 90)
                        .padding(.vertical, 8)
                    Text("“Watch one video together and ask what he found interesting.”")
                        .font(.bodyRegular)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(width: 200)
                }
                
                HStack{
                    Text("Did you try it?")
                        .font(.bodyRegular)
                        .padding(.horizontal, 50)
                    Spacer()
                }

                Button {
                    onYesTapped()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("primaryMediumBlue").opacity(0.1))
                            .frame(width: 307, height: 32)
                        
                        Text("Yes, we did it")
                            .font(.bodyRegular)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .frame(width: 200)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    onNoTapped()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("primaryMediumBlue").opacity(0.1))
                            .frame(width: 307, height: 32)
                        
                        Text("Not this time")
                            .font(.bodyRegular)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .frame(width: 200)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DoTheSuggestionView: View {
    var onOptionSelected: (String) -> Void
    
    let options = [
        "Opened up and talked",
        "Enjoy it, not much talking",
        "Led to a longer conversation",
        "Didn't want to"
    ]
    
    var body: some View {
        CardView(width: 346, height: 300) {
            VStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 24, height: 24)

                        Image("checkin-icon")
                    }
                    Text("How did Raka respond?")
                        .font(.heading6)


                    Spacer()

                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(.primaryMediumBlue.opacity(0.2))
                
                Spacer()
                
                ForEach(options, id: \.self) { option in
                    Button {
                        onOptionSelected(option) // <--- Triggers the change to Notes!
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color("primaryMediumBlue").opacity(0.1))
                                .frame(width: 307, height: 44)
                            
                            Text(option)
                                .font(.bodyRegular)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .frame(width: 200)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
    }
}

struct AdditionalNotesView: View {
    var body: some View {
        CardView(width: 346, height: 300){
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
            
            .frame(width: 340, height: 160, alignment: .topLeading)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        
        PrimaryButton(
            title: "Save",
            size: .medium,
            systemImage: "",
            action: {}
        )
        .padding(.top, 8)
        .padding(.horizontal, 30)
        
        Spacer()
    }
}

#Preview{
    AdditionalNotesView()
}

