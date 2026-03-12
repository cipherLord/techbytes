import SwiftUI

extension Color {
    static let darkVoid = Color(red: 21/255, green: 20/255, blue: 25/255)
    static let liquidLava = Color(red: 245/255, green: 110/255, blue: 15/255)
    static let gluonGrey = Color(red: 27/255, green: 27/255, blue: 30/255)
    static let slateGrey = Color(red: 38/255, green: 38/255, blue: 38/255)
    static let dustyGrey = Color(red: 135/255, green: 135/255, blue: 135/255)
    static let snow = Color(red: 251/255, green: 251/255, blue: 251/255)

    static let lavaEmber = Color(red: 200/255, green: 80/255, blue: 10/255)
    static let lavaGlow = Color(red: 255/255, green: 140/255, blue: 50/255)
}

extension ShapeStyle where Self == Color {
    static var cardBackground: Color { .gluonGrey }
    static var surfaceBackground: Color { .slateGrey }
    static var primaryAccent: Color { .liquidLava }
    static var primaryText: Color { .snow }
    static var secondaryText: Color { .dustyGrey }
    static var appBackground: Color { .darkVoid }

    static var liquidLava: Color { Color.liquidLava }
    static var darkVoid: Color { Color.darkVoid }
    static var gluonGrey: Color { Color.gluonGrey }
    static var slateGrey: Color { Color.slateGrey }
    static var dustyGrey: Color { Color.dustyGrey }
    static var snow: Color { Color.snow }
}

extension LinearGradient {
    static var lavaGradient: LinearGradient {
        LinearGradient(
            colors: [.lavaEmber, .liquidLava, .lavaGlow],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var subtleCardGlow: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.04), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
