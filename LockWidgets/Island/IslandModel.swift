import AppKit
import Combine
import SwiftUI

/// Something the island can show, from a playing song to a passing notification.
enum IslandActivity: Equatable {
    case music
}

/// What the island is showing and how big it is. Shared by the window (for hit testing) and the view.
final class IslandModel: ObservableObject {
    static let shared = IslandModel()

    @Published private(set) var primary: IslandActivity?
    @Published var isExpanded = false
    @Published var isHovering = false

    /// The notch, or a stand-in on displays without one.
    @Published private(set) var notch = CGSize(width: 190, height: 32)
    @Published private(set) var hasNotch = false

    private var subscriptions: Set<AnyCancellable> = []

    private init() {
        updateNotch()
        let music = NowPlayingStore.shared
        music.$track.map { $0 != nil }.removeDuplicates().combineLatest(music.$isPlaying.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.refresh() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.updateNotch() }
            .store(in: &subscriptions)
    }

    private func setting(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    func refresh() {
        var next: IslandActivity?
        let music = NowPlayingStore.shared
        if setting(SettingsKey.islandMusic), music.track != nil {
            next = .music
        }
        if primary != next {
            primary = next
            if next == nil { isExpanded = false }
        }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "islandExpanded"), primary != nil { isExpanded = true }
        #endif
    }

    // MARK: Geometry

    static var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func updateNotch() {
        guard let screen = Self.screen else { return }
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea
        {
            hasNotch = true
            notch = CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        } else {
            hasNotch = false
            notch = CGSize(width: 190, height: NSStatusBar.system.thickness)
        }
    }

    /// Room either side of the notch in the compact island.
    static let compactSide: CGFloat = 44

    /// Size of the black shape for the current state.
    var size: CGSize {
        if isExpanded, primary != nil {
            return CGSize(width: max(notch.width + 260, 470), height: notch.height + 150)
        }
        if primary != nil {
            return CGSize(width: notch.width + Self.compactSide * 2 + (isHovering ? 8 : 0), height: notch.height + (isHovering ? 3 : 0))
        }
        return notch
    }

    func toggleExpanded() {
        guard primary != nil else { return }
        isExpanded.toggle()
    }
}
