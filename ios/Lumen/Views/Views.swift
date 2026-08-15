import SwiftUI
import Photos

// MARK: - Color Theme

extension Color {
    static let lumenBg = Color(red: 0.06, green: 0.07, blue: 0.09)        // #0f1117
    static let lumenCard = Color(red: 0.10, green: 0.11, blue: 0.15)      // #1a1d27
    static let lumenAccent = Color(red: 0.39, green: 0.40, blue: 0.94)    // #6366f1
    static let lumenAccentLight = Color(red: 0.51, green: 0.55, blue: 0.97) // #818cf8
    static let lumenText = Color(red: 0.91, green: 0.91, blue: 0.93)      // #e8e8ed
    static let lumenTextSecondary = Color(red: 0.60, green: 0.60, blue: 0.69) // #9a9ab0
    static let lumenBorder = Color(red: 0.18, green: 0.19, blue: 0.25)    // #2d3040
}

// MARK: - Content View (Root Router)

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var sync: SyncManager
    
    var body: some View {
        ZStack {
            Color.lumenBg.ignoresSafeArea()
            
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
        .tint(.lumenAccent)
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
    @FocusState private var focusedField: Field?
    
    enum Field {
        case server, username, password
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.lumenAccent)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text("Lumen")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.lumenText)
                
                Text("Your photos, your server")
                    .font(.subheadline)
                    .foregroundColor(.lumenTextSecondary)
            }
            .padding(.bottom, 48)
            
            // Form
            VStack(spacing: 16) {
                // Server URL
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.lumenTextSecondary)
                        .frame(width: 20)
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .server)
                }
                .padding(14)
                .background(Color.lumenCard)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .server ? Color.lumenAccent : Color.lumenBorder, lineWidth: 1)
                )
                
                // Username
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.lumenTextSecondary)
                        .frame(width: 20)
                    TextField("Username", text: $username)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .username)
                }
                .padding(14)
                .background(Color.lumenCard)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .username ? Color.lumenAccent : Color.lumenBorder, lineWidth: 1)
                )
                
                // Password
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.lumenTextSecondary)
                        .frame(width: 20)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .password)
                }
                .padding(14)
                .background(Color.lumenCard)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .password ? Color.lumenAccent : Color.lumenBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            
            // Error
            if !error.isEmpty {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 8)
            }
            
            // Button
            Button(action: handleLogin) {
                HStack {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isSetup ? "Create Account" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.lumenAccent)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
            .opacity(auth.isLoading || username.isEmpty || password.isEmpty ? 0.6 : 1)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        }
        .onSubmit {
            switch focusedField {
            case .server: focusedField = .username
            case .username: focusedField = .password
            case .password: handleLogin()
            case .none: break
            }
        }
    }
    
    private func handleLogin() {
        guard !serverURL.isEmpty else {
            error = "Server URL required"
            return
        }
        UserDefaults.standard.set(serverURL, forKey: "server_url")
        focusedField = nil
        
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
        NavigationStack {
            ZStack {
                Color.lumenBg.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.lumenAccent)
                } else if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.lumenTextSecondary)
                        Text("No photos yet")
                            .font(.title3)
                            .foregroundColor(.lumenTextSecondary)
                        Text("Upload photos from the web UI or iOS app")
                            .font(.subheadline)
                            .foregroundColor(.lumenTextSecondary.opacity(0.7))
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
                                            .fill(Color.lumenCard)
                                            .aspectRatio(1, contentMode: .fill)
                                            .overlay(
                                                ProgressView()
                                                    .tint(.lumenAccent)
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadPhotos()
            }
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
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/original")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .white)
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    
                    Link(destination: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/original")!) {
                        Image(systemName: "arrow.down.to.line")
                            .foregroundColor(.white)
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
        NavigationStack {
            ZStack {
                Color.lumenBg.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.lumenAccent)
                } else if albums.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.lumenTextSecondary)
                        Text("No albums yet")
                            .font(.title3)
                            .foregroundColor(.lumenTextSecondary)
                        Text("Create an album to organize your photos")
                            .font(.subheadline)
                            .foregroundColor(.lumenTextSecondary.opacity(0.7))
                    }
                } else {
                    List(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            HStack(spacing: 12) {
                                if let coverId = album.coverPhotoId {
                                    AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(coverId)/thumbnail")) { image in
                                        image.resizable()
                                            .frame(width: 56, height: 56)
                                            .cornerRadius(10)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.lumenCard)
                                            .frame(width: 56, height: 56)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.lumenAccent.opacity(0.2))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(.lumenAccent)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(album.name)
                                        .font(.headline)
                                        .foregroundColor(.lumenText)
                                    Text("\(album.photoCount ?? 0) photos")
                                        .font(.subheadline)
                                        .foregroundColor(.lumenTextSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingNewAlbum = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.lumenAccent)
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
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    let album: Album
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 200), spacing: 2)
    ]
    
    var body: some View {
        ZStack {
            Color.lumenBg.ignoresSafeArea()
            
            if let photos = album.photos, !photos.isEmpty {
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
                                        .fill(Color.lumenCard)
                                        .aspectRatio(1, contentMode: .fill)
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.lumenTextSecondary)
                    Text("No photos in this album")
                        .font(.title3)
                        .foregroundColor(.lumenTextSecondary)
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 200), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.lumenBg.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.lumenAccent)
                } else if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star")
                            .font(.system(size: 48))
                            .foregroundColor(.lumenTextSecondary)
                        Text("No favorites yet")
                            .font(.title3)
                            .foregroundColor(.lumenTextSecondary)
                        Text("Star photos in Timeline to add them here")
                            .font(.subheadline)
                            .foregroundColor(.lumenTextSecondary.opacity(0.7))
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
                                            .fill(Color.lumenCard)
                                            .aspectRatio(1, contentMode: .fill)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
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
        NavigationStack {
            ZStack {
                Color.lumenBg.ignoresSafeArea()
                
                Form {
                    Section {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.lumenAccent)
                                .frame(width: 24)
                            TextField("Server URL", text: $serverURL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onSubmit {
                                    UserDefaults.standard.set(serverURL, forKey: "server_url")
                                }
                        }
                    } header: {
                        Text("Server")
                    }
                    
                    Section {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.lumenAccent)
                                .frame(width: 24)
                            Text("Status")
                            Spacer()
                            Text(sync.isSyncing ? "Syncing..." : "Idle")
                                .foregroundColor(.lumenTextSecondary)
                        }
                        
                        if let lastSync = sync.lastSyncDate {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.lumenAccent)
                                    .frame(width: 24)
                                Text("Last Sync")
                                Spacer()
                                Text(lastSync.formatted())
                                    .foregroundColor(.lumenTextSecondary)
                            }
                        }
                        
                        Button(action: {
                            Task {
                                await sync.performFullSync()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.lumenAccent)
                                    .frame(width: 24)
                                Text("Sync Now")
                            }
                        }
                    } header: {
                        Text("Sync")
                    }
                    
                    Section {
                        if let user = auth.user {
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.lumenAccent)
                                    .frame(width: 24)
                                Text("Username")
                                Spacer()
                                Text(user.username)
                                    .foregroundColor(.lumenTextSecondary)
                            }
                            
                            HStack {
                                Image(systemName: "shield")
                                    .foregroundColor(.lumenAccent)
                                    .frame(width: 24)
                                Text("Admin")
                                Spacer()
                                Text(user.isAdmin ? "Yes" : "No")
                                    .foregroundColor(.lumenTextSecondary)
                            }
                        }
                        
                        Button(action: { showingLogoutAlert = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                            }
                        }
                    } header: {
                        Text("Account")
                    }
                    
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("Lumen")
                                    .font(.headline)
                                    .foregroundColor(.lumenText)
                                Text("v1.0.0")
                                    .font(.caption)
                                    .foregroundColor(.lumenTextSecondary)
                            }
                            Spacer()
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
}
