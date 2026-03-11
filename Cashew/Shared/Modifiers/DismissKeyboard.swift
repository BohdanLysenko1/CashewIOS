import SwiftUI

// MARK: - Private helper

private func resignFirstResponder() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Keyboard Dismiss Modifier

struct DismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture { resignFirstResponder() }
    }
}

// MARK: - ScrollView with Keyboard Dismiss

struct ScrollViewDismissesKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - View Extension

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardModifier())
    }

    func dismissKeyboardOnScroll() -> some View {
        modifier(ScrollViewDismissesKeyboard())
    }

    func hideKeyboard() {
        resignFirstResponder()
    }
}

// MARK: - Toolbar Keyboard Dismiss Button

struct KeyboardDismissToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { resignFirstResponder() }
                }
            }
    }
}

extension View {
    func keyboardDismissToolbar() -> some View {
        modifier(KeyboardDismissToolbar())
    }
}
