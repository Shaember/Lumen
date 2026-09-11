import SwiftUI
import Photos

// MARK: - Favorites
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
                Color.lumenBg.ignoresSafeArea()
                if isLoading {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<9, id: \.self) { _ in
                            Rectangle().fill(Color.lumenRaised).aspectRatio(1, contentMode: .fit)
                        }
                    }
                } else if photos.isEmpty {
                    Text("В избранном пока пусто")
                        .foregroundStyle(Color.lumenMuted)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .onTapGesture { selectedPhoto = photo }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Избранное")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo, allPhotos: photos)
            }
            .task {
                do {
                    let all = try await APIClient.shared.listAllPhotos()
                    photos = all.filter { $0.isFavorite }
                } catch { print(error) }
                isLoading = false
            }
        }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var sync: SyncManager
    @State private var serverURL = ""
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.lumenBg.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(Color.lumenAccent)
                                .frame(width: 24)
                            TextField("Адрес сервера", text: $serverURL)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .onSubmit {
                                    UserDefaults.standard.set(serverURL, forKey: "server_url")
                                }
                        }
                    } header: { Text("Сервер") }
                    
                    Section {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.lumenAccent)
                                .frame(width: 24)
                            Text("Статус")
                            Spacer()
                            Text(sync.isSyncing ? "Синхронизация…" : "Ожидание")
                                .foregroundStyle(Color.lumenMuted)
                        }
                        Button {
                            Task { await sync.performFullSync() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(Color.lumenAccent)
                                    .frame(width: 24)
                                Text("Синхронизировать")
                                    .foregroundStyle(Color.lumenText)
                            }
                        }
                    } header: { Text("Синхронизация") }
                    
                    Section {
                        if let user = auth.user {
                            HStack {
                                Image(systemName: "person")
                                    .foregroundStyle(Color.lumenAccent)
                                    .frame(width: 24)
                                Text("Пользователь")
                                Spacer()
                                Text(user.username).foregroundStyle(Color.lumenMuted)
                            }
                        }
                        Button { showingLogoutAlert = true } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(Color.lumenDanger)
                                    .frame(width: 24)
                                Text("Выйти").foregroundStyle(Color.lumenDanger)
                            }
                        }
                    } header: { Text("Аккаунт") }
                    
                    Section {
                        Text("ATS / AsyncImage: медиа без Authorization header — см. docs/API_GAPS.md")
                            .font(.caption)
                            .foregroundStyle(Color.lumenMuted)
                    } header: { Text("Заметки") }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
            }
            .alert("Выйти?", isPresented: $showingLogoutAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Выйти", role: .destructive) { auth.logout() }
            }
        }
    }
}
