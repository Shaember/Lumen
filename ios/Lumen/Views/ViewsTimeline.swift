import SwiftUI
import Photos

enum TimelineSection: Identifiable {
    case year(key: String, label: String)
    case month(key: String, label: String, items: [Photo])
    var id: String {
        switch self {
        case .year(let key, _): return "y-\(key)"
        case .month(let key, _, _): return "m-\(key)"
        }
    }
}

struct TimelineView: View {
    @State private var photos: [Photo] = []
    @State private var isLoading = true
    @State private var selectedPhoto: Photo?
    @State private var loadError: String?
    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]
    private var sections: [TimelineSection] { Self.buildSections(photos) }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenAtmosphere()
                if isLoading {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<12, id: \.self) { _ in Rectangle().fill(Color.lumenRaised).aspectRatio(1, contentMode: .fit) }
                    }
                } else if let loadError {
                    VStack(spacing: 12) {
                        Text(loadError).font(.body).foregroundStyle(Color.lumenDanger).multilineTextAlignment(.center)
                        Button("Повторить") { Task { await loadPhotos() } }.foregroundStyle(Color.lumenAccent)
                    }.padding()
                } else if photos.isEmpty {
                    Text("Пока нет фотографий").font(.body).foregroundStyle(Color.lumenMuted)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(sections) { section in
                                switch section {
                                case .year(_, let label):
                                    Section { EmptyView() } header: {
                                        Text(label).font(.system(size: 32, weight: .semibold)).tracking(-0.4)
                                            .foregroundStyle(Color.lumenText).shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 10)
                                            .frame(height: 84, alignment: .bottom)
                                            .background(LinearGradient(colors: [Color.lumenBg.opacity(0.75), Color.lumenBg.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                                    }
                                case .month(_, let label, let items):
                                    Section {
                                        LazyVGrid(columns: columns, spacing: 2) {
                                            ForEach(items) { photo in
                                                PhotoThumbnailView(photo: photo).clipShape(Rectangle()).onTapGesture { selectedPhoto = photo }
                                            }
                                        }
                                    } header: {
                                        Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.lumenText)
                                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 6)
                                            .background(LinearGradient(colors: [Color.lumenBg.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Фото").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { TrashView() } label: { Image(systemName: "trash").foregroundStyle(Color.lumenAccent) }
                    .accessibilityLabel("Корзина")
                }
            }
            .fullScreenCover(item: $selectedPhoto) { photo in PhotoDetailView(photo: photo, allPhotos: photos) }
            .task { await loadPhotos() }
        }
    }

    private func loadPhotos() async {
        isLoading = true; loadError = nil
        do { photos = try await APIClient.shared.listAllPhotos() }
        catch { loadError = error.localizedDescription }
        isLoading = false
    }

    static func buildSections(_ photos: [Photo]) -> [TimelineSection] {
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        let monthFmt = DateFormatter(); monthFmt.locale = Locale(identifier: "ru_RU"); monthFmt.dateFormat = "LLLL yyyy"
        func date(of p: Photo) -> Date? {
            guard let raw = p.takenAt ?? p.createdAt else { return nil }
            return iso.date(from: raw) ?? isoBasic.date(from: raw)
        }
        let sorted = photos.sorted { (date(of: $0)?.timeIntervalSince1970 ?? 0) > (date(of: $1)?.timeIntervalSince1970 ?? 0) }
        var out: [TimelineSection] = []; var lastYear = ""; var lastMonth = ""; var bucket: [Photo] = []; var bucketLabel = ""; var bucketKey = ""
        func flush() { guard !bucket.isEmpty else { return }; out.append(.month(key: bucketKey, label: bucketLabel, items: bucket)); bucket = [] }
        for p in sorted {
            let d = date(of: p)
            let year = d.map { String(Calendar.current.component(.year, from: $0)) } ?? "unknown"
            let monthKey: String; let monthLabel: String
            if let d {
                let m = Calendar.current.component(.month, from: d)
                monthKey = "\(year)-\(String(format: "%02d", m))"
                let raw = monthFmt.string(from: d); monthLabel = raw.prefix(1).uppercased() + raw.dropFirst()
            } else { monthKey = "unknown"; monthLabel = "Без даты" }
            if year != lastYear { flush(); lastYear = year; lastMonth = ""; out.append(.year(key: year, label: year == "unknown" ? "Без даты" : year)) }
            if monthKey != lastMonth { flush(); lastMonth = monthKey; bucketKey = monthKey; bucketLabel = monthLabel }
            bucket.append(p)
        }
        flush(); return out
    }
}

struct TrashView: View {
    @State private var photos: [Photo] = []; @State private var isLoading = true; @State private var showEmptyStub = false
    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]
    var body: some View {
        ZStack {
            LumenAtmosphere()
            if isLoading { ProgressView().tint(Color.lumenAccent) }
            else if photos.isEmpty { Text("Корзина пуста").foregroundStyle(Color.lumenMuted) }
            else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            PhotoThumbnailView(photo: photo).opacity(0.7).onTapGesture {
                                Task { try? await APIClient.shared.restorePhoto(id: photo.id); photos.removeAll { $0.id == photo.id } }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Корзина").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Очистить") { showEmptyStub = true }.foregroundStyle(Color.lumenDanger).disabled(photos.isEmpty) } }
        .alert("Очистка корзины", isPresented: $showEmptyStub) { Button("Понятно", role: .cancel) {} } message: { Text("API очистки корзины ещё нет (docs/API_GAPS.md).") }
        .task { do { photos = try await APIClient.shared.listTrash() } catch { photos = [] }; isLoading = false }
    }
}

struct PhotoThumbnailView: View {
    let photo: Photo
    var body: some View {
        GeometryReader { geo in
            AuthImage(url: mediaURL(photo.id, thumb: true), contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.width).clipped()
        }.aspectRatio(1, contentMode: .fit)
    }
}

func mediaURL(_ id: Int64, thumb: Bool) -> URL? {
    let base = UserDefaults.standard.string(forKey: "server_url") ?? ""
    return URL(string: "\(base)/api/v1/photos/\(id)/\(thumb ? "thumbnail" : "original")")
}

struct PhotoDetailView: View {
    let photo: Photo; var allPhotos: [Photo] = []
    @Environment(\.dismiss) private var dismiss
    @State private var isFavorite = false; @State private var showingDeleteAlert = false
    @State private var scale: CGFloat = 1.0; @State private var lastScale: CGFloat = 1.0; @State private var currentId: Int64 = 0
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AuthImage(url: mediaURL(currentId, thumb: false), contentMode: .fit)
                .scaleEffect(scale)
                .gesture(MagnificationGesture().onChanged { v in scale = lastScale * v }.onEnded { _ in lastScale = scale })
                .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.16)) { scale = 1.0; lastScale = 1.0 } }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(Color.lumenText).frame(width: 44, height: 44) }
                Spacer()
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Color.lumenAccent : Color.lumenText).frame(width: 44, height: 44)
                }
                Button { showingDeleteAlert = true } label: { Image(systemName: "trash").foregroundStyle(Color.lumenText).frame(width: 44, height: 44) }
            }.padding(.horizontal, 8).background(.ultraThinMaterial)
        }
        .alert("Удалить фото?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) { Task { try? await APIClient.shared.deletePhoto(id: currentId); dismiss() } }
        }
        .onAppear { currentId = photo.id; isFavorite = photo.isFavorite }
    }
    private func toggleFavorite() { Task { if let v = try? await APIClient.shared.toggleFavorite(id: currentId) { isFavorite = v } } }
}
