import RecallCore
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    /// 1 = live screen hidden, 0 = fully open. Shared by the live bar and the live screen.
    @State private var live: SpringValue = SpringValue(1, preset: .standard, precision: 0.001)
    @State private var arc: ArcModel = ArcModel()
    @State private var insets: EdgeInsets = EdgeInsets()

    var body: some View {
        @Bindable var store = store
        ZStack {
            Palette.bone.ignoresSafeArea()
            screen
            ChromeLayer(live: live, arc: arc, insets: insets)
        }
        .onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { newValue in
            insets = newValue
        }
        .sheet(item: $store.sheet) { route in
            SheetHost(route: route)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.flush() }
        }
        .onChange(of: store.liveEntry?.id) { _, id in
            if id == nil, live.restingTarget < 1 { live.animate(to: 1) }
        }
        .task { await store.runAutoCaptureLoop() }
        .task { await store.showFirstLaunchHint() }
        .onAppear {
            store.applyTheme()
            Haptics.prepare()
        }
    }

    @ViewBuilder private var screen: some View {
        switch store.tab {
        case .today: TodayScreen()
        case .archive: ArchiveScreen()
        case .insights: InsightsScreen()
        }
    }
}

/// Where the chrome sits, in full-screen coordinates (the prototype's geometry:
/// a 58 pt bar above the home indicator, ⊕ centred 4 pt below the bar's top edge,
/// the live bar floating 6 pt above the bar).
struct ChromeLayout {
    let size: CGSize
    let insets: EdgeInsets

    var tabBarHeight: CGFloat { 58 + insets.bottom }
    var fabCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height - insets.bottom - 54) }
    var liveBarCenterY: CGFloat { size.height - tabBarHeight - 6 - 27 }
}

/// Everything that floats over the screens. Ignores the keyboard so the tab bar
/// and ⊕ stay put while typing in Archive search.
struct ChromeLayer: View {
    @Environment(AppStore.self) private var store
    let live: SpringValue
    let arc: ArcModel
    let insets: EdgeInsets

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = ChromeLayout(size: size, insets: insets)
            ZStack(alignment: .topLeading) {
                if store.liveEntry != nil {
                    LiveBar(live: live, screenHeight: size.height)
                        .padding(.horizontal, 10)
                        .frame(width: size.width)
                        .position(x: size.width / 2, y: layout.liveBarCenterY)
                        .transition(.opacity.combined(with: .offset(y: 20)))
                }
                TabBar(bottomInset: insets.bottom)
                    .frame(width: size.width, height: layout.tabBarHeight)
                    .position(x: size.width / 2, y: size.height - layout.tabBarHeight / 2)
                if arc.isOpen {
                    ArcOverlay(arc: arc, size: size)
                }
                CaptureButton(arc: arc, center: layout.fabCenter)
                    .position(layout.fabCenter)
                if store.liveEntry != nil {
                    LiveScreenLayer(live: live, size: size, insets: insets)
                }
                StatusBarVisibility(live: live)
                ToastLayer(bottom: 150)
                    .frame(width: size.width, height: size.height)
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(.named("chrome"))
            .animation(SpringPreset.standard.animation, value: store.liveEntry != nil)
        }
        .ignoresSafeArea()
        .ignoresSafeArea(.keyboard)
    }
}
