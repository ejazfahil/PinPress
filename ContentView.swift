//
//  ContentView.swift
//  PinPress
//
//  Pinterest-like feed: remote images + caching + swipe tiles + infinite scroll + tabs
//  HIG-minded: accessibility, predictable image sizes, refreshable feed
//

import SwiftUI
import UIKit
import Combine

// MARK: - Image Cache (cost-aware)
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 150 * 1024 * 1024 // ~150 MB budget
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        // cost ~ bytes in memory (heuristic)
        let cost = image.pngData()?.count ?? 1
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - Cached Async Image View
struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode

    @State private var uiImage: UIImage?
    @State private var isLoading = false
    @Environment(\.displayScale) private var displayScale

    init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if isLoading {
                ProgressView().controlSize(.large)
            } else {
                placeholder
            }
        }
        .task(id: url) { await load() }
        .animation(.easeInOut(duration: 0.2), value: uiImage)
        .accessibilityHidden(uiImage == nil) // placeholder is decorative
    }

    @MainActor
    private func load() async {
        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) {
            self.uiImage = cached
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url, delegate: nil)
            if let image = UIImage(data: data) {
                ImageCache.shared.insert(image, for: url)
                self.uiImage = image
            }
        } catch {
            // Keep placeholder; you might log errors in a real app.
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.12))
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Image unavailable")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Model
struct Pin: Identifiable, Hashable {
    let id: UUID
    let title: String
    let imageURLs: [URL] // swipe through images
    let category: String

    init(id: UUID = UUID(), title: String, imageURLs: [URL], category: String) {
        self.id = id
        self.title = title
        self.imageURLs = imageURLs
        self.category = category
    }
}

// MARK: - Demo Image Service (seed-based, predictable sizes)
enum DemoImageService {
    static func makeSeedPicsumURLs(count: Int, width: Int = 600, height: Int = 800) -> [URL] {
        (0..<count).compactMap { _ in
            let seed = UUID().uuidString
            return URL(string: "https://picsum.photos/seed/\(seed)/\(width)/\(height)")
        }
    }

    static func makeBasePins() -> [Pin] {
        // 6 pins * 5 images each = 30 images
        let pool = makeSeedPicsumURLs(count: 30, width: 600, height: 800)
        guard pool.count >= 30 else { return [] }

        let pin1 = Array(pool[0..<5])
        let pin2 = Array(pool[5..<10])
        let pin3 = Array(pool[10..<15])
        let pin4 = Array(pool[15..<20])
        let pin5 = Array(pool[20..<25])
        let pin6 = Array(pool[25..<30])

        return [
            Pin(title: "Mountain Escape", imageURLs: pin1, category: "Nature"),
            Pin(title: "Workspace Inspiration", imageURLs: pin2, category: "Tech"),
            Pin(title: "Cozy Living Vibes", imageURLs: pin3, category: "Interior"),
            Pin(title: "Delicious Flatlays", imageURLs: pin4, category: "Food"),
            Pin(title: "Ocean Sunset Series", imageURLs: pin5, category: "Photography"),
            Pin(title: "Minimal Bedroom + Architecture", imageURLs: pin6, category: "Design")
        ]
    }

    static func repeated(_ pins: [Pin], times: Int) -> [Pin] {
        var out: [Pin] = []
        for _ in 0..<times {
            out.append(contentsOf: pins.map { Pin(title: $0.title, imageURLs: $0.imageURLs, category: $0.category) })
        }
        return out
    }
}

// MARK: - Feed ViewModel
@MainActor
final class HomeFeedViewModel: ObservableObject {
    @Published private(set) var pins: [Pin] = []
    @Published var isLoadingMore = false
    private var page = 1

    // Tuning knobs
    private let loadMoreThreshold = 6
    private let pageSizeMultiplier = 2

    init() {
        reset()
    }

    func reset() {
        let base = DemoImageService.makeBasePins()
        self.pins = DemoImageService.repeated(base, times: 2)
        self.page = 1
    }

