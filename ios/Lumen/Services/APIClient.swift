import Foundation

final class APIClient {
    static let shared = APIClient()

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? "https://photos.local"
    }

    private var accessToken: String?
    private var refreshToken: String?
    private var refreshTask: Task<Void, Error>?

    private init() {}

    func getAccessToken() -> String? { accessToken }

    func setTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        Keychain.set(access, account: "access_token")
        Keychain.set(refresh, account: "refresh_token")
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }

    func loadTokens() {
        if let a = Keychain.get("access_token"), let r = Keychain.get("refresh_token") {
            accessToken = a
            refreshToken = r
            return
        }
        if let a = UserDefaults.standard.string(forKey: "access_token"),
           let r = UserDefaults.standard.string(forKey: "refresh_token") {
            setTokens(access: a, refresh: r)
        }
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        Keychain.delete("access_token")
        Keychain.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }

    func setup(username: String, password: String) async throws {
        let _: MessageResponse = try await post("/auth/setup", body: ["username": username, "password": password])
    }

    func login(username: String, password: String) async throws -> User {
        let response: LoginResponse = try await post("/auth/login", body: ["username": username, "password": password])
        setTokens(access: response.accessToken, refresh: response.refreshToken)
        return response.user
    }

    func refreshToken() async throws {
        if let existing = refreshTask {
            try await existing.value
            return
        }
        let task = Task<Void, Error> {
            defer { self.refreshTask = nil }
            guard let refresh = self.refreshToken else { throw APIError.unauthorized }
            let pair: TokenPair = try await self.post("/auth/refresh", body: ["refresh_token": refresh])
            self.setTokens(access: pair.accessToken, refresh: pair.refreshToken)
        }
        refreshTask = task
        try await task.value
    }

    func logout() async {
        let refresh = refreshToken
        defer { clearTokens() }
        guard let refresh else { return }
        _ = try? await post("/auth/logout", body: ["refresh_token": refresh]) as MessageResponse
    }

    func listPhotos(month: String? = nil, offset: Int = 0, limit: Int = 50) async throws -> [Photo] {
        var query = "offset=\(offset)&limit=\(limit)"
        if let month { query += "&month=\(month)" }
        return try await get("/photos?\(query)")
    }

    func listAllPhotos(max: Int = 5000) async throws -> [Photo] {
        let pageSize = 200
        var all: [Photo] = []
        while all.count < max {
            let batch = try await listPhotos(offset: all.count, limit: min(pageSize, max - all.count))
            all.append(contentsOf: batch)
            if batch.count < pageSize { break }
        }
        return all
    }

    func getPhoto(id: Int64) async throws -> Photo {
        try await get("/photos/\(id)")
    }

    @discardableResult
    func uploadPhoto(data: Data, filename: String, takenAt: String?, deviceId: Int64?) async throws -> UploadResponse {
        let boundary = UUID().uuidString
        guard let url = URL(string: "\(baseURL)/api/v1/photos/upload") else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(data)
        append("\r\n")
        if let takenAt {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"taken_at\"\r\n\r\n")
            append("\(takenAt)\r\n")
        }
        if let deviceId {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"device_id\"\r\n\r\n")
            append("\(deviceId)\r\n")
        }
        append("--\(boundary)--\r\n")
        request.httpBody = body
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 {
            try await refreshToken()
            return try await uploadPhoto(data: data, filename: filename, takenAt: takenAt, deviceId: deviceId)
        }
        guard http.statusCode == 201 else { throw APIError.uploadFailed }
        let result = try JSONDecoder().decode(APIResponse<UploadResponse>.self, from: responseData)
        guard let uploaded = result.data else { throw APIError.invalidResponse }
        return uploaded
    }

    func toggleFavorite(id: Int64) async throws -> Bool {
        let result: [String: Bool] = try await patch("/photos/\(id)/favorite")
        return result["is_favorite"] ?? false
    }

    func deletePhoto(id: Int64) async throws {
        let _: MessageResponse = try await delete("/photos/\(id)")
    }

    func restorePhoto(id: Int64) async throws {
        let _: MessageResponse = try await post("/photos/\(id)/restore", body: [String: String]())
    }

    func listTrash() async throws -> [Photo] {
        try await get("/photos/trash")
    }

    func listAlbums() async throws -> [Album] {
        try await get("/albums")
    }

    func createAlbum(name: String) async throws -> Album {
        let created: CreateAlbumResponse = try await post("/albums", body: ["name": name])
        return Album(id: created.id, name: created.name, photoCount: 0)
    }

    func getAlbum(id: Int64) async throws -> Album {
        try await get("/albums/\(id)")
    }

    func addPhotosToAlbum(id: Int64, photoIds: [Int64]) async throws {
        struct Added: Decodable { let added: Int? }
        let _: Added = try await post("/albums/\(id)/photos", body: ["photo_ids": photoIds.map { Int($0) }])
    }

    func removePhotoFromAlbum(albumId: Int64, photoId: Int64) async throws {
        let _: MessageResponse = try await delete("/albums/\(albumId)/photos/\(photoId)")
    }

    func registerDevice(name: String, pushToken: String?) async throws -> Device {
        var body: [String: Any] = ["name": name, "device_type": "ios"]
        if let pushToken { body["push_token"] = pushToken }
        let created: RegisterDeviceResponse = try await post("/devices/register", body: body)
        return Device(id: created.id, name: created.name, deviceType: "ios")
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await request(path, method: "GET")
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard let result = response.data else { throw APIError.invalidResponse }
        return result
    }

    private func post<T: Decodable>(_ path: String, body: Any) async throws -> T {
        let data = try await request(path, method: "POST", body: body)
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard let result = response.data else { throw APIError.invalidResponse }
        return result
    }

    private func patch<T: Decodable>(_ path: String) async throws -> T {
        let data = try await request(path, method: "PATCH")
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard let result = response.data else { throw APIError.invalidResponse }
        return result
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let data = try await request(path, method: "DELETE")
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard let result = response.data else { throw APIError.invalidResponse }
        return result
    }

    private func request(_ path: String, method: String, body: Any? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/v1\(path)") else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 && refreshToken != nil && !path.hasPrefix("/auth/refresh") {
            try await refreshToken()
            return try await self.request(path, method: method, body: body)
        }
        guard (200...299).contains(http.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
            throw APIError.httpError(http.statusCode, errorResponse?.error ?? "Unknown error")
        }
        return data
    }
}

enum APIError: Error, LocalizedError {
    case unauthorized
    case invalidResponse
    case uploadFailed
    case httpError(Int, String)
    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Не авторизован"
        case .invalidResponse: return "Некорректный ответ сервера"
        case .uploadFailed: return "Ошибка загрузки"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        }
    }
}
