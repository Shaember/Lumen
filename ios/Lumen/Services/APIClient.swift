import Foundation

// MARK: - API Client

class APIClient {
    static let shared = APIClient()
    
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? "https://photos.local"
    }
    
    private var accessToken: String?
    private var refreshToken: String?
    
    private init() {}
    
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        UserDefaults.standard.set(access, forKey: "access_token")
        UserDefaults.standard.set(refresh, forKey: "refresh_token")
    }
    
    func loadTokens() {
        self.accessToken = UserDefaults.standard.string(forKey: "access_token")
        self.refreshToken = UserDefaults.standard.string(forKey: "refresh_token")
    }
    
    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }
    
    // MARK: - Auth
    
    func setup(username: String, password: String) async throws {
        try await post("/auth/setup", body: ["username": username, "password": password])
    }
    
    func login(username: String, password: String) async throws -> User {
        let response: LoginResponse = try await post("/auth/login", body: ["username": username, "password": password])
        setTokens(access: response.accessToken, refresh: response.refreshToken)
        return response.user
    }
    
    func refreshToken() async throws {
        guard let refresh = refreshToken else { throw APIError.unauthorized }
        let response: LoginResponse = try await post("/auth/refresh", body: ["refresh_token": refresh])
        setTokens(access: response.accessToken, refresh: response.refreshToken)
    }
    
    // MARK: - Photos
    
    func listPhotos(month: String? = nil, offset: Int = 0, limit: Int = 50) async throws -> [Photo] {
        var query = "offset=\(offset)&limit=\(limit)"
        if let month = month { query += "&month=\(month)" }
        return try await get("/photos?\(query)")
    }
    
    func getPhoto(id: Int64) async throws -> Photo {
        return try await get("/photos/\(id)")
    }
    
    func uploadPhoto(data: Data, filename: String, takenAt: String?, deviceId: Int64?) async throws -> Photo {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v1/photos/upload")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        if let takenAt = takenAt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"taken_at\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(takenAt)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.uploadFailed
        }
        
        let result = try JSONDecoder().decode(APIResponse<Photo>.self, from: responseData)
        guard let photo = result.data else { throw APIError.invalidResponse }
        return photo
    }
    
    func toggleFavorite(id: Int64) async throws -> Bool {
        let result: [String: Bool] = try await patch("/photos/\(id)/favorite")
        return result["is_favorite"] ?? false
    }
    
    func deletePhoto(id: Int64) async throws {
        try await delete("/photos/\(id)")
    }
    
    func restorePhoto(id: Int64) async throws {
        try await post("/photos/\(id)/restore", body: [String: String]())
    }
    
    func listTrash() async throws -> [Photo] {
        return try await get("/photos/trash")
    }
    
    // MARK: - Albums
    
    func listAlbums() async throws -> [Album] {
        return try await get("/albums")
    }
    
    func createAlbum(name: String) async throws -> Album {
        return try await post("/albums", body: ["name": name])
    }
    
    func getAlbum(id: Int64) async throws -> Album {
        return try await get("/albums/\(id)")
    }
    
    // MARK: - Devices
    
    func registerDevice(name: String, pushToken: String?) async throws -> Device {
        var body: [String: Any] = ["name": name, "device_type": "ios"]
        if let token = pushToken { body["push_token"] = token }
        return try await post("/devices/register", body: body)
    }
    
    // MARK: - Generic HTTP
    
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
    
    private func delete(_ path: String) async throws {
        _ = try await request(path, method: "DELETE")
    }
    
    private func request(_ path: String, method: String, body: Any? = nil) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 && refreshToken != nil {
            try await refreshToken()
            return try await self.request(path, method: method, body: body)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
            throw APIError.httpError(httpResponse.statusCode, errorResponse?.error ?? "Unknown error")
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
        case .unauthorized: return "Not authenticated"
        case .invalidResponse: return "Invalid server response"
        case .uploadFailed: return "Upload failed"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        }
    }
}
