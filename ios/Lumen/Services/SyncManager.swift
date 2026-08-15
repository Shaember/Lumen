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
    
    private let api = APIClient.shared
    
    func loadTokens() {
        api.loadTokens()
        if api.getAccessToken() != nil {
            Task {
                await fetchUser()
            }
        }
    }
    
    func login(username: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await api.login(username: username, password: password)
            isLoggedIn = true
        } catch {
            print("Login failed: \(error)")
        }
    }
    
    func setup(username: String, password: String) async throws {
        try await api.setup(username: username, password: password)
    }
    
    func logout() {
        api.clearTokens()
        user = nil
        isLoggedIn = false
    }
    
    private func fetchUser() async {
        // Token exists, assume logged in for now
        isLoggedIn = true
    }
}

// MARK: - Sync Manager

class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0
    
    private let api = APIClient.shared
    private let uploadQueue = UploadQueue()
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.lumen.photosync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.lumen.photosync.refresh",
            using: nil
        ) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: "com.lumen.photosync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.lumen.photosync.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func handleBackgroundSync(task: BGProcessingTask) {
        scheduleBackgroundSync() // Schedule next
        
        Task {
            await performFullSync()
            task.setTaskCompleted(success: true)
        }
        
        task.expirationHandler = {
            self.uploadQueue.cancelAll()
        }
    }
    
    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh()
        
        let operation = Task {
            await performIncrementalSync()
        }
        
        task.expirationHandler = {
            operation.cancel()
        }
    }
    
    func performFullSync() async {
        isSyncing = true
        defer { isSyncing = false }
        
        await syncDeviceRegistration()
        await syncNewPhotos()
        lastSyncDate = Date()
    }
    
    func performIncrementalSync() async {
        await syncNewPhotos()
        lastSyncDate = Date()
    }
    
    private func syncDeviceRegistration() async {
        let deviceName = await UIDevice.current.name
        do {
            _ = try await api.registerDevice(name: deviceName, pushToken: nil)
        } catch {
            print("Device registration failed: \(error)")
        }
    }
    
    private func syncNewPhotos() async {
        // Fetch last sync date from server or use local
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
        
        var uploaded = 0
        let total = assets.count
        
        assets.enumerateObjects { asset, _, _ in
            self.uploadQueue.enqueue(asset: asset) { [weak self] result in
                switch result {
                case .success:
                    uploaded += 1
                    Task { @MainActor in
                        self?.syncProgress = Double(uploaded) / Double(total)
                    }
                case .failure(let error):
                    print("Upload failed for asset: \(error)")
                }
            }
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
    
    func enqueue(asset: PHAsset, completion: @escaping (Result<Void, Error>) -> Void) {
        let operation = BlockOperation { [weak self] in
            guard let self = self else { return }
            
            Task {
                do {
                    let data = try await self.exportAsset(asset)
                    let filename = self.formatFilename(asset: asset)
                    let takenAt = ISO8601DateFormatter().string(from: asset.creationDate ?? Date())
                    
                    _ = try await self.api.uploadPhoto(
                        data: data,
                        filename: filename,
                        takenAt: takenAt,
                        deviceId: nil
                    )
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        
        operationQueue.addOperation(operation)
    }
    
    func cancelAll() {
        operationQueue.cancelAllOperations()
    }
    
    private func exportAsset(_ asset: PHAsset) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "ExportError", code: 0))
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
