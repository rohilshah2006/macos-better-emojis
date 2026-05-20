import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.autoresizingMask = [.width, .height]
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

class EmojiPickerState: ObservableObject {
    @Published var query: String = ""
    @Published var matches: [Emoji] = []
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false
    
    func updateQuery(_ newQuery: String) {
        query = newQuery
        matches = EmojiDatabase.shared.search(query: newQuery)
        
        // Clamp selection to valid range
        if matches.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= matches.count {
            selectedIndex = matches.count - 1
        } else if selectedIndex < 0 {
            selectedIndex = 0
        }
    }
    
    func moveSelectionDown() {
        guard !matches.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % matches.count
    }
    
    func moveSelectionUp() {
        guard !matches.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + matches.count) % matches.count
    }
    
    var selectedEmoji: Emoji? {
        guard !matches.isEmpty && selectedIndex >= 0 && selectedIndex < matches.count else { return nil }
        return matches[selectedIndex]
    }
}

struct CandidateView: View {
    @ObservedObject var state: EmojiPickerState
    let onSelect: (Emoji) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header showing search preview
            HStack(spacing: 8) {
                Text(":")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(Color.accentColor)
                
                Text(state.query.isEmpty ? "type to search..." : state.query)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(state.query.isEmpty ? Color(.secondaryLabelColor) : Color(.labelColor))
                
                Spacer()
                
                Text("\(state.matches.count) found")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.textColor).opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
                .background(Color(.separatorColor).opacity(0.5))
            
            // Emoji matches list
            if state.matches.isEmpty {
                VStack(spacing: 8) {
                    Text("🔍")
                        .font(.system(size: 24))
                    Text("No matching emojis found")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(Color(.secondaryLabelColor))
                }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 180)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 2) {
                            ForEach(Array(state.matches.prefix(10).enumerated()), id: \.offset) { index, emoji in
                                let isSelected = index == state.selectedIndex
                                
                                EmojiRow(emoji: emoji, isSelected: isSelected) {
                                    onSelect(emoji)
                                }
                                .id(index)
                            }
                        }
                        .padding(4)
                    }
                    .frame(maxHeight: 220)
                    .onChange(of: state.selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            
            Divider()
                .background(Color(.separatorColor).opacity(0.5))
            
            // Footer with keyboard tips
            HStack {
                Text("↑↓ Navigate")
                Spacer()
                Text("↵ Select")
                Spacer()
                Text("⎋ Close")
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundColor(Color(.secondaryLabelColor).opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.textColor).opacity(0.03))
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

struct EmojiRow: View {
    let emoji: Emoji
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Large visual Emoji
                Text(emoji.emoji)
                    .font(.system(size: 28))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    // Alias (e.g. :smile:)
                    Text(":\(emoji.aliases.first ?? ""):")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : Color(.labelColor))
                    
                    // Description or secondary keywords
                    Text(emoji.description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : Color(.secondaryLabelColor))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Discord-like category label or indicator on selection
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color(.textColor).opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hover in
            isHovered = hover
        }
    }
}
