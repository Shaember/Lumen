import SwiftUI
import Photos

// MARK: - Content View (Root Router)

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var sync: SyncManager
    
    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            if auth.isLoggedIn {
                await sync.performFullSync()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "photo.on.rectangle")
                }
            
            AlbumsListView()
                .tabItem {
                    Label("Albums", systemImage: "folder")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var isSetup = false
    @State private var error = ""
    @State private var serverURL = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Lumen")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            TextField("Server URL", text: $serverURL)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            if !error.isEmpty {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: handleLogin) {
                if auth.isLoading {
                    ProgressView()
                } else {
                    Text(isSetup ? "Create Account" : "Sign In")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
        }
        .padding(40)
        .onAppear {
            serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        }
    }
    
    private func handleLogin() {
        guard !serverURL.isEmpty else {
            error = "Server URL required"
            return
        }
        UserDefaults.standard.set(serverURL, forKey: "server_url")
        
        Task {
            if isSetup {
                do {
                    try await auth.setup(username: username, password: password)
                    await auth.login(username: username, password: password)
                } catch {
                    self.error = error.localizedDescription
                }
            } else {
                await auth.login(username: username, password: password)
                if !auth.isLoggedIn {
                    error = "Invalid credentials"
                }
            }
        }
    }
}

// MARK: - Timeline View

struct TimelineView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 200), spacing: 2)
    ]
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No photos yet")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            NavigationLink(destination: PhotoDetailView(photo: photo)) {
                                AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/thumbnail")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .aspectRatio(1, contentMode: .fill)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Timeline")
        .task {
            await loadPhotos()
        }
    }
    
    private func loadPhotos() async {
        do {
            photos = try await APIClient.shared.listPhotos()
        } catch {
            print("Failed to load photos: \(error)")
        }
        isLoading = false
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    let photo: Photo
    @State private var isFavorite = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/original")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .primary)
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("Delete Photo?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await APIClient.shared.deletePhoto(id: photo.id)
                }
            }
        }
        .onAppear {
            isFavorite = photo.isFavorite
        }
    }
    
    private func toggleFavorite() {
        Task {
            isFavorite = try await APIClient.shared.toggleFavorite(id: photo.id)
        }
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Albums List View

struct AlbumsListView: View {
    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var showingNewAlbum = false
    @State private var newAlbumName = ""
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if albums.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No albums yet")
                        .foregroundColor(.secondary)
                }
            } else {
                List(albums) { album in
                    NavigationLink(destination: AlbumDetailView(album: album)) {
                        HStack {
                            if let coverId = album.coverPhotoId {
                                AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(coverId)/thumbnail")) { image in
                                    image.resizable().frame(width: 50, height: 50).cornerRadius(8)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                }
                            } else {
                                Image(systemName: "folder")
                                    .frame(width: 50, height: 50)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(album.name)
                                    .font(.headline)
                                Text("\(album.photoCount ?? 0) photos")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Albums")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingNewAlbum = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Album", isPresented: $showingNewAlbum) {
            TextField("Album name", text: $newAlbumName)
            Button("Create") {
                Task {
                    if let album = try? await APIClient.shared.createAlbum(name: newAlbumName) {
                        albums.append(album)
                        newAlbumName = ""
                    }
                }
            }
            Button("Cancel", role: .cancel) { newAlbumName = "" }
        }
        .task {
            do {
                albums = try await APIClient.shared.listAlbums()
            } catch {
                print("Failed to load albums: \(error)")
            }
            isLoading = false
        }
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    let album: Album
    
    var body: some View {
        Group {
            if let photos = album.photos, !photos.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 200), spacing: 2)
                    ], spacing: 2) {
                        ForEach(photos) { photo in
                            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/thumbnail")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(1, contentMode: .fill)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No photos in this album")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(album.name)
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No favorites yet")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 200), spacing: 2)
                    ], spacing: 2) {
                        ForEach(photos) { photo in
                            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/thumbnail")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(1, contentMode: .fill)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .task {
            do {
                let all = try await APIClient.shared.listPhotos()
                photos = all.filter { $0.isFavorite }
            } catch {
                print("Failed to load favorites: \(error)")
            }
            isLoading = false
        }
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var sync: SyncManager
    @State private var serverURL = ""
    @State private var showingLogoutAlert = false
    
    var body: some View {
        Form {
            Section("Server") {
                TextField("Server URL", text: $serverURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        UserDefaults.standard.set(serverURL, forKey: "server_url")
                    }
            }
            
            Section("Sync") {
                LabeledContent("Status", value: sync.isSyncing ? "Syncing..." : "Idle")
                if let lastSync = sync.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSync.formatted())
                }
                Button("Sync Now") {
                    Task {
                        await sync.performFullSync()
                    }
                }
            }
            
            Section("Account") {
                if let user = auth.user {
                    LabeledContent("Username", value: user.username)
                    LabeledContent("Admin", value: user.isAdmin ? "Yes" : "No")
                }
                
                Button("Sign Out", role: .destructive) {
                    showingLogoutAlert = true
                }
            }
            
            Section {
                Text("Lumen v1.0")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        }
        .alert("Sign Out?", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                auth.logout()
            }
        }
    }
}
