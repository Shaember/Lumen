import Foundation
import SwiftUI
import BackgroundTasks
import Photos
import UIKit

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var lastError: String?

    private let api = APIClient.shared

    func loadTokens() {
        api.loadTokens()
        if api.getAccessToken() != nil {
            isLoggedIn = true
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            user = try await api.login(username: username, password: password)
            isLoggedIn = true
        } catch {
            lastError = error.localizedDescription
            print("Login failed: \(error)")
        }
    }

    func setup(username: String, password: String) async throws {
        try await api.setup(username: username, password: password)
    }

    func logout() async {
        await api.logout() // revoke refresh on server, then clear Keychain
        user = nil
        isLoggedIn = false
    }
}

// MARK: - Sync Manager

@MainActor
class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0
    @Published var lastError: String?
    @Published var photoAuthStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var deviceId: Int64?

    private let api = APIClient.shared
    private let uploadQueue = UploadQueue()
    private let lastSyncKey = "lumen_last_sync"
    private let deviceIdKey = "lumen_device_id"

    init() {
        if let t = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            lastSyncDate = t
        }
        let stored = UserDefaults.standard.object(forKey: deviceIdKey) as? Int64
            ?? (UserDefaults.standard.object(forKey: deviceIdKey) as? NSNumber)?.int64Value
        deviceId = stored
    }

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.lumen.photosync",
            using: nil
        ) { task in
            guard let processing = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self.handleBackgroundSync(task: processing)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.lumen.photosync.refresh",
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await self.handleRefresh(task: refresh)
            }
        }
    }

    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: "com.lumen.photosync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lastError = "Фоновая синхронизация: \(error.localizedDescription)"
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.lumen.photosync.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lastError = "Фоновое обновление: \(error.localizedDescription)"
        }
    }

    private func handleBackgroundSync(task: BGProcessingTask) async {
        scheduleBackgroundSync()
        let work = Task { await performFullSync() }
        task.expirationHandler = { [weak self] in
            work.cancel()
            self?.uploadQueue.cancelAll()
        }
        await work.value
        task.setTaskCompleted(success: lastError == nil)
    }

    private func handleRefresh(task: BGAppRefreshTask) async {
        scheduleRefresh()
        let work = Task { await performIncrementalSync() }
        task.expirationHandler = { work.cancel() }
        await work.value
        task.setTaskCompleted(success: true)
    }

    func requestPhotoAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoAuthStatus = status
        return status == .authorized || status == .limited
    }

    func performFullSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let ok = await requestPhotoAccess()
        guard ok else {
            lastError = "Нет доступа к Фото. Разрешите в Настройки → Lumen."
            return
        }

        await syncDeviceRegistration()
        await syncNewPhotos()
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now, forKey: lastSyncKey)
        scheduleBackgroundSync()
        scheduleRefresh()
    }

    func performIncrementalSync() async {
        let ok = photoAuthStatus == .authorized || photoAuthStatus == .limited
            || await requestPhotoAccess()
        guard ok else { return }
        await syncNewPhotos()
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now, forKey: lastSyncKey)
    }

    private func syncDeviceRegistration() async {
        let deviceName = UIDevice.current.name
        do {
            let device = try await api.registerDevice(name: deviceName, pushToken: nil)
            deviceId = device.id
            UserDefaults.standard.set(device.id, forKey: deviceIdKey)
        } catch {
            lastError = "Регистрация устройства: \(error.localizedDescription)"
            print("Device registration failed: \(error)")
        }
    }

    private func syncNewPhotos() async {
        let lastSync = lastSyncDate ?? Date.distantPast
        let assetCollection = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumUserLibrary,
            options: nil
        ).firstObject

        guard let collection = assetCollection else { return }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "creationDate > %@", lastSync as NSDate)

        let assets = PHAsset.fetchAssets(in: collection, options: options)
        let total = assets.count
        guard total > 0 else {
            syncProgress = 1
            return
        }

        var uploaded = 0
        var failures = 0
        let device = deviceId

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            assets.enumerateObjects { asset, _, _ in
                group.enter()
                self.uploadQueue.enqueue(asset: asset, deviceId: device) { result in
                    switch result {
                    case .success:
                        uploaded += 1
                    case .failure:
                        failures += 1
                    }
                    Task { @MainActor in
                        self.syncProgress = Double(uploaded + failures) / Double(total)
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                cont.resume()
            }
        }

        if failures > 0 {
            lastError = "Не загружено: \(failures) из \(total)"
        }
    }
}

// MARK: - Upload Queue

class UploadQueue {
    private let operationQueue = OperationQueue()
    private let api = APIClient.shared

    init() {
        operationQueue.maxConcurrentOperationCount = 3
    }

    func enqueue(asset: PHAsset, deviceId: Int64?, completion: @escaping (Result<Void, Error>) -> Void) {
        let operation = BlockOperation { [weak self] in
            guard let self = self else { return }
            let sem = DispatchSemaphore(value: 0)
            Task {
                do {
                    let data = try await self.exportAsset(asset)
                    let filename = self.formatFilename(asset: asset)
                    let takenAt = ISO8601DateFormatter().string(from: asset.creationDate ?? Date())
                    _ = try await self.api.uploadPhoto(
                        data: data,
                        filename: filename,
                        takenAt: takenAt,
                        deviceId: deviceId
                    )
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
                sem.signal()
            }
            sem.wait()
        }
        operationQueue.addOperation(operation)
    }

    func cancelAll() {
        operationQueue.cancelAllOperations()
    }

    private func exportAsset(_ asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "ExportError", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: "Не удалось экспортировать фото"
                    ]))
                }
            }
        }
    }

    private func formatFilename(asset: PHAsset) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = formatter.string(from: asset.creationDate ?? Date())
        let ext = asset.mediaType == .video ? "mov" : "jpg"
        return "\(dateStr)_ios.\(ext)"
    }
}
