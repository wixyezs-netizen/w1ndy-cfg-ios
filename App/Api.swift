import Foundation
import UIKit

enum W1 {
    static let base = "https://site.litenergyapp.store"
    static let botURL = URL(string: "https://t.me/VPN_LitEnergy_bot")!
    static let channelURL = URL(string: "https://t.me/windytoptop")!
    static let shopURL = URL(string: "https://t.me/WindyCfg_bot")!
    static let releasesURL = URL(string: "https://github.com/wixyezs-netizen/w1ndy-cfg-ios/releases/latest")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var deviceModel: String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return "Apple \(machine)".prefix(64).description
    }
}

struct ApiError: LocalizedError {
    let code: Int
    let message: String
    var errorDescription: String? { message }
}

/// Запросы к серверу W1NDY. Каждый запрос — новая сессия и новое соединение:
/// на части мобильных сетей долгоживущие соединения через CDN «замирают», короткие проходят.
enum Api {
    static let netError = "Сервер не отвечает. Проверьте интернет и попробуйте ещё раз."

    static func json(_ method: String, _ path: String, body: [String: Any]? = nil, idempotent: Bool = true) async throws -> [String: Any] {
        let data = try await raw(method, path, body: body, idempotent: idempotent)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    static func text(_ path: String) async throws -> String {
        let data = try await raw("GET", path, body: nil, idempotent: true)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func raw(_ method: String, _ path: String, body: [String: Any]?, idempotent: Bool) async throws -> Data {
        for attempt in 0 ..< 3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(800_000_000 * attempt))
            }
            do {
                return try await once(method, path, body)
            } catch let error as ApiError {
                throw error
            } catch let error as URLError {
                // активацию повторяем, только если запрос точно не ушёл на сервер
                let notSent: Set<URLError.Code> = [.cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet]
                if !idempotent, !notSent.contains(error.code) { break }
            } catch {
                if !idempotent { break }
            }
        }
        throw ApiError(code: 0, message: netError)
    }

    private static func once(_ method: String, _ path: String, _ body: [String: Any]?) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 25
        config.httpMaximumConnectionsPerHost = 1
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: URL(string: W1.base + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("W1NDY-CFG/\(W1.version) (iOS)", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200 ..< 300).contains(code) {
            if code == 502 || code == 504 || (520 ... 530).contains(code) {
                throw URLError(.badServerResponse)
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let message = (json["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Ошибка сервера (\(code))"
            throw ApiError(code: code, message: message)
        }
        return data
    }
}
