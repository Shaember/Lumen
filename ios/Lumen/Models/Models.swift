import Foundation
import SwiftUI

// MARK: - API Models

struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let error: String?
}

struct User: Codable {
    let id: Int64
    let username: String
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id, username
        case isAdmin = "is_admin"
    }
}

struct Photo: Identifiable, Codable {
    let id: Int64
    let userId: Int64
    let filename: String
    let mimeType: String
    let fileSize: Int64
    let takenAt: String?
    let isFavorite: Bool
    let thumbnailPath: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case filename
        case mimeType = "mime_type"
        case fileSize = "file_size"
        case takenAt = "taken_at"
        case isFavorite = "is_favorite"
        case thumbnailPath = "thumbnail_path"
        case createdAt = "created_at"
    }
}

struct Album: Identifiable, Codable {
    let id: Int64
    let name: String
    let coverPhotoId: Int64?
    let createdAt: String
    let updatedAt: String
    let photoCount: Int?
    let photos: [Photo]?

    enum CodingKeys: String, CodingKey {
        case id, name
        case coverPhotoId = "cover_photo_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case photoCount = "photo_count"
        case photos
    }
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct Device: Identifiable, Codable {
    let id: Int64
    let name: String
    let deviceType: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case deviceType = "device_type"
    }
}
