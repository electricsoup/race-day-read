//
//  Theme.swift
//  Race Day Ready
//
//  Each kind of race weekend gets its own colors (the header, bib and accents follow it),
//  plus small shared pieces: chips, the bag pill, the quantity stepper, a wrapping row.
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    /// One color in light mode, another in dark mode.
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

struct Palette {
    var header: Color
    var accent: Color
    var gold: Color
    var wash: Color

    static func forTheme(_ key: String?) -> Palette {
        switch key ?? "" {
        case "marathon":
            return Palette(header: Color(hex: 0x12305F), accent: .adaptive(0x1E5AA8, 0x8DB8F2), gold: Color(hex: 0xF4C531), wash: .adaptive(0xEAF1FB, 0x16233A))
        case "princess":
            return Palette(header: Color(hex: 0x0D3F46), accent: .adaptive(0x11777F, 0x6AD3D2), gold: Color(hex: 0xE2B24A), wash: .adaptive(0xE5F3F2, 0x13292C))
        case "springtime":
            return Palette(header: Color(hex: 0x3A2A5C), accent: .adaptive(0x6A4FB0, 0xBCA8F4), gold: Color(hex: 0xF4A0BA), wash: .adaptive(0xF1EDFA, 0x221C33))
        case "wine-dine":
            return Palette(header: Color(hex: 0x4A1626), accent: .adaptive(0x8C2A3C, 0xEC93A2), gold: Color(hex: 0xD9AE55), wash: .adaptive(0xF7ECEE, 0x2B1B20))
        default:
            return Palette(header: Color(hex: 0x1F2B3A), accent: .adaptive(0x2F5A86, 0x9CC3E6), gold: Color(hex: 0xF08A5D), wash: .adaptive(0xEAF0F6, 0x17202B))
        }
    }

    static let themes: [(String, String)] = [
        ("wine-dine", "Food & wine fall weekend"), ("marathon", "Marathon weekend"), ("princess", "Princess weekend"),
        ("springtime", "Spring weekend"), ("other", "Other race weekend")
    ]
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.forTheme(nil) }
private struct CanEditKey: EnvironmentKey { static let defaultValue = true }

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
    var canEdit: Bool {
        get { self[CanEditKey.self] }
        set { self[CanEditKey.self] = newValue }
    }
}

enum PersonColor {
    private static let pairs: [(fg: Color, bg: Color)] = [
        (.adaptive(0xB4485C, 0xF29CA8), .adaptive(0xFBE9EC, 0x3B1E28)),
        (.adaptive(0x2F64A0, 0x8FBBEC), .adaptive(0xE4EDF8, 0x1A2D4A)),
        (.adaptive(0xB0561A, 0xF2A877), .adaptive(0xFBEBDD, 0x3D2414)),
        (.adaptive(0x127478, 0x79D6D6), .adaptive(0xDDF2F2, 0x123334)),
        (.adaptive(0x9A3E8C, 0xEBA3DE), .adaptive(0xF7E6F4, 0x3A1E36)),
        (.adaptive(0x5E6B12, 0xC9D77A), .adaptive(0xEEF1D6, 0x2C3014))
    ]
    static let sharedFG = Color.adaptive(0x2E7D5B, 0x74CFA3)
    static let sharedBG = Color.adaptive(0xE2F2EA, 0x16362A)
    static let matchFG = Color.adaptive(0x5B4BA6, 0xB7ADF2)
    static let matchBG = Color.adaptive(0xECE9F8, 0x2A2552)

    static func colors(for whoKey: String?, in trip: Trip?) -> (Color, Color) {
        switch whoKey ?? "" {
        case Who.shared: return (sharedFG, sharedBG)
        case Who.matching: return (matchFG, matchBG)
        default:
            let i = Int(trip?.person(whoKey)?.colorIndex ?? 0)
            let pair = pairs[((i % pairs.count) + pairs.count) % pairs.count]
            return (pair.fg, pair.bg)
        }
    }
}

