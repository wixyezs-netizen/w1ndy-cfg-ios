import NetworkExtension
import SwiftUI

/// Главный экран: логотип, статус, кнопка «АКТИВИРОВАТЬ», плашки внизу.
struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.openURL) private var openURL

    let onRestart: (Step) -> Void

    @State private var showMenu = false
    @State private var showSettings = false
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        Button { showMenu = true } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 24, weight: .medium))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Меню")
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 24, weight: .regular))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Настройки")
                    }
                    .foregroundColor(.white)

                    Spacer(minLength: 24)

                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width * 0.84)
                    StatusLine()
                        .padding(.top, 10)
                    ConnectButton(status: vpn.status) { toggle() }
                        .padding(.top, 26)
                    if let message {
                        Text(message)
                            .font(mono(14))
                            .foregroundColor(.w1Red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                    }

                    Spacer(minLength: 28)

                    VStack(spacing: 14) {
                        GlowPill(icon: "paperplane", title: "Наш Telegram-канал", handle: "@windytoptop") { openURL(W1.channelURL) }
                        GlowPill(icon: "bolt.fill", title: "LitEnergy VPN", handle: "@VPN_LitEnergy_bot") { openURL(W1.botURL) }
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(minHeight: geo.size.height)
            }
        }
        .task {
            // проверка доступа и свежий конфиг при открытии
            guard state.mode == .vpn, state.activated else { return }
            do {
                try await state.refresh()
            } catch let error as ApiError where error.code == 403 || error.code == 401 {
                onRestart(.key)
            } catch {}
        }
        .onChange(of: vpn.lastError) { value in
            if let value { message = value }
        }
        .sheet(isPresented: $showMenu) { menuSheet }
        .sheet(isPresented: $showSettings) { settingsSheet }
    }

    private func toggle() {
        switch vpn.status {
        case .connected, .connecting, .reasserting:
            vpn.disconnect()
        case .disconnecting:
            break
        default:
            Task { await connect() }
        }
    }

    private func connect() async {
        message = nil
        if state.mode == .vpn, state.vpnConfig == nil {
            do {
                try await state.refresh()
            } catch let error as ApiError {
                if error.code == 403 || error.code == 401 {
                    onRestart(.key)
                    return
                }
                message = error.message
                return
            } catch {
                message = error.localizedDescription
                return
            }
        }
        guard let config = state.currentConfig() else {
            message = "Нет конфигурации. Введите ключ ещё раз."
            return
        }
        await vpn.connect(config: config)
        if let error = vpn.lastError { message = error }
    }

    // MARK: - шторки

    private var menuSheet: some View {
        sheetBody(title: "Меню") {
            SheetItem(title: "Наш Telegram-канал", subtitle: "Новости и обновления · @windytoptop") {
                showMenu = false
                openURL(W1.channelURL)
            }
            SheetItem(title: "LitEnergy VPN", subtitle: "Быстрый и стабильный VPN · @VPN_LitEnergy_bot") {
                showMenu = false
                openURL(W1.botURL)
            }
            SheetItem(title: "Последняя версия", subtitle: "Страница загрузки приложения") {
                showMenu = false
                openURL(W1.releasesURL)
            }
        }
    }

    private var settingsSheet: some View {
        sheetBody(title: "Настройки") {
            SheetItem(title: "Сменить режим", subtitle: "Сейчас: " + (state.mode == .dns ? "только DNS" : "VPN")) {
                showSettings = false
                onRestart(.mode)
            }
            if state.mode == .vpn {
                SheetItem(title: "Обновить конфигурацию", subtitle: busy ? "Загрузка…" : "Скачать актуальные настройки с сервера") {
                    guard !busy else { return }
                    busy = true
                    Task {
                        do {
                            try await state.refresh()
                            message = vpn.isConnected ? "Конфигурация обновлена. Переподключитесь, чтобы применить." : nil
                        } catch let error as ApiError where error.code == 403 || error.code == 401 {
                            showSettings = false
                            onRestart(.key)
                        } catch {
                            message = error.localizedDescription
                        }
                        busy = false
                        showSettings = false
                    }
                }
                SheetItem(title: "Ввести другой ключ", subtitle: "Текущее подключение будет удалено с телефона") {
                    showSettings = false
                    if vpn.isConnected || vpn.isBusy { vpn.disconnect() }
                    state.reset()
                    onRestart(.key)
                }
            } else {
                SheetItem(title: "Выбрать другой DNS", subtitle: "Сейчас: \(state.dnsServer)") {
                    showSettings = false
                    onRestart(.dns)
                }
            }
        }
    }

    private func sheetBody<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                Text(title).font(mono(20, .bold)).foregroundColor(.white).padding(.vertical, 8)
                content()
                Text("W1NDY CFG · версия \(W1.version)")
                    .font(mono(13)).foregroundColor(.w1Dim)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color.w1Sheet.ignoresSafeArea())
        .mediumSheet()
        .preferredColorScheme(.dark)
    }
}

struct StatusLine: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var vpn: VPNController

    private var title: String {
        switch vpn.status {
        case .connected: return "РЕЖИМ ВКЛЮЧЕН"
        case .connecting, .reasserting: return "ПОДКЛЮЧАЕМСЯ…"
        case .disconnecting: return "ОТКЛЮЧАЕМСЯ…"
        default: return "РЕЖИМ ВЫКЛЮЧЕН"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(vpn.isConnected ? Color.w1BlueLight : (vpn.isBusy ? Color.w1Muted : Color.w1Chrome))
                    .frame(width: 9, height: 9)
                Text(title)
                    .font(mono(17))
                    .tracking(1)
                    .foregroundColor(vpn.isConnected ? .w1BlueLight : .white)
            }
            if vpn.isConnected, let since = vpn.connectedDate {
                TimelineView(.periodic(from: Date(), by: 1)) { context in
                    let s = max(0, Int(context.date.timeIntervalSince(since)))
                    (Text("В сети: ").foregroundColor(.w1Muted)
                        + Text(String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)).foregroundColor(.w1BlueLight).bold())
                        .font(mono(15))
                }
            } else {
                (Text("Режим: ").foregroundColor(.w1Muted)
                    + Text(state.mode == .dns ? "DNS \(state.dnsServer)" : "VPN").foregroundColor(.w1BlueLight).bold())
                    .font(mono(15))
            }
        }
    }
}
