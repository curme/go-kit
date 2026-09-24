import SwiftUI

@main
@MainActor
struct GoKitApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.green)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var previewLesson: StudyLesson?
    #endif
    var body: some View {
        TabView {
            NavigationStack { LearnView() }
                .tabItem { Label("跟着学", systemImage: "book.closed") }
            NavigationStack { PracticeView() }
                .tabItem { Label("下一盘", systemImage: "square.grid.3x3") }
            NavigationStack { ReviewView() }
                .tabItem { Label("温故知新", systemImage: "arrow.counterclockwise") }
        }
        #if DEBUG
        .onAppear {
            if let raw = ProcessInfo.processInfo.environment["GO_KIT_PREVIEW_LESSON"],
               let id = Int(raw) {
                previewLesson = StudyCatalog.lessons.first { $0.id == id }
            }
        }
        .sheet(item: $previewLesson) { lesson in
            NavigationStack { StudyLessonView(lesson: lesson) }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.save() }
        }
        .alert("本机记录", isPresented: Binding(get: { store.storageNotice != nil }, set: { if !$0 { store.storageNotice = nil } })) {
            Button("知道了", role: .cancel) { store.storageNotice = nil }
        } message: { Text(store.storageNotice ?? "") }
    }
}
