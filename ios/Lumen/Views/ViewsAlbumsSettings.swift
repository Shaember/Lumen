import SwiftUI
import Photos

struct AlbumsListView: View {
    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var showingNewAlbum = false
    @State private var newAlbumName = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LumenAtmosphere()
                if isLoading {
                    ProgressView().tint(Color.lumenAccent)
                } else if albums.isEmpty {
                    VStack(spacing: 12) {
                        Text("Альбомов пока нет")
                            .foregroundStyle(Color.lumenMuted)
                        Button("Создать альбом") { showingNewAlbum = true }
                            .foregroundStyle(Color.lumenAccent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(albums) { album in
                                NavigationLink(destination: AlbumDetailView(album: album)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        AlbumMosaicCover(coverPhotoId: album.coverPhotoId)
                                        Text(album.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.lumenText)
                                            .lineLimit(1)
                                        Text("\(album.photoCount ?? 0) фото")
                                            .font(.caption)
                                            .foregroundStyle(Color.lumenMuted)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Альбомы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingNewAlbum = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.lumenAccent)
                    }
                }
            }
            .alert("Новый альбом", isPresented: $showingNewAlbum) {
                TextField("Название", text: $newAlbumName)
                Button("Создать") {
                    Task {
                        if let album = try? await APIClient.shared.createAlbum(name: newAlbumName) {
                            albums.append(album)
                            newAlbumName = ""
                        }
                    }
                }
                Button("Отмена", role: .cancel) { newAlbumName = "" }
            }
            .task {
                do { albums = try await APIClient.shared.listAlbums() } catch { print(error) }
                isLoading = false
            }
        }
    }
}

struct AlbumMosaicCover: View {
    let coverPhotoId: Int64?

    var body: some View {
        Group {
            if let coverId = coverPhotoId {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
                    ForEach(0..<4, id: \.self) { _ in
                        AuthImage(url: mediaURL(coverId, thumb: true), contentMode: .fill)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.lumenHairline, lineWidth: 1)
                )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.lumenHairline)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "rectangle.stack")
                            .foregroundStyle(Color.lumenMuted)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct AlbumDetailView: View {
    let album: Album
    @State private var selectedPhoto: Photo?
    @State private var detail: Album?
    @State private var selecting = false
    @State private var selectedIds: Set<Int64> = []
    @State private var showAdd = false
    @State private var library: [Photo] = []
    @State private var librarySelection: Set<Int64> = []

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var photos: [Photo] { detail?.photos ?? album.photos ?? [] }

    var body: some View {
        ZStack {
            LumenAtmosphere()
            if photos.isEmpty {
                VStack(spacing: 12) {
                    Text("В альбоме нет фотографий")
                        .foregroundStyle(Color.lumenMuted)
                    Button("Добавить") { showAdd = true }
                        .foregroundStyle(Color.lumenAccent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { photo in
                            PhotoThumbnailView(photo: photo)
                                .opacity(selectedIds.contains(photo.id) ? 0.88 : 1)
                                .overlay(alignment: .topTrailing) {
                                    if selecting {
                                        Image(systemName: selectedIds.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(Color.lumenAccent)
                                            .padding(6)
                                    }
                                }
                                .onTapGesture {
                                    if selecting {
                                        if selectedIds.contains(photo.id) {
                                            selectedIds.remove(photo.id)
                                        } else {
                                            selectedIds.insert(photo.id)
                                        }
                                    } else {
                                        selectedPhoto = photo
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(selecting ? "Готово" : "Выбрать") {
                    selecting.toggle()
                    selectedIds.removeAll()
                }
                .foregroundStyle(Color.lumenAccent)
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.lumenAccent)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting && !selectedIds.isEmpty {
                HStack {
                    Text("\(selectedIds.count)")
                        .font(.body.weight(.semibold))
                    Spacer()
                    Button(role: .destructive) {
                        Task { await removeSelected() }
                    } label: {
                        Label("Из альбома", systemImage: "xmark")
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(.ultraThinMaterial)
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, allPhotos: photos)
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                ZStack {
                    LumenAtmosphere()
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(library) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: librarySelection.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(Color.lumenAccent)
                                            .padding(6)
                                    }
                                    .onTapGesture {
                                        if librarySelection.contains(photo.id) {
                                            librarySelection.remove(photo.id)
                                        } else {
                                            librarySelection.insert(photo.id)
                                        }
                                    }
                            }
                        }
                    }
                }
                .navigationTitle("Добавить фото")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Добавить") {
                            Task { await addSelected() }
                        }
                        .disabled(librarySelection.isEmpty)
                    }
                }
                .task { await loadLibrary() }
            }
            .tint(Color.lumenAccent)
            .presentationBackground(Color.lumenRaised)
        }
        .task { await reload() }
    }

    private func reload() async {
        detail = try? await APIClient.shared.getAlbum(id: album.id)
    }

    private func loadLibrary() async {
        let all = (try? await APIClient.shared.listAllPhotos()) ?? []
        let existing = Set(photos.map(\ .id))
        library = all.filter { !existing.contains($0.id) }
        librarySelection.removeAll()
    }

    private func addSelected() async {
        do {
            try await APIClient.shared.addPhotosToAlbum(id: album.id, photoIds: Array(librarySelection))
            showAdd = false
            await reload()
        } catch { print(error) }
    }

    private func removeSelected() async {
        do {
            for id in selectedIds {
                try await APIClient.shared.removePhotoFromAlbum(albumId: album.id, photoId: id)
            }
            selecting = false
            selectedIds.removeAll()
            await reload()
        } catch { print(error) }
    }
}
