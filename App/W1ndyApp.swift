import NetworkExtension
import SwiftUI

@main
struct W1ndyApp: App {
    @StateObject private var state = AppState()
    @StateObject private var vpn = VPNController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(vpn)
                .preferredColorScheme(.dark)
        }
    }
}

enum Step: Hashable {
    case mode, key, dns, telegram
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var vpn: VPNController
    @State private var startStep: Step = .mode

    var body: some View {
        Group {
            if state.onboarded {
                HomeView(onRestart: { step in
                    if vpn.isConnected || vpn.isBusy { vpn.disconnect() }
                    startStep = step
                    state.onboarded = false
                })
            } else {
                OnboardingView(initial: startStep)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SpaceBackground())
    }
}

/// Звёздный фон на весь экран (не влияет на размеры содержимого).
struct SpaceBackground: View {
    var body: some View {
        GeometryReader { geo in
            Image("Space")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

// MARK: - Палитра «космос»

extension Color {
    static let w1Blue = Color(red: 0.184, green: 0.525, blue: 1.0)
    static let w1BlueLight = Color(red: 0.31, green: 0.64, blue: 1.0)
    static let w1Chrome = Color(red: 0.86, green: 0.90, blue: 0.95)
    static let w1Muted = Color(red: 0.71, green: 0.75, blue: 0.83)
    static let w1Dim = Color(red: 0.43, green: 0.48, blue: 0.57)
    static let w1Red = Color(red: 1.0, green: 0.36, blue: 0.36)
    static let w1Glass = Color(red: 0.024, green: 0.04, blue: 0.08).opacity(0.75)
    static let w1Sheet = Color(red: 0.04, green: 0.067, blue: 0.125)
    static let w1Border = Color(red: 0.24, green: 0.545, blue: 1.0).opacity(0.38)
}

func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}

extension View {
    @ViewBuilder
    func mediumSheet() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large])
        } else {
            self
        }
    }
}
