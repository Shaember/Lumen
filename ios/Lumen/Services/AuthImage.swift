import SwiftUI
import UIKit

/// Authenticated media loader — parity with web `AuthImage`.
/// `AsyncImage` cannot attach Bearer; API thumbs/originals require Authorization.
struct AuthImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @StateObject private var loader = AuthImageLoader()

    var body: some View {
        Group {
            switch loader.state {
            case .idle, .loading:
                Rectangle().fill(Color.lumenRaised)
            case .success(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failed:
                Rectangle()
                    .fill(Color.lumenRaised)
                    .overlay(
                        Text("не загрузилось")
                            .font(.caption2)
                            .foregroundStyle(Color.lumenMuted)
                    )
                    .onTapGesture { Task { await loader.load(url: url, force: true) } }
            }
        }
        .task(id: url?.absoluteString) {
            await loader.load(url: url, force: false)
        }
    }
}

@MainActor
final class AuthImageLoader: ObservableObject {
    enum State {
        case idle, loading
        case success(UIImage)
        case failed
    }

    @Published var state: State = .idle

    private static let cache = NSCache<NSString, UIImage>()
    private static var inflight: [String: Task<UIImage, Error>] = [:]
    private static let lock = NSLock()

    func load(url: URL?, force: Bool) async {
        guard let url else {
            state = .failed
            return
        }
        let key = url.absoluteString as NSString
        if !force, let cached = Self.cache.object(forKey: key) {
            state = .success(cached)
            return
        }
        state = .loading
        do {
            let image = try await Self.fetch(url: url)
            Self.cache.setObject(image, forKey: key)
            state = .success(image)
        } catch {
            state = .failed
        }
    }

    private static func fetch(url: URL) async throws -> UIImage {
        let key = url.absoluteString
        lock.lock()
        if let existing = inflight[key] {
            lock.unlock()
            return try await existing.value
        }
        let task = Task<UIImage, Error> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            if let token = APIClient.shared.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                try await APIClient.shared.refreshToken()
                var retry = URLRequest(url: url)
                if let token = APIClient.shared.getAccessToken() {
                    retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let (data2, response2) = try await URLSession.shared.data(for: retry)
                guard let http2 = response2 as? HTTPURLResponse, (200...299).contains(http2.statusCode),
                      let image = UIImage(data: data2) else {
                    throw APIError.invalidResponse
                }
                return image
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                throw APIError.invalidResponse
            }
            return image
        }
        inflight[key] = task
        lock.unlock()
        defer {
            lock.lock()
            inflight[key] = nil
            lock.unlock()
        }
        return try await task.value
    }
}
