import Foundation
import NetworkExtension

/// Управление VPN-туннелем через NETunnelProviderManager.
/// Конфиг передаётся в расширение напрямую (options + providerConfiguration) — App Group не нужен,
/// поэтому приложение продолжает работать после переподписи другим сертификатом.
@MainActor
final class VPNController: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var connectedDate: Date?
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
        Task { await load() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var isConnected: Bool { status == .connected }
    var isBusy: Bool { status == .connecting || status == .disconnecting || status == .reasserting }

    func load() async {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        manager = managers.first
        update()
    }

    private func update() {
        status = manager?.connection.status ?? .disconnected
        connectedDate = manager?.connection.connectedDate
    }

    /// Bundle ID расширения ищем в самом приложении: после переподписи он может измениться.
    static var extensionBundleId: String {
        if let plugins = Bundle.main.builtInPlugInsURL,
           let items = try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil)
        {
            for item in items where item.pathExtension == "appex" {
                if let bundle = Bundle(url: item),
                   let point = (bundle.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String,
                   point == "com.apple.networkextension.packet-tunnel",
                   let id = bundle.bundleIdentifier
                {
                    return id
                }
            }
        }
        return (Bundle.main.bundleIdentifier ?? "com.w1ndy.cfg") + ".tunnel"
    }

    func connect(config: String) async {
        lastError = nil
        do {
            let manager = self.manager ?? NETunnelProviderManager()
            let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Self.extensionBundleId
            proto.serverAddress = "W1NDY CFG"
            proto.providerConfiguration = ["configContent": config]
            proto.disconnectOnSleep = false
            manager.protocolConfiguration = proto
            manager.localizedDescription = "W1NDY CFG"
            manager.isEnabled = true
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            self.manager = manager
            try manager.connection.startVPNTunnel(options: ["configContent": config as NSString])
            update()
        } catch {
            let ns = error as NSError
            if ns.domain == NEVPNErrorDomain, ns.code == NEVPNError.configurationReadWriteFailed.rawValue {
                lastError = "Разрешите добавление VPN-конфигурации"
            } else {
                lastError = error.localizedDescription
            }
            update()
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }
}
