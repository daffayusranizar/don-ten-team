//
//  Input.swift
//  team-10-c3
//
//  Created by Huy Tran on 27/05/26.
//
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum TextFieldSize {
    case large
    case medium
    case small

    var horizontalPadding: CGFloat {
        switch self {
        case .large: 24
        case .medium: 18
        case .small: 14
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .large: 18
        case .medium: 14
        case .small: 10
        }
    }

    var contentSpacing: CGFloat {
        switch self {
        case .large: 12
        case .medium: 10
        case .small: 8
        }
    }

    var font: Font {
        switch self {
        case .large:
            .system(size: 18, weight: .regular)

        case .medium:
            .system(size: 16, weight: .regular)

        case .small:
            .system(size: 14, weight: .regular)
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .large: 22
        case .medium: 18
        case .small: 16
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .large: 60
        case .medium: 50
        case .small: 40
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .large: 12
        case .medium: 10
        case .small: 8
        }
    }
}

// MARK: Primary Textfield
struct PrimaryTextField: View {
    @Binding var text: String
    var placeholder: String
    var size: TextFieldSize = .medium
    var systemImage: String? = nil
    var isFocused: FocusState<Bool>.Binding? = nil
    var action: () -> Void = {}

    @FocusState private var isFieldFocused: Bool

    private var showsClearButton: Bool {
        isFieldFocused && !text.isEmpty
    }

    private var externalFocusValue: Bool {
        isFocused?.wrappedValue ?? false
    }

    var body: some View {
        HStack(spacing: size.contentSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(.textPrimary)
                    .allowsHitTesting(false)
            }

            textInput
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .background(Capsule().fill(.uiSurface))
        .overlay {
            Capsule()
                .strokeBorder(
                    isFieldFocused ? Color.primaryMediumBlue : Color.clear,
                    lineWidth: 2
                )
        }
        .overlay {
            if !isFieldFocused {
                Capsule()
                    .fill(.clear)
                    .contentShape(Capsule())
                    .onTapGesture {
                        isFieldFocused = true
                    }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isFieldFocused)
        .onChange(of: isFieldFocused) { _, focused in
            syncFocusToExternal(focused)
        }
        .onChange(of: externalFocusValue) { _, externalFocused in
            guard isFocused != nil, isFieldFocused != externalFocused else { return }
            isFieldFocused = externalFocused
        }
    }

    private var textInput: some View {
        ZStack(alignment: .trailing) {
            TextField(placeholder, text: $text)
                .font(size.font)
                .foregroundStyle(.textPrimary)
                .tint(.textPrimary)
                .textFieldStyle(.plain)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($isFieldFocused)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, size.iconSize + 4)
                .onSubmit { action() }

            clearButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clearButton: some View {
        Button {
            isFieldFocused = false
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: size.iconSize))
                .foregroundStyle(.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear text")
        .opacity(showsClearButton ? 1 : 0)
        .allowsHitTesting(showsClearButton)
        .animation(.easeInOut(duration: 0.15), value: showsClearButton)
    }

    private func syncFocusToExternal(_ focused: Bool) {
        guard let isFocused, isFocused.wrappedValue != focused else { return }
        isFocused.wrappedValue = focused
    }
}

// MARK: Primary Date Input
struct PrimaryDateField: View {
    @Binding var date: Date?

    var placeholder: String
    var size: TextFieldSize = .medium
    var systemImage: String? = nil

    private var formattedDate: String {
        guard let date else { return placeholder }

        return date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { date = $0 }
        )
    }

    var body: some View {
        HStack(spacing: size.contentSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(.textPrimary)
            }

            Text(formattedDate)
                .font(size.font)
                .foregroundStyle(
                    date == nil
                    ? .textDisabled
                    : .textPrimary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.trailing, size.iconSize + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .background(Capsule().fill(.uiSurface))
        .allowsHitTesting(false)
        .background {
            DatePicker(
                "",
                selection: dateBinding,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .scaleEffect(x: 5, y: 1, anchor: .leading)
        }
        .clipShape(Capsule())
        .overlay(alignment: .trailing) {
            clearButton
                .padding(.trailing, size.horizontalPadding)
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    date != nil ? Color.primaryMediumBlue : Color.clear,
                    lineWidth: 2
                )
        }
        .animation(.easeInOut(duration: 0.15), value: date != nil)
    }

    private var clearButton: some View {
        Button {
            date = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: size.iconSize))
                .foregroundStyle(.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear date")
        .opacity(date == nil ? 0 : 1)
        .allowsHitTesting(date != nil)
    }
}

// MARK: Secondary Textfield
struct SecondaryTextField: View {
    @Binding var text: String
    var placeholder: String
    var size: TextFieldSize = .medium
    var systemImage: String? = nil
    var action: () -> Void = {}

    @FocusState private var isFieldFocused: Bool

    private var showsClearButton: Bool {
        isFieldFocused && !text.isEmpty
    }

    var body: some View {
        HStack(spacing: size.contentSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(.textPrimary)
                    .allowsHitTesting(false)
            }

            ZStack(alignment: .trailing) {
                TextField(placeholder, text: $text)
                    .font(size.font)
                    .foregroundStyle(.textPrimary)
                    .tint(.textPrimary)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($isFieldFocused)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, size.iconSize + 4)
                    .onSubmit { action() }

                Button {
                    isFieldFocused = false
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: size.iconSize))
                        .foregroundStyle(.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
                .opacity(showsClearButton ? 1 : 0)
                .allowsHitTesting(showsClearButton)
                .animation(.easeInOut(duration: 0.15), value: showsClearButton)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(.uiSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .strokeBorder(
                    isFieldFocused ? Color.primaryMediumBlue : Color.clear,
                    lineWidth: 2
                )
        }
        .overlay {
            if !isFieldFocused {
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(.clear)
                    .contentShape(RoundedRectangle(cornerRadius: size.cornerRadius))
                    .onTapGesture {
                        isFieldFocused = true
                    }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isFieldFocused)
    }
}

// MARK: Keyboard

extension View {
    /// Dismisses the keyboard when tapping outside text inputs. Ignores taps on text fields so focus stays instant.
    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissGestureInstaller())
    }
}

#if canImport(UIKit)
private struct KeyboardDismissGestureInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: UIView?
        private var recognizer: UITapGestureRecognizer?

