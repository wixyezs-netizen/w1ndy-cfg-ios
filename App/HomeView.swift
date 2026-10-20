import NetworkExtension
import SwiftUI

/// Главный экран в стиле мини-приложения: шапка, карточка статуса, кнопка подключения, ссылки.
struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.openURL) private var openURL

    let onRestart: (Step) -> Void

    @State private var showMenu = false
    @State private var showSettings = false
    @State private var showDiagnostics = false
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        RoundIconButton(icon: "line.3.horizontal", label: "Меню") { showMenu = true }
                        Spacer()
                        RoundIconButton(icon: "gearshape", label: "Настройки") { showSettings = true }
                    }

                    BrandHeader()
                        .padding(.top, 6)

                    StatusCard(onChangeMode: { onRestart(.mode) })
                        .padding(.top, 26)

                    Spacer(minLength: 22)

                    ConnectButton(status: vpn.status) { toggle() }

                    if let message {
                        Text(message)
                            .font(ui(14))
                            .foregroundColor(.w1Red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                            .padding(.horizontal, 6)
                    }

                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        LinkCard(icon: "paperplane.fill", title: "Наш Telegram-канал", subtitle: "@windytoptop") { openURL(W1.channelURL) }
                        LinkCard(icon: "bolt.fill", title: "LitEnergy VPN", subtitle: "@VPN_LitEnergy_bot") { openURL(W1.botURL) }
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(minHeight: geo.size.height)
            }
        }
        .task {
            // проверка доступа, срок и свежий конфиг при открытии
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
        .alert("Диагностика VPN", isPresented: $showDiagnostics) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(VPNDiagnostics.current().report)
        }
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
            SheetItem(title: "Купить или продлить ключ", subtitle: "Бот W1NDY CFG · @WindyCfg_bot") {
                showMenu = false
                openURL(W1.shopURL)
            }
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
            SheetItem(title: "Диагностика VPN", subtitle: "Проверить подпись и VPN-модуль") {
                showSettings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showDiagnostics = true }
            }
        }
    }

    private func sheetBody<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                Text(title).font(ui(22, .bold)).foregroundColor(.white).padding(.vertical, 6)
                content()
                Text("W1NDY CFG · версия \(W1.version)")
                    .font(ui(13)).foregroundColor(.w1Dim)
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

/// Карточка статуса, как «Подписка активна | 28 дн.» в мини-приложении.
struct StatusCard: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var vpn: VPNController
    let onChangeMode: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: vpn.isConnected ? "checkmark" : (vpn.isBusy ? "ellipsis" : "power"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(vpn.isConnected ? .black : .white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(vpn.isConnected ? Color.white : Color.w1Pill))
                    .overlay(Circle().strokeBorder(Color.w1BorderStrong, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    title
                    Text(subtitle)
                        .font(ui(14))
                        .foregroundColor(.w1Muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            PillButton(icon: "arrow.up.arrow.down", title: "Сменить режим", action: onChangeMode)
        }
        .padding(18)
        .card(26)
    }

    @ViewBuilder
    private var title: some View {
        if vpn.isConnected, let since = vpn.connectedDate {
            TimelineView(.periodic(from: Date(), by: 1)) { context in
                let s = max(0, Int(context.date.timeIntervalSince(since)))
                Text("Подключено | " + String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60))
                    .font(ui(18, .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        } else {
            Text(headline)
                .font(ui(18, .bold))
                .foregroundColor(.white)
        }
    }

    private var headline: String {
        switch vpn.status {
        case .connecting, .reasserting: return "Подключаемся…"
        case .disconnecting: return "Отключаемся…"
        default:
            if state.mode == .vpn, let days = state.daysLeft {
                return days > 0 ? "Ключ активен | \(days) дн." : "Срок ключа истёк"
            }
            return state.mode == .dns ? "Режим DNS" : "VPN выключен"
        }
    }

    private var subtitle: String {
        state.mode == .dns ? "DNS-сервер \(state.dnsServer)" : state.accessLine
    }
}
