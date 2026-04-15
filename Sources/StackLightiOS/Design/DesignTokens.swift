import SwiftUI

/// Centralised design tokens for the iOS target. Everything else should read
/// colors/fonts/spacing from here so we can tune the look in one place.
enum DesignTokens {

    // MARK: Palette

    enum Palette {
        /// Near-black backdrop used by the Home screen, matching the dark
        /// background of the reference smart-home mockup.
        static let background = Color(red: 0.04, green: 0.05, blue: 0.08)
        /// Slightly lifted surface used behind grouped forms/sheets.
        static let surface = Color(red: 0.09, green: 0.10, blue: 0.13)
        /// 1pt hairline between glass elements.
        static let hairline = Color.white.opacity(0.08)

        // Status tints — slightly desaturated for the glass aesthetic.
        static let success  = Color(red: 0.27, green: 0.83, blue: 0.55)
        static let failure  = Color(red: 0.98, green: 0.32, blue: 0.36)
        static let building = Color(red: 1.00, green: 0.64, blue: 0.20)
        static let queued   = Color(red: 0.63, green: 0.64, blue: 0.68)
        static let review   = Color(red: 0.33, green: 0.66, blue: 1.00)
    }

    // MARK: Radii

    enum Radius {
        static let sm:    CGFloat = 14
        static let md:    CGFloat = 22
        static let lg:    CGFloat = 28
        static let hero:  CGFloat = 36
        static let pill:  CGFloat = 999
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Typography

    enum Typography {
        /// Large condensed numerals for the hero card readouts (e.g. "58").
        static func display(size: CGFloat = 56) -> Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }
        /// Medium display numerals used inside chips.
        static func numeric(size: CGFloat = 22) -> Font {
            .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
        }
        static let sectionTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let cardTitle    = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let chipLabel    = Font.system(size: 13, weight: .medium,   design: .rounded)
        static let caption      = Font.system(size: 11, weight: .medium,   design: .rounded)
    }

    // MARK: Motion

    enum Motion {
        /// Should we respect Reduce Motion? Shader animations should pause when true.
        static var reduceMotion: Bool {
            UIAccessibility.isReduceMotionEnabled
        }
        /// Should we drop the shader backdrop entirely for contrast users?
        static var reduceTransparency: Bool {
            UIAccessibility.isReduceTransparencyEnabled
        }
    }
}