        func installIfNeeded(from anchor: UIView) {
            guard !PreviewRuntime.isActive else { return }
            guard let host = anchor.parentViewController?.view else { return }
            guard hostView !== host else { return }
            uninstall()

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            host.addGestureRecognizer(tap)
            recognizer = tap
            hostView = host
        }

        func uninstall() {
            if let recognizer, let hostView {
                hostView.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            hostView = nil
        }

        @objc private func handleTap() {
            dismissKeyboard()
        }

        func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !Self.isTextInputView(touch.view)
        }

        private static func isTextInputView(_ view: UIView?) -> Bool {
            var current = view
            while let v = current {
                if v is UITextField || v is UITextView {
                    return true
                }
                if v is UIDatePicker {
                    return true
                }
                let typeName = String(describing: type(of: v))
                if typeName.contains("TextField")
                    || typeName.contains("TextInput")
                    || typeName.contains("UITextInput")
                    || typeName.contains("DatePicker") {
                    return true
                }
                current = v.superview
            }
            return false
        }
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        sequence(first: self as UIResponder, next: \.next)
            .compactMap { $0 as? UIViewController }
            .first
    }
}
#endif

private func dismissKeyboard() {
#if canImport(UIKit)
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
#endif
}

// MARK: Preview

private struct PrimaryInputPreviewScreen: View {
    @State private var largeText = ""
    @State private var mediumText = ""
    @State private var smallText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PrimaryTextField(
                    text: $largeText,
                    placeholder: "Type name...",
                    size: .large,
                    systemImage: "person.crop.circle.fill"
                )
                previewEcho("Large", value: largeText)

                PrimaryTextField(
                    text: $mediumText,
                    placeholder: "Type name...",
                    size: .medium,
                    systemImage: "person.crop.circle.fill"
                )
                previewEcho("Medium", value: mediumText)

                PrimaryTextField(
                    text: $smallText,
                    placeholder: "Type name...",
                    size: .small,
                    systemImage: "person.crop.circle.fill"
                )
                previewEcho("Small", value: smallText)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black)
        .preferredColorScheme(.light)
    }

    private func previewEcho(_ label: String, value: String) -> some View {
        Text("\(label): \"\(value.isEmpty ? " " : value)\"")
            .font(.caption)
            .foregroundStyle(.textSecondary)
    }
}

private struct PrimaryDateInputPreviewScreen: View {
    @State private var birthdate: Date? = nil

    var body: some View {
        VStack(spacing: 16) {
            PrimaryDateField(
                date: $birthdate,
                placeholder: "Insert Birthdate...",
                size: .large,
                systemImage: "calendar"
            )
            PrimaryDateField(
                date: $birthdate,
                placeholder: "Insert Birthdate...",
                size: .medium,
                systemImage: "calendar"
            )
            PrimaryDateField(
                date: $birthdate,
                placeholder: "Insert Birthdate...",
                size: .small,
                systemImage: "calendar"
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .preferredColorScheme(.light)
    }
}

private struct SecondaryInputPreviewScreen: View {
    @State private var largeText = ""
    @State private var mediumText = ""
    @State private var smallText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SecondaryTextField(
                    text: $largeText,
                    placeholder: "Type name...",
                    size: .large,
                    systemImage: "person.crop.circle.fill"
                )
                SecondaryTextField(
                    text: $mediumText,
                    placeholder: "Type name...",
                    size: .medium,
                    systemImage: "person.crop.circle.fill"
                )
                SecondaryTextField(
                    text: $smallText,
                    placeholder: "Type name...",
                    size: .small,
                    systemImage: "person.crop.circle.fill"
                )
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color.black)
        .preferredColorScheme(.light)
    }
}

#Preview("Primary Input") {
    PrimaryInputPreviewScreen()
}

#Preview("Primary Date Input") {
    PrimaryDateInputPreviewScreen()
}

#Preview("Secondary Input") {
    SecondaryInputPreviewScreen()
}

