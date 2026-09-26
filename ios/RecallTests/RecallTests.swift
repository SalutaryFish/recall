import RecallCore
import UIKit
import XCTest
@testable import Recall

/// Hosted in the app, so the bundle's fonts and sandbox are real.
final class RecallTests: XCTestCase {
    @MainActor
    func testBundledFontsAreRegistered() {
        for name in Typeface.all {
            XCTAssertNotNil(UIFont(name: name, size: 12), "\(name) is not registered — check UIAppFonts")
        }
        XCTAssertTrue(Typeface.isAvailable)
    }

    @MainActor
    func testPersistenceRoundTrip() throws {
        let persistence = Persistence.temporary()
        let data = Seed.sampleSnapshot(now: Date(), calendar: .current)
        Persistence.write(data, to: persistence.fileURL)
        guard case .loaded(let loaded) = persistence.load() else {
            return XCTFail("the archive didn't load back")
        }
        XCTAssertEqual(loaded.entries, data.entries)
        XCTAssertEqual(loaded.frequents, data.frequents)
    }

    @MainActor
    func testUnreadableArchiveIsMovedAsideNotOverwritten() throws {
        let persistence = Persistence.temporary()
        try FileManager.default.createDirectory(at: persistence.directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: persistence.fileURL)
        guard case .unreadable(let aside) = persistence.load() else {
            return XCTFail("expected the corrupt file to be reported")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: aside.path(percentEncoded: false)))
    }

    @MainActor
    func testStoreStartsStopsAndClearsSamples() {
        let store = AppStore(data: Seed.sampleSnapshot(now: Date(), calendar: .current),
                             persistence: .temporary(), calendar: .current, isUITesting: true)
        store.startBlock("Coffee")
        XCTAssertEqual(store.liveEntry?.title, "Coffee")
        store.clearSamples()
        XCTAssertEqual(store.entries.map(\.title), ["Coffee"])
        XCTAssertFalse(store.data.hasSamples)
        store.stopLive()
        XCTAssertNil(store.liveEntry)
    }
}
