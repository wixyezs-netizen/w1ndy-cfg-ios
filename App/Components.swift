import NetworkExtension
import SwiftUI

/// Большая круглая кнопка с хромированным кольцом и синим свечением.
struct ConnectButton: View {
    let status: NEVPNStatus
    let action: () -> Void
    @State private var pulse = false

    private var on: Bool { status == .connected }
    private var busy: Bool { status == .connecting || status == .disconnecting || status == .reasserting }

    private var label: String {
        switch status {
        case .connected: return "ОТКЛЮЧИТЬ"
        case .connecting, .reasserting: return "ПОДКЛЮЧЕНИЕ"
        case .disconnecting: return "ОТКЛЮЧЕНИЕ"
        default: return "АКТИВИРОВАТЬ"
        }
    }

    private var glow: Double {
        if on { return pulse ? 1.0 : 0.65 }
        if busy { return pulse ? 0.85 : 0.25 }
        return 0.35
    }

    private var ringColors: [Color] {
        on
            ? [.w1BlueLight, Color(red: 0.62, green: 0.82, blue: 1.0), .w1Blue, Color(red: 0.62, green: 0.82, blue: 1.0), .w1BlueLight]
            : [.white, Color(red: 0.56, green: 0.66, blue: 0.79), Color(red: 0.37, green: 0.66, blue: 1.0), .white, Color(red: 0.56, green: 0.66, blue: 0.79), .white]
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.w1Blue.opacity(0.55 * glow), Color.w1Blue.opacity(0.12 * glow), .clear],
                        center: .center, startRadius: 70, endRadius: 132
                    ))
                    .frame(width: 264, height: 264)
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.043, green: 0.078, blue: 0.141), Color(red: 0.008, green: 0.012, blue: 0.03)],
                        center: .center, startRadius: 0, endRadius: 107
                    ))
                    .frame(width: 214, height: 214)
                    .overlay(
                        Circle().strokeBorder(AngularGradient(gradient: Gradient(colors: ringColors), center: .center), lineWidth: on ? 3 : 2.5)
                    )
                    .shadow(color: Color.w1Blue.opacity(on ? 0.9 : 0.45), radius: on ? 18 : 10)
                VStack(spacing: 12) {
                    Image(systemName: "power")
                        .font(.system(size: 70, weight: .light))
                        .foregroundStyle(on
                            ? AnyShapeStyle(Color.w1BlueLight)
                            : AnyShapeStyle(LinearGradient(colors: [.white, Color(red: 0.6, green: 0.68, blue: 0.79)], startPoint: .top, endPoint: .bottom)))
                    Text(label)
                        .font(mono(16, .medium))
                        .tracking(1)
                        .foregroundColor(on ? .w1BlueLight : .white)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(status == .disconnecting)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// Стеклянная плашка с синей светящейся рамкой.
struct GlowPill: View {
    let icon: String
    let title: String
    let handle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundColor(.w1Chrome)
                    .frame(width: 28)
                (Text(handle.isEmpty ? title : title + " ").foregroundColor(.white) + Text(handle).foregroundColor(.w1BlueLight))
                    .font(mono(15))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.043, green: 0.106, blue: 0.212).opacity(0.85), Color(red: 0.016, green: 0.04, blue: 0.086).opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.w1Blue, Color(red: 0.55, green: 0.76, blue: 1.0), .w1Blue], startPoint: .leading, endPoint: .trailing), lineWidth: 1.5)
            )
            .shadow(color: Color.w1Blue.opacity(0.45), radius: 10)
        }
        .buttonStyle(.plain)
    }
}

struct ChoiceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.08, green: 0.13, blue: 0.23)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(mono(18, .bold)).foregroundColor(.white)
                    Text(subtitle).font(mono(13)).foregroundColor(.w1Muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundColor(.w1Dim)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.w1Glass))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.w1Border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(mono(16, .bold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundColor(enabled ? .white : .w1Dim)
            .background(RoundedRectangle(cornerRadius: 16).fill(enabled ? Color.w1Blue : Color(red: 0.08, green: 0.13, blue: 0.23)))
            .shadow(color: Color.w1Blue.opacity(enabled ? 0.45 : 0), radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || busy)
    }
}

struct SheetItem: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(mono(16, .semibold)).foregroundColor(.white)
                Text(subtitle).font(mono(13)).foregroundColor(.w1Muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(mono(26, .heavy)).foregroundColor(.white)
            Text(subtitle).font(mono(14)).foregroundColor(.w1Muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}
