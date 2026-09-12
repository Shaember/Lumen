import SwiftUI
import Photos

// MARK: - Design tokens (DESIGN_SYSTEM.md)
extension Color {
    static let lumenBg = Color(red: 16/255, green: 14/255, blue: 12/255)           // #100E0C (Designer canvas)
    static let lumenRaised = Color(red: 20/255, green: 20/255, blue: 20/255)       // #141414
    static let lumenRaised2 = Color(red: 26/255, green: 26/255, blue: 26/255)      // #1A1A1A
    static let lumenAccent = Color(red: 232/255, green: 228/255, blue: 217/255)    // #E8E4D9
    static let lumenAccentInk = Color(red: 10/255, green: 10/255, blue: 10/255)
    static let lumenText = Color(red: 244/255, green: 241/255, blue: 234/255)      // #F4F1EA
    static let lumenMuted = Color(red: 138/255, green: 133/255, blue: 120/255)     // #8A8578
    static let lumenDanger = Color(red: 226/255, green: 75/255, blue: 75/255)      // #E24B4B
    static let lumenHairline = Color(red: 232/255, green: 228/255, blue: 217/255).opacity(0.12)
    // Legacy aliases
    static let lumenCard = lumenRaised
    static let lumenAccentLight = lumenAccent
    static let lumenTextSecondary = lumenMuted
    static let lumenBorder = lumenHairline
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var sync: SyncManager
    
    var body: some View {
        ZStack {
            LumenAtmosphere()
            
            if auth.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if auth.isLoggedIn {
                await sync.performFullSync()
            }
        }
    }
}

// MARK: - Main Tab View
// Photos · Albums · Favorites · Settings. Trash via Photos toolbar (not 5th tab).
struct MainTabView: View {
    var body: some View {
        TabView {
            TimelineView()
                .tabItem {
                    Label("Фото", systemImage: "photo")
                }
            
            AlbumsListView()
                .tabItem {
                    Label("Альбомы", systemImage: "rectangle.stack")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Избранное", systemImage: "heart")
                }
            
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
        }
        .tint(Color.lumenAccent)
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
            // Atmospheric mesh so frost panel glass has something to blur
            LumenAtmosphere()
            
            VStack {
                Spacer()
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Color.lumenAccent)
                        
                        Text("Lumen")
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .foregroundStyle(Color.lumenText)
                            .tracking(-0.5)
                        
                        Text(isSetup ? "Создайте учётную запись" : "Your photos, your server")
                            .font(.subheadline)
                            .foregroundStyle(Color.lumenMuted)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 10) {
                        fieldRow(icon: "globe", field: .server) {
                            TextField("Адрес сервера", text: $serverURL)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                                .foregroundStyle(Color.lumenText)
                                .focused($focusedField, equals: .server)
                        }
                        
                        fieldRow(icon: "person", field: .username) {
                            TextField("Имя пользователя", text: $username)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .foregroundStyle(Color.lumenText)
                                .focused($focusedField, equals: .username)
                        }
                        
                        fieldRow(icon: "lock", field: .password) {
                            SecureField("Пароль", text: $password)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.lumenText)
                                .focused($focusedField, equals: .password)
                        }
                    }
                    
                    if !error.isEmpty {
                        Text(error)
                            .foregroundStyle(Color.lumenDanger)
                            .font(.caption)
                    }
                    
                    Button(action: handleLogin) {
                        Text(isSetup ? "Создать аккаунт" : "Войти")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.lumenAccent)
                            .foregroundStyle(Color.lumenAccentInk)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
                    .opacity(auth.isLoading || username.isEmpty || password.isEmpty ? 0.4 : 1)
                    
                    Button(isSetup ? "Уже есть аккаунт? Войти" : "Первый раз? Создать аккаунт") {
                        isSetup.toggle()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.lumenAccent)
                }
                .padding(20)
                .frame(maxWidth: 360)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.lumenHairline, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                Spacer()
            }
        }
        .onAppear {
            serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        }
    }
    
    @ViewBuilder
    private func fieldRow<Content: View>(icon: String, field: Field, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.lumenMuted)
                .frame(width: 20)
            content()
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color.lumenRaised)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(focusedField == field ? Color.lumenAccent : Color.lumenHairline, lineWidth: 1)
        )
    }
    
    private func handleLogin() {
        guard !serverURL.isEmpty else {
            error = "Укажите адрес сервера"
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
                    error = "Неверные данные"
                }
            }
        }
    }
}


// MARK: - Atmospheric canvas (Designer lock: #100E0C + washes + ~4% grain)
struct LumenAtmosphere: View {
    var body: some View {
        ZStack {
            Color.lumenBg
            // Top-left warm wash ~80vmax equivalent
            RadialGradient(
                colors: [Color(red: 232/255, green: 228/255, blue: 217/255).opacity(0.09), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            // Bottom-right brown wash
            RadialGradient(
                colors: [Color(red: 90/255, green: 70/255, blue: 50/255).opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 460
            )
            // Edge vignette
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                center: .center,
                startRadius: 120,
                endRadius: 700
            )
            // Grain ~4% (Designer: do not raise to 8–15%)
            Canvas { ctx, size in
                for _ in 0..<900 {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let r = CGFloat.random(in: 0.4...1.1)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(0.045))
                    )
                }
            }
            .allowsHitTesting(false)
            .blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}
