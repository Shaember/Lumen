import SwiftUI
import Photos

// MARK: - Design tokens (DESIGN_SYSTEM.md)
extension Color {
    static let lumenBg = Color(red: 10/255, green: 10/255, blue: 10/255)           // #0A0A0A
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
            Color.lumenBg.ignoresSafeArea()
            
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
            Color.lumenBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Color.lumenAccent)
                    
                    Text("Lumen")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.lumenText)
                        .tracking(-0.5)
                    
                    Text(isSetup ? "Создайте учётную запись" : "Your photos, your server")
                        .font(.subheadline)
                        .foregroundStyle(Color.lumenMuted)
                }
                .padding(.bottom, 40)
                
                VStack(spacing: 12) {
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
                .padding(.horizontal, 20)
                .frame(maxWidth: 360)
                
                if !error.isEmpty {
                    Text(error)
                        .foregroundStyle(Color.lumenDanger)
                        .font(.caption)
                        .padding(.top, 12)
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
                .padding(.horizontal, 20)
                .frame(maxWidth: 360)
                .padding(.top, 20)
                .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
                .opacity(auth.isLoading || username.isEmpty || password.isEmpty ? 0.4 : 1)
                
                Button(isSetup ? "Уже есть аккаунт? Войти" : "Первый раз? Создать аккаунт") {
                    isSetup.toggle()
                }
                .font(.caption)
                .foregroundStyle(Color.lumenAccent)
                .padding(.top, 16)
                
                Spacer()
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
