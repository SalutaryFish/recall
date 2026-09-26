import SwiftUI

enum Metrics {
    static let chipRadius: CGFloat = 8
    static let cardRadius: CGFloat = 14
    static let sheetRadius: CGFloat = 28
    static let gutter: CGFloat = 20
}

extension View {
    /// `.card`: raised white surface, hairline border, the faintest shadow.
    func cardSurface(radius: CGFloat = Metrics.cardRadius, fill: Color = Palette.card,
                     border: Color = Palette.hair) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .shadow(color: Palette.shadowCard, radius: 1, x: 0, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        }
    }
}

struct Chip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.mono(10))
            .foregroundStyle(Palette.ink2)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Palette.wash, in: RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous))
    }
}

struct ChipRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(tags.prefix(4)), id: \.self) { Chip(text: $0) }
        }
    }
}

/// `.seg`: a small two- or three-way switch.
struct SegmentedPill<Value: Hashable>: View {
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    if !on {
                        selection = option
                        Haptics.tick()
                    }
                } label: {
                    Text(label(option))
                        .font(.mono(10))
                        .tracking(0.6)
                        .foregroundStyle(on ? Palette.ink : Palette.ink2)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Palette.card)
                                    .shadow(color: Palette.shadowCard, radius: 1, x: 0, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// `.fields`: stacked key/value rows separated by hairlines.
struct FieldList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 1) {
            content
        }
        .background(Palette.hair)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(Palette.hair, lineWidth: 1)
        }
    }
}

struct FieldRow<Value: View>: View {
    let key: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.mono(10.5))
                .tracking(0.6)
                .foregroundStyle(Palette.ink3)
            Spacer(minLength: 0)
            value
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(Palette.card)
    }
}

/// A tappable time value with the prototype's dashed underline.
struct TimeValueButton: View {
    let text: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .sans(13.5)
                .foregroundStyle(active ? Palette.clayInk : Palette.ink)
                .padding(.bottom, 1)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.hair2)
                        .frame(height: 1)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Inline 24-hour wheel shown under a FROM/TO row.
struct WheelTimePicker: View {
    @Binding var selection: Date
    let range: ClosedRange<Date>

    var body: some View {
        DatePicker("", selection: $selection, in: range, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "en_GB"))
            .frame(maxWidth: .infinity)
            .background(Palette.card)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sans(15, .medium)
            .foregroundStyle(Palette.bone)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(SpringPreset.snappy.animation, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sans(15)
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Palette.hair2, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(SpringPreset.snappy.animation, value: configuration.isPressed)
    }
}

/// Scale-on-press for tiles and rows (`.freq:active`, `.gap-btn:active`).
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.955

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(SpringPreset.snappy.animation, value: configuration.isPressed)
    }
}

struct IconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Palette.ink2)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(IconButtonStyle())
        .accessibilityLabel(label)
    }
}

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle().fill(configuration.isPressed ? Palette.wash : Color.clear)
            }
    }
}

struct SheetTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.serif(24))
            .foregroundStyle(Palette.ink)
    }
}

struct SheetSub: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.mono(10.5))
            .tracking(0.6)
            .foregroundStyle(Palette.ink3)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.mono(10.5))
            .tracking(0.9)
            .foregroundStyle(Palette.ink3)
            .padding(.top, 22)
            .padding(.bottom, 10)
    }
}

/// Archive / Insights page header: mono kicker over a 32 pt serif title.
struct PageHeader: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker)
                .font(.mono(11.5))
                .tracking(0.9)
                .foregroundStyle(Palette.ink3)
            Text(title)
                .font(.serif(32))
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

/// `.qinput`: the mono text field used for capture and search.
struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding?
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}

    var body: some View {
        field
            .font(.mono(14))
            .foregroundStyle(Palette.ink)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Palette.hair2, lineWidth: 1)
            }
    }

    @ViewBuilder private var field: some View {
        let prompt = Text(placeholder).foregroundStyle(Palette.ink3)
        if let focus {
            TextField("", text: $text, prompt: prompt).focused(focus)
        } else {
            TextField("", text: $text, prompt: prompt)
        }
    }
}

/// Placeholder thumbnail: hatch + source glyph.
struct Thumb: View {
    let glyph: String
    var width: CGFloat = 76
    var height: CGFloat = 52
    var radius: CGFloat = 9
    var glyphSize: CGFloat = 17

    var body: some View {
        Hatch.placeholder(band: 7)
            .frame(width: width, height: height)
            .overlay {
                Text(glyph)
                    .font(.system(size: glyphSize))
                    .foregroundStyle(Palette.ink)
                    .opacity(0.55)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
