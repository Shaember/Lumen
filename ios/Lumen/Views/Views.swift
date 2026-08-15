import SwiftUI
import Photos

// MARK: - Color Theme
extension Color {
    static let lumenBg = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let lumenCard = Color(red: 0.10, green: 0.11, blue: 0.15)
    static let lumenAccent = Color(red: 0.39, green: 0.40, blue: 0.94)
    static let lumenAccentLight = Color(red: 0.51, green: 0.55, blue: 0.97)
    static let lumenText = Color(red: 0.91, green: 0.91, blue: 0.93)
    static let lumenTextSecondary = Color(red: 0.60, green: 0.60, blue: 0.69)
    static let lumenBorder = Color(red: 0.18, green: 0.19, blue: 0.25)
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var sync: SyncManager
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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
                    Label("Photos", systemImage: "photo.fill")
                }
            
            AlbumsListView()
                .tabItem {
                    Label("Albums", systemImage: "rectangle.stack.fill")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.yellow)
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
    
    enum Field { case server, username, password }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                    
                    Text("Lumen")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Your photos, your server")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .padding(.bottom, 40)
                
                // Form
                VStack(spacing: 14) {
                    // Server URL
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.gray)
                            .frame(width: 20)
                        TextField("Server URL", text: $serverURL)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .foregroundStyle(.white)
                            .focused($focusedField, equals: .server)
                    }
                    .padding(14)
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .server ? Color.yellow : Color.clear, lineWidth: 1)
                    )
                    
                    // Username
                    HStack {
                        Image(systemName: "person")
                            .foregroundStyle(.gray)
                            .frame(width: 20)
                        TextField("Username", text: $username)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundStyle(.white)
                            .focused($focusedField, equals: .username)
                    }
                    .padding(14)
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .username ? Color.yellow : Color.clear, lineWidth: 1)
                    )
                    
                    // Password
                    HStack {
                        Image(systemName: "lock")
                            .foregroundStyle(.gray)
                            .frame(width: 20)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .focused($focusedField, equals: .password)
                    }
                    .padding(14)
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .password ? Color.yellow : Color.clear, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                
                // Error
                if !error.isEmpty {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.top, 12)
                }
                
                // Button
                Button(action: handleLogin) {
                    Text(isSetup ? "Create Account" : "Sign In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.yellow)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
                .opacity(auth.isLoading || username.isEmpty || password.isEmpty ? 0.6 : 1)
                
                Spacer()
                Spacer()
            }
        }
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

// MARK: - Timeline View (Apple Photos Style)
struct TimelineView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var selectedPhoto: Photo?
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 56))
                            .foregroundStyle(.gray)
                        Text("No Photos")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Text("Photos you add will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
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
}

// MARK: - Photo Thumbnail
struct PhotoThumbnailView: View {
    let photo: Photo
    
    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/thumbnail")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        )
                default:
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(ProgressView().tint(.gray))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Photo Detail View
struct PhotoDetailView: View {
    let photo: Photo
    @Environment(\.dismiss) private var dismiss
    @State private var isFavorite = false
    @State private var showingDeleteAlert = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/original")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = scale
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        }
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        Text("Failed to load")
                            .foregroundStyle(.gray)
                    }
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.yellow)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 20) {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : .white)
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.white)
                    }
                    
                    ShareLink(item: URL(string: "\(serverURL)/api/v1/photos/\(photo.id)/original")!) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .alert("Delete Photo?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await APIClient.shared.deletePhoto(id: photo.id)
                    dismiss()
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
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if albums.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 56))
                            .foregroundStyle(.gray)
                        Text("No Albums")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Text("Create albums to organize your photos")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                } else {
                    List {
                        Section {
                            ForEach(albums) { album in
                                NavigationLink(destination: AlbumDetailView(album: album)) {
                                    HStack(spacing: 12) {
                                        if let coverId = album.coverPhotoId {
                                            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(coverId)/thumbnail")) { image in
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } placeholder: {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(white: 0.15))
                                                    .frame(width: 60, height: 60)
                                            }
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.yellow.opacity(0.2))
                                                .frame(width: 60, height: 60)
                                                .overlay(
                                                    Image(systemName: "rectangle.stack.fill")
                                                        .foregroundStyle(.yellow)
                                                )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(album.name)
                                                .foregroundStyle(.white)
                                            Text("\(album.photoCount ?? 0) photos")
                                                .font(.subheadline)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingNewAlbum = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.yellow)
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
    @State private var selectedPhoto: Photo?
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let photos = album.photos, !photos.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            PhotoThumbnailView(photo: photo)
                                .onTapGesture {
                                    selectedPhoto = photo
                                }
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 56))
                        .foregroundStyle(.gray)
                    Text("No Photos")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
    }
}

// MARK: - Favorites View
struct FavoritesView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var selectedPhoto: Photo?
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 56))
                            .foregroundStyle(.gray)
                        Text("No Favorites")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Text("Photos you favorite will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
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
                Color.black.ignoresSafeArea()
                
                List {
                    Section {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.yellow)
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
                                .foregroundStyle(.yellow)
                                .frame(width: 24)
                            Text("Status")
                            Spacer()
                            Text(sync.isSyncing ? "Syncing..." : "Idle")
                                .foregroundStyle(.gray)
                        }
                        
                        Button(action: {
                            Task {
                                await sync.performFullSync()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.yellow)
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
                                    .foregroundStyle(.yellow)
                                    .frame(width: 24)
                                Text("Username")
                                Spacer()
                                Text(user.username)
                                    .foregroundStyle(.gray)
                            }
                        }
                        
                        Button(action: { showingLogoutAlert = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.red)
                                    .frame(width: 24)
                                Text("Sign Out")
                                    .foregroundStyle(.red)
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
                                    .foregroundStyle(.white)
                                Text("v1.0.0")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                        }
                    }
                }
                .listStyle(.insetGrouped)
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
