import SwiftUI
import UIKit

/// Вход: выбор режима → ключ или DNS → «Старт» в боте LitEnergy VPN.
struct OnboardingView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openURL) private var openURL

    @State private var step: Step
    @State private var mode: Mode
    @State private var key = ""
    @State private var dnsChoice = "8.8.8.8"
    @State private var customDns = ""
    @State private var busy = false
    @State private var error: String?
    @State private var botOpened = false

    init(initial: Step) {
        _step = State(initialValue: initial)
        _mode = State(initialValue: initial == .dns ? .dns : .vpn)
    }

    private var dnsTarget: String { dnsChoice == "custom" ? customDns : dnsChoice }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if step != .mode {
                    Button {
                        error = nil
                        step = step == .telegram ? (mode == .vpn ? .key : .dns) : .mode
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Spacer().frame(height: 24)
                }
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .onAppear {
            let saved = state.dnsServer
            if AppState.dnsPresets.contains(where: { $0.address == saved }) {
                dnsChoice = saved
            } else {
                dnsChoice = "custom"
                customDns = saved
            }
        }
        .task(id: step) {
            // ожидание нажатия «Старт» в боте
            guard step == .telegram else { return }
            while !Task.isCancelled {
                if await state.telegramLinked() {
                    busy = true
                    _ = await finish()
                    busy = false
                    return
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .mode:
            VStack(spacing: 0) {
                Spacer().frame(height: 36)
                BrandHeader()
                Text("Выберите, как подключиться")
                    .font(ui(16)).foregroundColor(.w1Muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                VStack(spacing: 12) {
                    ChoiceCard(icon: "shield.fill", title: "VPN", subtitle: "Защищённое подключение по ключу доступа") {
                        mode = .vpn
                        error = nil
                        if state.activated { next() } else { step = .key }
                    }
                    ChoiceCard(icon: "server.rack", title: "Только DNS", subtitle: "Свой DNS-сервер, например 8.8.8.8. Остальной трафик — напрямую") {
                        mode = .dns
                        error = nil
                        step = .dns
                    }
                }
                .padding(.top, 32)
                if busy {
                    ProgressView().tint(.white).padding(.top, 20)
                }
                errorText
            }

        case .key:
            StepHeader(title: "Ключ доступа", subtitle: "Вставьте ключ из бота @WindyCfg_bot. Он выглядит так: ABCD-EFGH")
            HStack {
                TextField("", text: $key, prompt: Text("XXXX-XXXX").foregroundColor(.w1Dim))
                    .font(ui(22, .semibold))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .disabled(busy)
                    .onChange(of: key) { value in
                        let fixed = String(value.uppercased().prefix(16))
                        if fixed != value { key = fixed }
                    }
                Button("Вставить") {
                    if let text = UIPasteboard.general.string {
                        key = String(text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().prefix(16))
                    }
                }
                .font(ui(14, .semibold))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .card(18)
            .padding(.top, 24)
            errorText
            PrimaryButton(title: "Продолжить", busy: busy, enabled: key.filter { $0.isLetter || $0.isNumber }.count >= 8) { next() }
                .padding(.top, 20)
            PillButton(icon: "cart", title: "Купить ключ") { openURL(W1.shopURL) }
                .padding(.top, 12)

        case .dns:
            StepHeader(title: "DNS-сервер", subtitle: "DNS-запросы телефона пойдут через выбранный сервер, остальной трафик — напрямую.")
            VStack(spacing: 0) {
                ForEach(AppState.dnsPresets) { preset in
                    dnsRow(preset.title, preset.address, selected: dnsChoice == preset.address) { dnsChoice = preset.address }
                }
                dnsRow("Свой адрес", "", selected: dnsChoice == "custom") { dnsChoice = "custom" }
            }
            .padding(.vertical, 6)
            .card(24)
            .padding(.top, 20)
            if dnsChoice == "custom" {
                TextField("", text: $customDns, prompt: Text("например 9.9.9.9").foregroundColor(.w1Dim))
                    .font(ui(18))
                    .foregroundColor(.white)
                    .keyboardType(.numbersAndPunctuation)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .card(18)
                    .padding(.top, 12)
            }
            errorText
            PrimaryButton(title: "Продолжить", busy: busy, enabled: !dnsTarget.trimmingCharacters(in: .whitespaces).isEmpty) { next() }
                .padding(.top, 20)

        case .telegram:
            VStack(spacing: 0) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 76, height: 76)
                    .card(22)
                    .padding(.top, 16)
                Text("Последний шаг")
                    .font(ui(24, .heavy)).foregroundColor(.white)
                    .padding(.top, 20)
                Text("Откройте бота LitEnergy VPN и нажмите «Старт». После этого приложение запустится автоматически.")
                    .font(ui(14)).foregroundColor(.w1Muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                PrimaryButton(title: "Открыть бота", busy: busy && !botOpened) {
                    error = nil
                    Task {
                        do {
                            let url = try await state.telegramLink()
                            openURL(url)
                            botOpened = true
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                .padding(.top, 28)
                errorText
                if botOpened {
                    HStack(spacing: 10) {
                        ProgressView().tint(.w1Muted)
                        Text("Ждём нажатия «Старт»…").font(ui(14)).foregroundColor(.w1Muted)
                    }
                    .padding(.top, 20)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if let error {
            Text(error)
                .font(ui(14))
                .foregroundColor(.w1Red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
    }

    private func dnsRow(_ title: String, _ address: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? .white : .w1Dim)
                Text(title).font(ui(16)).foregroundColor(.white)
                Spacer()
                if !address.isEmpty {
                    Text(address).font(ui(15)).foregroundColor(.w1Muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - логика (как в Android-версии)

    private func finish() async -> Bool {
        do {
            if mode == .vpn {
                if !state.activated {
                    try await state.activate(code: key)
                } else {
                    state.mode = .vpn
                }
            } else {
                guard let server = AppState.normalizeDns(dnsTarget) else {
                    error = "Введите IP-адрес DNS, например 8.8.8.8"
                    return false
                }
                state.dnsServer = server
                state.mode = .dns
            }
            state.onboarded = true
            return true
        } catch let apiError as ApiError {
            if apiError.code == 428 {
                step = .telegram
            } else {
                error = apiError.message
                if apiError.code == 404, step == .telegram { step = .key }
            }
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func next() {
        guard !busy else { return }
        error = nil
        busy = true
        Task {
            defer { busy = false }
            if mode == .dns, AppState.normalizeDns(dnsTarget) == nil {
                error = "Введите IP-адрес DNS, например 8.8.8.8"
                return
            }
            var linked = state.tgLinked
            if !linked { linked = await state.telegramLinked() }
            if !linked {
                if mode == .vpn, !state.activated {
                    _ = await finish() // сервер проверит ключ; верный ключ без «Старт» → шаг Telegram
                } else {
                    step = .telegram
                }
            } else {
                _ = await finish()
            }
        }
    }
}
