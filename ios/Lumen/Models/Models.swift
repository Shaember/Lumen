import Foundation

// MARK: - API envelope

struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let error: String?
}

struct MessageResponse: Decodable {
    let message: String?
}

struct TokenPair: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
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

/// POST /photos/upload → { id, filename } only
struct UploadResponse: Decodable {
    let id: Int64
    let filename: String
}

/// POST /albums → { id, name }
struct CreateAlbumResponse: Decodable {
    let id: Int64
    let name: String
}

/// POST /devices/register → { id, name }
struct RegisterDeviceResponse: Decodable {
    let id: Int64
    let name: String
}

// MARK: - Domain

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
    let userId: Int64?
    let filename: String
    let mimeType: String?
    let fileSize: Int64?
    let takenAt: String?
    let isFavorite: Bool
    let thumbnailPath: String?
    let createdAt: String?

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        userId = try c.decodeIfPresent(Int64.self, forKey: .userId)
        filename = try c.decodeIfPresent(String.self, forKey: .filename) ?? ""
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType)
        fileSize = try c.decodeIfPresent(Int64.self, forKey: .fileSize)
        takenAt = try c.decodeIfPresent(String.self, forKey: .takenAt)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        thumbnailPath = try c.decodeIfPresent(String.self, forKey: .thumbnailPath)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    init(id: Int64, filename: String, isFavorite: Bool = false, takenAt: String? = nil, createdAt: String? = nil) {
        self.id = id
        self.userId = nil
        self.filename = filename
        self.mimeType = nil
        self.fileSize = nil
        self.takenAt = takenAt
        self.isFavorite = isFavorite
        self.thumbnailPath = nil
        self.createdAt = createdAt
    }
}

struct Album: Identifiable, Codable {
    let id: Int64
    let name: String
    let coverPhotoId: Int64?
    let createdAt: String?
    let updatedAt: String?
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        coverPhotoId = try c.decodeIfPresent(Int64.self, forKey: .coverPhotoId)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        photoCount = try c.decodeIfPresent(Int.self, forKey: .photoCount)
        photos = try c.decodeIfPresent([Photo].self, forKey: .photos)
    }

    init(id: Int64, name: String, coverPhotoId: Int64? = nil, createdAt: String? = nil, updatedAt: String? = nil, photoCount: Int? = 0, photos: [Photo]? = nil) {
        self.id = id
        self.name = name
        self.coverPhotoId = coverPhotoId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.photoCount = photoCount
        self.photos = photos
    }
}

struct Device: Identifiable, Codable {
    let id: Int64
    let name: String
    let deviceType: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case deviceType = "device_type"
    }
}
