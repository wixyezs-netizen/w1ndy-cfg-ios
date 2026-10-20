import Foundation

enum Mode: String {
    case vpn
    case dns
}

struct DnsPreset: Identifiable {
    let title: String
    let address: String
    var id: String { address }
}

/// Состояние приложения (аналог W1ndy.kt в Android-версии).
@MainActor
final class AppState: ObservableObject {
    static let dnsPresets = [
        DnsPreset(title: "Google", address: "8.8.8.8"),
        DnsPreset(title: "Cloudflare", address: "1.1.1.1"),
        DnsPreset(title: "Яндекс", address: "77.88.8.8"),
        DnsPreset(title: "AdGuard", address: "94.140.14.14"),
    ]

    private let defaults = UserDefaults.standard

    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var mode: Mode { didSet { defaults.set(mode.rawValue, forKey: "mode") } }
    @Published var dnsServer: String { didSet { defaults.set(dnsServer, forKey: "dns") } }
    @Published var tgLinked: Bool { didSet { defaults.set(tgLinked, forKey: "tg_linked") } }
    @Published var tgName: String { didSet { defaults.set(tgName, forKey: "tg_name") } }
    @Published private(set) var token: String? { didSet { defaults.set(token, forKey: "token") } }
    @Published private(set) var vpnConfig: String? { didSet { defaults.set(vpnConfig, forKey: "vpn_config") } }

    var activated: Bool { !(token ?? "").isEmpty }

    init() {
        onboarded = defaults.bool(forKey: "onboarded")
        mode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .vpn
        dnsServer = defaults.string(forKey: "dns") ?? "8.8.8.8"
        tgLinked = defaults.bool(forKey: "tg_linked")
        tgName = defaults.string(forKey: "tg_name") ?? ""
        token = defaults.string(forKey: "token")
        vpnConfig = defaults.string(forKey: "vpn_config")
    }

    var installId: String {
        if let id = defaults.string(forKey: "install_id"), id.count >= 16 {
            return id
        }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        defaults.set(id, forKey: "install_id")
        return id
    }

    // MARK: - сервер

    /// Активация ключа: сервер выдаёт конфиг, приложение его сохраняет.
    func activate(code: String) async throws {
        let json = try await Api.json("POST", "/api/w1ndy/activate", body: [
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "install_id": installId,
            "model": W1.deviceModel,
        ], idempotent: false)
        guard let token = json["token"] as? String, !token.isEmpty else {
            throw ApiError(code: 500, message: "Сервер вернул пустой ответ")
        }
        self.token = token
        try await downloadProfile()
        mode = .vpn
    }

    /// Проверка доступа и обновление конфига (администратор мог что-то поменять).
    func refresh() async throws {
        guard let token, !token.isEmpty else { return }
        do {
            _ = try await Api.json("GET", "/api/w1ndy/status?t=" + escape(token))
        } catch let error as ApiError where error.code == 403 || error.code == 401 {
            reset()
            throw error
        }
        try await downloadProfile()
    }

    private func downloadProfile() async throws {
        guard let token else { return }
        let content = try await Api.text("/api/w1ndy/profile?t=" + escape(token))
        guard content.contains("\"inbounds\"") else {
            throw ApiError(code: 500, message: "Не удалось получить конфигурацию")
        }
        vpnConfig = content
    }

    func telegramLink() async throws -> URL {
        let json = try await Api.json("POST", "/api/w1ndy/tg/start", body: ["install_id": installId])
        guard let raw = json["url"] as? String, let url = URL(string: raw) else {
            throw ApiError(code: 500, message: "Не удалось получить ссылку")
        }
        return url
    }

    func telegramLinked() async -> Bool {
        guard let json = try? await Api.json("GET", "/api/w1ndy/tg/poll?install_id=" + escape(installId)) else {
            return false
        }
        let linked = (json["linked"] as? Bool) ?? false
        if linked {
            tgLinked = true
            tgName = json["name"] as? String ?? ""
        }
        return linked
    }

    func reset() {
        token = nil
        vpnConfig = nil
    }

    private func escape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    // MARK: - конфигурации sing-box

    /// Конфиг для запуска: VPN (с сервера) или «только DNS».
    func currentConfig() -> String? {
        mode == .dns ? Self.dnsConfig(server: dnsServer) : vpnConfig
    }

    static func normalizeDns(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, parts.allSatisfy({ p in
            guard let v = Int(p), p.count <= 3, String(v) == p else { return false }
            return (0 ... 255).contains(v)
        }) {
            return s
        }
        if s.contains(":"), s.count <= 45, s.allSatisfy({ $0.isHexDigit || $0 == ":" }) {
            return s
        }
        return nil
    }

    /// В туннель попадает только адрес DNS (172.19.0.2), остальной трафик идёт напрямую.
    static func dnsConfig(server: String) -> String {
        let root: [String: Any] = [
            "log": ["level": "warn"],
            "dns": [
                "servers": [["type": "udp", "tag": "dns-custom", "server": server]],
                "final": "dns-custom",
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "address": ["172.19.0.1/30"],
                "route_address": ["172.19.0.0/30"],
                "auto_route": true,
                "stack": "mixed",
            ]],
            "outbounds": [["type": "direct", "tag": "direct"]],
            "route": [
                "rules": [
                    ["action": "sniff"],
                    ["protocol": "dns", "action": "hijack-dns"],
                    ["port": 53, "action": "hijack-dns"],
                ],
                "final": "direct",
                "auto_detect_interface": true,
            ],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
