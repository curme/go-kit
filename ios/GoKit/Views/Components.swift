import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Palette {
    static let background = Color(red: 0.965, green: 0.961, blue: 0.938)
    static let ink = Color(red: 0.16, green: 0.23, blue: 0.19)
    static let green = Color(red: 0.21, green: 0.36, blue: 0.28)
    static let sage = Color(red: 0.90, green: 0.93, blue: 0.86)
    static let muted = Color(red: 0.40, green: 0.46, blue: 0.38)
    static let amber = Color(red: 0.66, green: 0.35, blue: 0.19)
    static let paper = Color(red: 1, green: 0.995, blue: 0.977)
}

extension View {
    func card() -> some View {
        self.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.green.opacity(0.10), lineWidth: 1))
    }
    func pageStyle() -> some View {
        self.background(Palette.background).foregroundStyle(Palette.ink)
    }
    func inlineTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage = "arrow.right"
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(disabled ? Palette.muted.opacity(0.3) : Palette.green, in: RoundedRectangle(cornerRadius: 15))
                .foregroundStyle(.white)
        }.buttonStyle(.plain).disabled(disabled)
    }
}

struct CoachNote: View {
    let text: String
    var isError = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isError ? "arrow.uturn.backward" : "lightbulb")
                .padding(.top, 3).accessibilityHidden(true)
            Text(text).font(.subheadline).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(isError ? Palette.amber : Palette.green)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? Color.orange.opacity(0.09) : Palette.sage.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).font(.caption.weight(.semibold)).tracking(3).foregroundStyle(Palette.muted)
            Text(title).font(.system(.largeTitle, design: .serif).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
enum TouchFeedback {
    static func move() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