    func maybeLoadMore(whenShowing pin: Pin) {
        guard !isLoadingMore,
              let idx = pins.firstIndex(of: pin),
              idx >= pins.count - loadMoreThreshold
        else { return }

        isLoadingMore = true
        let next = page + 1

        Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s demo latency
            let base = DemoImageService.makeBasePins()
            let newPins = DemoImageService.repeated(base, times: pageSizeMultiplier)
            self.pins.append(contentsOf: newPins)
            self.page = next
            self.isLoadingMore = false
        }
    }

    func refresh() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        reset()
    }
}

// MARK: - Tile
struct PinTileView: View {
    let pin: Pin
    @State private var selectedIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                TabView(selection: $selectedIndex) {
                    ForEach(Array(pin.imageURLs.enumerated()), id: \.offset) { idx, url in
                        ZStack(alignment: .topTrailing) {
                            CachedAsyncImage(url: url, contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .contentShape(Rectangle())

                            Text(pin.category)
                                .font(.caption).bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(8)
                                .accessibilityLabel("Category: \(pin.category)")
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: geo.size.height)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(pin.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .accessibilityLabel("Pin: \(pin.title)")
        }
        .padding(6)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Home Feed
struct HomeFeedView: View {
    @StateObject private var vm = HomeFeedViewModel()
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(vm.pins) { pin in
                    PinTileView(pin: pin)
                        .onAppear { vm.maybeLoadMore(whenShowing: pin) }
                }

                if vm.isLoadingMore {
                    ProgressView().padding().gridCellColumns(2)
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("PinPress")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await vm.refresh() }
        .accessibilitySortPriority(1)
    }
}

// MARK: - Search
struct SearchView: View {
    @State private var query = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("Search for ideas, designs, or moods", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel("Search field")

            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Search results will appear here.")
                .foregroundStyle(.secondary)
            Spacer(minLength: 40)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Create (Mock AI Mood Board)
struct AIMoodBoardView: View {
    @State private var prompt: String = ""
    @State private var selectedMood: String = "Cozy"
    @State private var selectedColor: String = "Terracotta"
    @State private var selectedStyle: String = "Bohemian"
    @State private var generatedURL: URL?
    @State private var isGenerating = false

    let moods = ["Cozy", "Energetic", "Calm", "Minimalist"]
    let colors = ["Terracotta", "Navy Blue", "Pastel Pink", "Forest Green"]
    let styles = ["Bohemian", "Industrial", "Mid-Century", "Cyberpunk"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🧠 AI Mood Board Generator")
                    .font(.title2).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    PickerRow(title: "Mood", selection: $selectedMood, options: moods)
                    PickerRow(title: "Color", selection: $selectedColor, options: colors)
                    PickerRow(title: "Style", selection: $selectedStyle, options: styles)

                    TextField("Describe your idea…", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Idea description")
                }
                .padding(.horizontal)

                Button(action: generateMoodBoard) {
                    HStack(spacing: 8) {
                        if isGenerating { ProgressView() }
                        Text(isGenerating ? "Generating…" : "Generate Mood Board")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(isGenerating)
                .padding(.horizontal)

                Group {
                    if let url = generatedURL {
                        CachedAsyncImage(url: url, contentMode: .fit)
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal)
                            .accessibilityLabel("Generated mood board image")
                    } else if !isGenerating {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 260)
                            .overlay(
                                Text("Your generated image will appear here")
                                    .foregroundStyle(.secondary)
                            )
                            .padding(.horizontal)
                            .accessibilityHidden(true)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generateMoodBoard() {
        isGenerating = true
        let _ = "\(selectedMood) \(selectedStyle) with \(selectedColor). \(prompt)"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let pool = DemoImageService.makeSeedPicsumURLs(count: 10, width: 600, height: 800)
            generatedURL = pool.randomElement()
            isGenerating = false
        }
    }
}

// MARK: - PickerRow
struct PickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack {
            Text(title).font(.body)
            Spacer(minLength: 16)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) picker")
    }
}

// MARK: - Profile
struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(.teal)
                    .accessibilityHidden(true)

                Text("Your Profile")
                    .font(.title2).bold()
                Text("Saved pins, boards, and settings.")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Root Tabs
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeFeedView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack { AIMoodBoardView() }
                .tabItem { Label("Create", systemImage: "sparkles") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .accessibilityLabel("Main tabs")
    }
}

// MARK: - App Entry
struct ContentView: View {
    var body: some View { RootTabView() }
}

#Preview { ContentView() }
