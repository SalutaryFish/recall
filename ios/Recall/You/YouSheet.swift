import RecallCore
import SwiftUI

/// You: counts, theme, simulated auto-capture, export, and the sample data switch.
struct YouSheet: View {
    @Environment(AppStore.self) private var store
    @State private var exportURL: URL?
    @State private var confirmClear = false

    var body: some View {
        let data = store.data
        FittedSheet(expanded: .constant(false)) {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle("You")
                SheetSub("DATA LIVES ON THIS IPHONE ONLY")
                    .padding(.top, 2)
                FieldList {
                    FieldRow(key: "ENTRIES") {
                        Text("\(data.entries.count)").sans(13.5).foregroundStyle(Palette.ink)
                    }
                    FieldRow(key: "DAYS") {
                        Text("\(Set(data.entries.map { Day($0.start, calendar: store.calendar) }).count)")
                            .sans(13.5)
                            .foregroundStyle(Palette.ink)
                    }
                    FieldRow(key: "THEME") {
                        SegmentedPill(options: ThemePreference.allCases, label: { $0.rawValue.uppercased() },
                                      selection: Binding(get: { store.data.theme }, set: { store.setTheme($0) }))
                    }
                    FieldRow(key: "AUTO-CAPTURE") {
                        SegmentedPill(options: [true, false], label: { $0 ? "ON" : "OFF" },
                                      selection: Binding(get: { store.data.simulateAutoCapture },
                                                         set: { store.setSimulation($0) }))
                    }
                    FieldRow(key: "SAMPLE DATA") {
                        Button {
                            if data.hasSamples {
                                confirmClear = true
                            } else {
                                store.loadSamples()
                            }
                        } label: {
                            Text(data.hasSamples ? "CLEAR" : "LOAD")
                                .font(.mono(10))
                                .tracking(0.6)
                                .foregroundStyle(data.hasSamples ? Palette.clayInk : Palette.ink2)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 30)
                                .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("samples.toggle")
                    }
                }
                .padding(.top, 14)
                SheetSub(data.hasSamples
                         ? "THE DAYS YOU SEE ARE SAMPLES. CLEAR THEM TO START FOR REAL — ANYTHING YOU LOGGED STAYS."
                         : "AUTO-CAPTURE HERE IS SIMULATED: IT INVENTS DETECTIONS TO TRY THE CONFIRM FLOW.")
                    .lineSpacing(5)
                    .padding(.top, 10)
                HStack(spacing: 10) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Text("Export JSON")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Export JSON") {}
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(true)
                    }
                    Button("Done") { store.dismissSheet() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 16)
                SheetSub(
                    "GESTURES — PINCH THE TIMELINE FOR DENSITY · SWIPE A ROW LEFT FOR ACTIONS · SWIPE RIGHT TO REPEAT · HOLD A ROW TO RE-TIME · HOLD ⊕ FOR FREQUENTS · DRAG THE LIVE BAR UP · SWIPE THE HEADER FOR ANOTHER DAY · PULL DOWN AT THE TOP · SCRUB THE RIBBON"
                )
                    .lineSpacing(7)
                    .padding(.top, 16)
                SheetSub(
                    "RECALL \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"
                )
                    .padding(.top, 12)
            }
        }
        .task {
            exportURL = store.exportFile()
        }
        .confirmationDialog("Clear the sample days?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear sample data", role: .destructive) { store.clearSamples() }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("Everything you logged yourself stays. Simulated auto-capture turns off.")
        }
    }
}
