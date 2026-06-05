//
//  ParentPinSetupView.swift
//  team-10-c3
//
//  Created by Huy Tran on 05/06/26.
//

import SwiftUI

struct ParentPinSetupView: View {
    @Binding var data: OnboardingData
    
    // pin entering related data
    @State private var unconfirmedPin: String = ""
    @State private var confirmedPin: String = ""
    @State private var wrongPinEntered: Bool = false
    private var isConfirming: Bool {
        unconfirmedPin.count == 6
    }
    private var pinEntered: Bool {
        (unconfirmedPin.count == 6 && confirmedPin.count == 6) &&
        confirmedPin.elementsEqual(unconfirmedPin)
    }
    
    // numpad data
    let numbers: [String] = [
        "1", "2", "3",
        "4", "5", "6",
        "7", "8", "9",
        "",  "0", "⌫"
    ]
    
    @State private var goToStepTwo = false

    var body: some View {
        VStack(spacing: 15) {
            Text(isConfirming ? "Confirm PIN" : "Create your parent PIN")
                .font(.system(size: 20, weight: .semibold))
            
            // pin entering
            VStack {
                Spacer()
                
                pinDotsView()
                
                Spacer()

                numpadView()
            }
            
            Text("You can change this PIN anytime in Settings. \n Use Face ID as an alternative.")
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            PrimaryButton(
                title: "Continue",
                size: .large,
                systemImage: nil,
                isDisabled: !pinEntered
            ) {
                goToStepTwo = true
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Step 1 of 5")
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToStepTwo) {
            StepTwoView(data: $data)
        }
    }
    
    private func pinDotsView () -> some View {
        HStack(spacing: 15) {
            ForEach(0..<6) { index in
                ZStack {
                    Circle()
                        .fill(.black)
                        .frame(width: 20, height: 20)
                    
                    isConfirming
                    ? // pin count for confirmation pin
                    Circle()
                        .fill(index < confirmedPin.count ? .black : .white)
                        .frame(width: 17, height: 17)
                    : // pin count for unconfirmed pin
                    Circle()
                        .fill(index < unconfirmedPin.count ? .black : .white)
                        .frame(width: 17, height: 17)
                }
            }
        }
        .alert("PINs don't match", isPresented: $wrongPinEntered) {
            Button("Try Again") {
                wrongPinEntered = false
                unconfirmedPin = ""
                confirmedPin = ""
            }
        } message: {
            Text("Please enter the same PIN twice.")
        }
    }
    
    private func numpadView () -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 3),
            spacing: 10
        ) {
            ForEach(numbers, id: \.self) { number in
                Button {
                    handleTap(number)
                } label: {
                    let letters = threeLetters(number)
                    VStack {
                        Text(number)
                            .font(.title)
                        
                        if !letters.isEmpty {
                            Text(threeLetters(number))
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((number.isEmpty || number.elementsEqual("⌫")) ? .clear : .white)
                    )
                }
                .disabled(number.isEmpty)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.uiSurfaceElevated)
        )
    }
    
    private func handleTap(_ value: String) {
        // confirming pin
        if isConfirming {
            if value == "⌫" {
                if !confirmedPin.isEmpty {
                    confirmedPin.removeLast()
                } else {
                    unconfirmedPin = "" // goes back to initial pin entering
                }
            } else if confirmedPin.count < 6 {
                confirmedPin.append(value)
                
                // handles incorrect pins
                if confirmedPin.count == 6 {
                    if confirmedPin != unconfirmedPin {
                        wrongPinEntered = true
                    }
                }
            }
        }
        
        // entering pin for first time
        else {
            if value == "⌫" {
                if !unconfirmedPin.isEmpty {
                    unconfirmedPin.removeLast()
                }
            } else if unconfirmedPin.count < 6 {
                unconfirmedPin.append(value)
            }
        }
    }
    
    private func threeLetters (_ val: String) -> String {
        switch val {
        case "2":
            return "ABC"
        case "3":
            return "DEF"
        case "4":
            return "GHI"
        case "5":
            return "JKL"
        case "6":
            return "MNO"
        case "7":
            return "PQRS"
        case "8":
            return "TUV"
        case "9":
            return "WXYZ"
        default:
            return ""
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
