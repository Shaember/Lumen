import SwiftUI
import Photos

// MARK: - Timeline View
struct TimelineView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var selectedPhoto: Photo?
    @State private var showTrash = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    private var sections: [(key: String, label: String, items: [Photo])] {
        Self.groupByMonth(photos)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LumenAtmosphere()
                
                if isLoading {
                    // Skeleton — no spinner in grid
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<12, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.lumenRaised)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                } else if photos.isEmpty {
                    VStack(spacing: 12) {
                        Text("Пока нет фотографий")
                            .font(.body)
                            .foregroundStyle(Color.lumenMuted)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(sections, id: \.key) { section in
                                Section {
                                    LazyVGrid(columns: columns, spacing: 2) {
                                        ForEach(section.items) { photo in
                                            PhotoThumbnailView(photo: photo)
                                                .onTapGesture { selectedPhoto = photo }
                                        }
                                    }
                                } header: {
                                    Text(section.label)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(Color.lumenText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 10)
                                        .padding(.bottom, 6)
                                        .frame(minHeight: 72, alignment: .bottom)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.lumenBg.opacity(0.85), Color.lumenBg.opacity(0.35), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Фото")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        TrashView()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.lumenAccent)
                    }
                    .accessibilityLabel("Корзина")
                }
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo, allPhotos: photos)
            }
            .task { await loadPhotos() }
        }
    }
    
    private func loadPhotos() async {
        do {
            photos = try await APIClient.shared.listAllPhotos()
        } catch {
            print("Failed to load photos: \(error)")
        }
        isLoading = false
    }
    
    static func groupByMonth(_ photos: [Photo]) -> [(key: String, label: String, items: [Photo])] {
        let display = DateFormatter()
        display.locale = Locale(identifier: "ru_RU")
        display.dateFormat = "LLLL yyyy"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        var map: [String: [Photo]] = [:]
        var order: [String] = []
        for p in photos {
            let key: String
            if let raw = p.takenAt ?? Optional(p.createdAt),
               let date = iso.date(from: raw) ?? isoBasic.date(from: raw) ?? Self.parseLoose(raw) {
                key = display.string(from: date)
            } else {
                key = "Без даты"
            }
            if map[key] == nil {
                order.append(key)
                map[key] = []
            }
            map[key]?.append(p)
        }
        return order.map { (key: $0, label: $0.prefix(1).uppercased() + $0.dropFirst(), items: map[$0] ?? []) }
    }
    
    private static func parseLoose(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let d = f.date(from: raw) { return d }
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = f.date(from: raw) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(raw.prefix(10)))
    }
}

// MARK: - Trash View (from Photos toolbar)
struct TrashView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var showEmptyStub = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ZStack {
            LumenAtmosphere()
            if isLoading {
                ProgressView().tint(Color.lumenAccent)
            } else if photos.isEmpty {
                Text("Корзина пуста")
                    .foregroundStyle(Color.lumenMuted)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            PhotoThumbnailView(photo: photo)
                                .opacity(0.7)
                                .onTapGesture {
                                    Task {
                                        try? await APIClient.shared.restorePhoto(id: photo.id)
                                        photos.removeAll { $0.id == photo.id }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Корзина")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Очистить") { showEmptyStub = true }
                    .foregroundStyle(Color.lumenDanger)
                    .disabled(photos.isEmpty)
            }
        }
        .alert("Очистка корзины", isPresented: $showEmptyStub) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("API очистки корзины ещё нет (docs/API_GAPS.md).")
        }
        .task {
            do {
                photos = try await APIClient.shared.listTrash()
            } catch {
                photos = []
            }
            isLoading = false
        }
    }
}

// MARK: - Photo Thumbnail
// NOTE: AsyncImage does not send Authorization — ATS / auth headers still broken for media.
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
                        .fill(Color.lumenRaised)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(
                            Text("не загрузилось")
                                .font(.caption2)
                                .foregroundStyle(Color.lumenMuted)
                        )
                default:
                    Rectangle()
                        .fill(Color.lumenRaised)
                        .frame(width: geo.size.width, height: geo.size.width)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}

// MARK: - Photo Detail (immersive)
struct PhotoDetailView: View {
    let photo: Photo
    var allPhotos: [Photo] = []
    @Environment(\.dismiss) private var dismiss
    @State private var isFavorite = false
    @State private var showingDeleteAlert = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentId: Int64 = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: "\(serverURL)/api/v1/photos/\(currentId)/original")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in scale = lastScale * value }
                                .onEnded { _ in lastScale = scale }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        }
                case .failure:
                    Text("не загрузилось")
                        .foregroundStyle(Color.lumenMuted)
                default:
                    Rectangle().fill(Color.lumenRaised).frame(width: 80, height: 80)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.lumenText)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Color.lumenDanger : Color.lumenText)
                        .frame(width: 44, height: 44)
                }
                Button { showingDeleteAlert = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.lumenText)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial)
        }
        .alert("Удалить фото?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                Task {
                    try? await APIClient.shared.deletePhoto(id: currentId)
                    dismiss()
                }
            }
        }
        .onAppear {
            currentId = photo.id
            isFavorite = photo.isFavorite
        }
    }
    
    private func toggleFavorite() {
        Task {
            isFavorite = try await APIClient.shared.toggleFavorite(id: currentId)
        }
    }
    
    private var serverURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? ""
    }
}
