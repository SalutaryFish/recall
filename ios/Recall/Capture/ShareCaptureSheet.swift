@preconcurrency import LinkPresentation
import RecallCore
import SwiftUI
import UIKit

/// Save to Recall (§6.6 tier 1): paste a link, resolve its title, file it under today.
/// The system PasteButton reads the clipboard without a permission prompt.
struct ShareCaptureSheet: View {
    @Environment(AppStore.self) private var store
    @State private var media: SharedMedia?
    @State private var resolving = false
    @State private var attention: Attention = .active

    var body: some View {
        let store = self.store
        FittedSheet(expanded: .constant(false)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    SheetTitle("Save to Recall")
                    Spacer(minLength: 0)
                    resolveTag
                }
                if let media {
                    resolved(media)
                } else {
                    SheetSub("COPY A LINK IN ANY APP, THEN PASTE IT HERE")
                        .padding(.top, 6)
                    PasteButton(payloadType: URL.self) { urls in
                        guard let url = urls.first else { return }
                        Task { @MainActor in store.pastedURL = url }
                    }
                    .buttonBorderShape(.roundedRectangle(radius: Metrics.cardRadius))
                    .labelStyle(.titleAndIcon)
                    .tint(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    Button("Try a sample") { trySample() }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }
        }
        .onChange(of: store.pastedURL) { _, url in
            guard let url else { return }
            store.pastedURL = nil
            resolve(url)
        }
    }

    @ViewBuilder private var resolveTag: some View {
        if resolving || media != nil {
            Text(resolving ? "RESOLVING…" : "RESOLVED ✓")
                .font(.mono(9.5))
                .tracking(0.7)
                .foregroundStyle(resolving ? Palette.ink3 : Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(resolving ? Palette.wash : Palette.clay, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .animation(.easeOut(duration: 0.2), value: resolving)
        }
    }

    private func resolved(_ media: SharedMedia) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetSub(media.url)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.top, 6)
            Hatch.placeholder(band: 9)
                .frame(height: 150)
                .overlay {
                    Text(media.source.glyph)
                        .font(.system(size: 34))
                        .foregroundStyle(Palette.ink)
                        .opacity(0.6)
                }
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                .padding(.top, 12)
            Text(media.title)
                .sans(15.5, .medium)
                .foregroundStyle(Palette.ink)
                .padding(.top, 12)
            MetaLine([media.source.label, media.creator, media.durationMs.map { Fmt.duration(minutes: Double($0) / 60_000) }]
                .compactMap { $0 }.joined(separator: " · "))
                .padding(.top, 4)
            FieldList {
                FieldRow(key: "CAPTURED") {
                    Text("Today \(store.hhmm(Date()))").sans(13.5).foregroundStyle(Palette.ink)
                }
                FieldRow(key: "TYPE") {
                    Text(media.type).sans(13.5).foregroundStyle(Palette.ink)
                }
                if let extra = media.extra {
                    FieldRow(key: "ALSO SAVED") {
                        Text(extra).sans(13.5).foregroundStyle(Palette.ink)
                    }
                }
                FieldRow(key: "ATTENTION") {
                    SegmentedPill(options: Attention.allCases, label: { $0.rawValue.uppercased() },
                                  selection: $attention)
                }
            }
            .padding(.top, 12)
            HStack(spacing: 10) {
                Button("Add to today") {
                    store.dismissSheet()
                    store.addShared(media, attention: attention)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(resolving)
                Button("Cancel") { store.dismissSheet() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, 16)
        }
    }

    private func trySample() {
        guard let sample = SharePool.samples.randomElement() else { return }
        media = sample
        resolving = true
        Task {
            try? await Task.sleep(for: .milliseconds(620))
            resolving = false
            Haptics.tap()
        }
    }

    private func resolve(_ url: URL) {
        let source = SourceDetector.source(for: url)
        let host = SourceDetector.host(of: url)
        media = SharedMedia(url: url.absoluteString, title: host, source: source, creator: host,
                            type: SourceDetector.typeLabel(for: source))
        resolving = true
        Task {
            let title = await LinkTitle.fetch(url)
            if let title, var current = media {
                current.title = title
                media = current
            }
            resolving = false
            Haptics.tap()
        }
    }
}

/// Page title via LinkPresentation (OpenGraph / <title>), with a short timeout.
enum LinkTitle {
    static func fetch(_ url: URL) async -> String? {
        let provider = LPMetadataProvider()
        provider.timeout = 8
        let metadata = try? await provider.startFetchingMetadata(for: url)
        let title = metadata?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (title?.isEmpty ?? true) ? nil : title
    }
}
