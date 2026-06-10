//
//  SuggestionFlowView.swift
//  team-10-c3
//

import SwiftUI

enum SuggestionStep {
    case initial
    case response
    case notes
}

struct SuggestionFlowView: View {
    @Environment(\.sessionAnalysisStore) private var sessionAnalysisStore

    let childId: UUID
    let weekKey: String
    let suggestionText: String
    let followUpOptions: [String]
    var onComplete: () -> Void = {}

    @State private var currentStep: SuggestionStep = .initial
    @State private var tried = false
    @State private var followUpSelection: String?
    @State private var note = ""
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        VStack {
            switch currentStep {
            case .initial:
                TrySuggestionView(
                    suggestionText: suggestionText,
                    onYesTapped: {
                        tried = true
                        withAnimation { currentStep = .response }
                    },
                    onNoTapped: {
                        tried = false
                        saveResponse(followUpSelection: nil, note: nil)
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .response:
                DoTheSuggestionView(
                    responseOptions: followUpOptions,
                    onOptionSelected: { selection in
                        followUpSelection = selection
                        withAnimation { currentStep = .notes }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .notes:
                AdditionalNotesView(
                    note: $note,
                    isSaving: isSaving,
                    onSave: {
                        saveResponse(followUpSelection: followUpSelection, note: note)
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .alert("Could Not Save", isPresented: saveErrorPresented) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { isPresented in
                if !isPresented {
                    saveError = nil
                }
            }
        )
    }

    private func saveResponse(followUpSelection: String?, note: String?) {
        guard let sessionAnalysisStore else {
            saveError = "Saving is unavailable right now."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try sessionAnalysisStore.saveSuggestionTry(
                childId: childId,
                weekKey: weekKey,
                suggestion: suggestionText,
                tried: tried,
                followUpOptions: followUpOptions,
                followUpSelection: followUpSelection,
                note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            onComplete()
        } catch {
            saveError = error.localizedDescription
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

                    Text("This week's suggestion")
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
    let responseOptions: [String]
    var onOptionSelected: (String) -> Void

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
    @Binding var note: String
    var isSaving: Bool
    var onSave: () -> Void

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

                CustomTextAreaView(
                    note: $note,
                    isSaving: isSaving,
                    onSave: onSave
                )
            }
        }
    }
}

struct CustomTextAreaView: View {
    @Binding var note: String
    var isSaving: Bool
    var onSave: () -> Void

    var body: some View {
        TextField("Type your notes here...", text: $note, axis: .vertical)
            .padding()
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18)

        PrimaryButton(
            title: isSaving ? "Saving..." : "Save",
            size: .medium,
            systemImage: "",
            isDisabled: isSaving,
            action: onSave
        )
        .padding(.top, 8)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    AdditionalNotesView(note: .constant(""), isSaving: false, onSave: {})
}