enum StatusColor {
    static let buyFG = Color.adaptive(0x8A5A0B, 0xE8C47E)
    static let buyBG = Color.adaptive(0xF8ECD3, 0x3A2D12)
    static let makeFG = Color.adaptive(0x5B4BA6, 0xB7ADF2)
    static let makeBG = Color.adaptive(0xECE9F8, 0x2A2552)
}

extension Font {
    /// Condensed heavy type for headings, like a race bib.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

// MARK: - Small pieces

struct Tag: View {
    var text: String
    var fg: Color
    var bg: Color
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.4)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }
}

struct InfoChip: View {
    var text: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 9, weight: .semibold)) }
            Text(text).lineLimit(1)
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .foregroundStyle(.secondary)
        .background(Color(.secondarySystemFill), in: Capsule())
    }
}

struct WhoTag: View {
    var whoKey: String?
    var trip: Trip
    var body: some View {
        let c = PersonColor.colors(for: whoKey, in: trip)
        Tag(text: trip.whoLabel(whoKey), fg: c.0, bg: c.1)
    }
}

/// Tap to cycle Carry-on → Checked → Any bag.
struct BagPill: View {
    var bag: Bag
    var onChange: ((Bag) -> Void)?
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    var body: some View {
        Button {
            onChange?(bag.next)
        } label: {
            Text(bag.label.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.4)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .foregroundStyle(bag == .carry ? Color.white : (bag == .checked ? Color.primary : Color.secondary))
                .background {
                    switch bag {
                    case .carry: Capsule().fill(palette.accent)
                    case .checked: Capsule().fill(Color(.tertiarySystemFill)).overlay(Capsule().stroke(Color.secondary, lineWidth: 1))
                    case .any: Capsule().strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    }
                }
        }
        .buttonStyle(.borderless)
        .disabled(onChange == nil || !canEdit)
        .accessibilityLabel("Packed in: \(bag.label). Tap to change.")
    }
}

struct QtyStepper: View {
    var qty: Int
    var onChange: (Int) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    var body: some View {
        HStack(spacing: 0) {
            Button { onChange(qty - 1) } label: {
                Image(systemName: "minus").frame(width: 26, height: 26)
            }
            .disabled(qty <= 1 || !canEdit)
            Text("\(qty)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .frame(minWidth: 20)
                .foregroundStyle(qty > 1 ? palette.accent : .primary)
            Button { onChange(qty + 1) } label: {
                Image(systemName: "plus").frame(width: 26, height: 26)
            }
            .disabled(qty >= 99 || !canEdit)
        }
        .font(.system(size: 12, weight: .semibold))
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .overlay(Capsule().stroke(qty > 1 ? palette.accent : Color(.separator), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("How many: \(qty)")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: onChange(qty + 1)
            case .decrement: onChange(max(1, qty - 1))
            @unknown default: break
            }
        }
    }
}

/// Lays children out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Undo banner

@MainActor
final class ToastCenter: ObservableObject {
    struct Toast: Identifiable {
        let id = UUID()
        var message: String
        var actionLabel: String?
        var action: (() -> Void)?
    }
    @Published var current: Toast?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        let toast = Toast(message: message, actionLabel: actionLabel, action: action)
        current = toast
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: action == nil ? 3_000_000_000 : 6_000_000_000)
            guard !Task.isCancelled else { return }
            if self?.current?.id == toast.id { self?.current = nil }
        }
    }
}

struct ToastOverlay: View {
    @ObservedObject var center: ToastCenter
    var body: some View {
        VStack {
            Spacer()
            if let toast = center.current {
                HStack(spacing: 14) {
                    Text(toast.message).font(.subheadline).lineLimit(2)
                    if let label = toast.actionLabel, let action = toast.action {
                        Button(label) {
                            action()
                            center.current = nil
                        }
                        .font(.subheadline.bold())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: center.current?.id)
    }
}

/// Icon + title that never wraps or drops its title (a plain Label can collapse to icon-only in tight rows).
struct IconText: View {
    let title: String
    let icon: String
    init(_ title: String, _ icon: String) { self.title = title; self.icon = icon }
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(title)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
