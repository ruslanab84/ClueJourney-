import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Tokens

public enum PPColor {
    public static let paper = Color.ppDynamic(
        light: .init(red: 251, green: 241, blue: 221),
        dark: .init(red: 18, green: 24, blue: 32)
    )
    public static let surface = Color.ppDynamic(
        light: .init(red: 255, green: 248, blue: 232),
        dark: .init(red: 27, green: 36, blue: 48)
    )
    public static let ink = Color.ppDynamic(
        light: .init(red: 5, green: 43, blue: 87),
        dark: .init(red: 245, green: 241, blue: 232)
    )
    public static let travelBlue = Color.ppDynamic(
        light: .init(red: 6, green: 112, blue: 215),
        dark: .init(red: 26, green: 106, blue: 148)
    )
    public static let teal = Color.ppDynamic(
        light: .init(red: 7, green: 141, blue: 145),
        dark: .init(red: 91, green: 201, blue: 190)
    )
    public static let terracotta = Color.ppDynamic(
        light: .init(red: 216, green: 92, blue: 59),
        dark: .init(red: 255, green: 155, blue: 128)
    )
    public static let gold = Color.ppDynamic(
        light: .init(red: 246, green: 181, blue: 20),
        dark: .init(red: 247, green: 201, blue: 92)
    )
    public static let border = Color.ppDynamic(
        light: .init(red: 216, green: 195, blue: 160),
        dark: .init(red: 96, green: 91, blue: 82)
    )
    public static let moveViolet = Color.ppDynamic(
        light: .init(red: 110, green: 43, blue: 212),
        dark: .init(red: 168, green: 128, blue: 244)
    )
}

public enum PPSpacing {
    public static let xxSmall: CGFloat = 4
    public static let xSmall: CGFloat = 8
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let xLarge: CGFloat = 32
}

public enum PPRadius {
    public static let small: CGFloat = 10
    public static let control: CGFloat = 14
    public static let card: CGFloat = 14
}

public enum PPShadow {
    public static let color = PPColor.ink.opacity(0.10)
    public static let radius: CGFloat = 5
    public static let x: CGFloat = 0
    public static let y: CGFloat = 2
}

// MARK: - Surfaces

public struct PPPaperBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        ZStack {
            PPColor.paper

            if !reduceTransparency {
                RadialGradient(
                    colors: [
                        PPColor.surface.opacity(0.72),
                        PPColor.paper,
                        PPColor.gold.opacity(0.035),
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 720
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

public struct PPPostcardCard<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: PPRadius.card, style: .continuous)

        content
            .padding(PPSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PPColor.surface, in: shape)
            .overlay {
                shape.stroke(
                    PPColor.border.opacity(colorSchemeContrast == .increased ? 0.92 : 0.72),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
            }
            .shadow(
                color: PPShadow.color,
                radius: PPShadow.radius,
                x: PPShadow.x,
                y: PPShadow.y
            )
    }
}

// MARK: - Controls

public struct PPPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, PPSpacing.medium)
            .padding(.vertical, PPSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(PPColor.travelBlue, in: .rect(cornerRadius: PPRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: PPRadius.control, style: .continuous)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
                    .padding(2)
            }
            .shadow(color: PPColor.travelBlue.opacity(0.24), radius: 4, y: 2)
            .contentShape(.rect(cornerRadius: PPRadius.control))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == PPPrimaryButtonStyle {
    static var ppPrimary: PPPrimaryButtonStyle { PPPrimaryButtonStyle() }
}

public struct PPBackButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(PPColor.teal, in: .circle)
                .overlay { Circle().stroke(.white.opacity(0.5), lineWidth: 1) }
                .shadow(color: PPColor.ink.opacity(0.14), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back"))
    }
}

public struct PPMetricPill: View {
    private let symbol: String
    private let value: Int
    private let tint: Color

    public init(symbol: String, value: Int, tint: Color = PPColor.gold) {
        self.symbol = symbol
        self.value = max(0, value)
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: PPSpacing.xSmall) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(value, format: .number)
                .font(.headline.monospacedDigit())
                .foregroundStyle(PPColor.ink)
        }
        .padding(.horizontal, PPSpacing.small)
        .frame(minHeight: 38)
        .background(PPColor.surface, in: .capsule)
        .overlay { Capsule().stroke(PPColor.border.opacity(0.72), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

public enum PPStatusKind: Sendable {
    case active
    case completed
    case locked

    fileprivate var color: Color {
        switch self {
        case .active: PPColor.travelBlue
        case .completed: PPColor.teal
        case .locked: PPColor.terracotta
        }
    }

    fileprivate var systemImage: String {
        switch self {
        case .active: "location.fill"
        case .completed: "checkmark.circle.fill"
        case .locked: "lock.fill"
        }
    }
}

public struct PPStatusBadge: View {
    private let title: LocalizedStringKey
    private let kind: PPStatusKind

    public init(_ title: LocalizedStringKey, kind: PPStatusKind) {
        self.title = title
        self.kind = kind
    }

    public var body: some View {
        Label(title, systemImage: kind.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, PPSpacing.small)
            .padding(.vertical, PPSpacing.xSmall)
            .background(kind.color.opacity(0.14), in: .capsule)
            .overlay {
                Capsule().stroke(kind.color.opacity(0.24), lineWidth: 1)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

public struct PPRewardStars: View {
    @ScaledMetric(relativeTo: .body) private var starSize: CGFloat = 18

    private let earned: Int
    private let total: Int

    public init(earned: Int, total: Int = 3) {
        self.total = max(0, total)
        self.earned = min(max(0, earned), max(0, total))
    }

    public var body: some View {
        HStack(spacing: PPSpacing.xxSmall) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: index < earned ? "star.fill" : "star")
                    .foregroundStyle(
                        index < earned ? PPColor.gold : PPColor.ink.opacity(0.62)
                    )
            }
        }
        .font(.system(size: starSize, weight: .semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stars"))
        .accessibilityValue(Text("\(earned) of \(total)"))
    }
}

public struct PPMoveBadge: View {
    private let moveCount: Int

    public init(moveCount: Int) {
        self.moveCount = max(0, moveCount)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text("Moves".uppercased())
                .font(.caption2.weight(.black))

            Text(moveCount, format: .number)
                .font(.title3.bold().monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, PPSpacing.xSmall)
        .padding(.vertical, PPSpacing.xxSmall)
        .background(PPColor.moveViolet, in: .rect(cornerRadius: PPRadius.small))
        .overlay {
            RoundedRectangle(cornerRadius: PPRadius.small, style: .continuous)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Moves"))
        .accessibilityValue(Text(moveCount, format: .number))
    }
}

// MARK: - Dynamic Color

private struct PPRGB: Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Int, green: Int, blue: Int) {
        self.red = Double(red) / 255
        self.green = Double(green) / 255
        self.blue = Double(blue) / 255
    }
}

private extension Color {
    static func ppDynamic(light: PPRGB, dark: PPRGB) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(rgb: match == .darkAqua ? dark : light)
        })
        #else
        Color(red: light.red, green: light.green, blue: light.blue)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(rgb: PPRGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(rgb: PPRGB) {
        self.init(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
#endif
