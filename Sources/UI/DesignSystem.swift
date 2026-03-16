import SwiftUI

// MARK: - Design System / Theme

extension Color {
    // Background
    static let bg = Color("AppBackground", bundle: nil)
    static let secondaryBg = Color("SecondaryBackground", bundle: nil)
    static let accent = Color.accentColor

    // Fallbacks for when asset catalog not loaded
    static var appBg: Color { Color(NSColor.windowBackgroundColor) }
    static var appSecondaryBg: Color { Color(NSColor.controlBackgroundColor) }
}

// MARK: - Color overrides using NSColor for reliable dark/light adaptation

extension Color {
    // Override bg / secondaryBg using computed properties instead of named colors
    // (Named colors require the asset catalog to have them defined)
}

// MARK: - Typography helpers

extension Font {
    static func monoCaption() -> Font { .system(.caption, design: .monospaced) }
    static func monoBody() -> Font { .system(.body, design: .monospaced) }
}

// MARK: - Asset Catalog Placeholder
// Note: In Xcode, add "AppBackground" and "SecondaryBackground" color sets to Assets.xcassets
// with dark/light mode variants. Until then, Color("AppBackground") falls back to nil safely.

// MARK: - Rounded card background

struct CardBackground: ViewModifier {
    var padding: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 12) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

// MARK: - Badge

struct ActionBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
