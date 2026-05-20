import Foundation

struct EmojiMatch: Identifiable, Hashable {
    var id: String { emoji.emoji }
    let emoji: Emoji
    let score: Int
}

class EmojiDatabase {
    static let shared = EmojiDatabase()
    
    let emojis: [Emoji]
    
    // Pre-built index: maps lowercased prefix substrings to emoji indices for O(1) lookup
    private var prefixIndex: [String: [(index: Int, score: Int)]] = [:]
    
    private init() {
        self.emojis = allEmojis
        buildIndex()
    }
    
    /// Builds a prefix index at startup so searches are instant hash lookups.
    private func buildIndex() {
        for (i, emoji) in emojis.enumerated() {
            // Index all alias prefixes (highest priority)
            for alias in emoji.aliases {
                let lower = alias.lowercased()
                // Add all prefixes of this alias
                for len in 1...lower.count {
                    let prefix = String(lower.prefix(len))
                    let score = (len == lower.count) ? 100 : (80 - (lower.count - len)) // Exact=100, prefix=80-penalty
                    let clampedScore = max(score, 50)
                    if prefixIndex[prefix] == nil {
                        prefixIndex[prefix] = []
                    }
                    prefixIndex[prefix]!.append((index: i, score: clampedScore))
                }
                // Also index substrings for "contains" matching
                if lower.count > 1 {
                    for start in 1..<lower.count {
                        let remaining = lower.count - start
                        for len in 1...remaining {
                            let sub = String(lower[lower.index(lower.startIndex, offsetBy: start)..<lower.index(lower.startIndex, offsetBy: start + len)])
                            if prefixIndex[sub] == nil {
                                prefixIndex[sub] = []
                            }
                            prefixIndex[sub]!.append((index: i, score: 30))
                        }
                    }
                }
            }
            
            // Index tag prefixes (medium priority)
            for tag in emoji.tags {
                let lower = tag.lowercased()
                for len in 1...lower.count {
                    let prefix = String(lower.prefix(len))
                    let score = (len == lower.count) ? 60 : 45
                    if prefixIndex[prefix] == nil {
                        prefixIndex[prefix] = []
                    }
                    prefixIndex[prefix]!.append((index: i, score: score))
                }
            }
        }
        
        // Deduplicate: keep only the highest score per emoji per prefix
        for (key, entries) in prefixIndex {
            var best: [Int: Int] = [:] // index -> best score
            for entry in entries {
                if let existing = best[entry.index] {
                    best[entry.index] = max(existing, entry.score)
                } else {
                    best[entry.index] = entry.score
                }
            }
            prefixIndex[key] = best.map { (index: $0.key, score: $0.value) }
        }
    }
    
    /// Ultra-fast emoji search using pre-built index. Returns top 10 results.
    func search(query: String) -> [Emoji] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmed.isEmpty {
            // Return top 10 default popular smileys when query is empty
            return Array(emojis.prefix(10))
        }
        
        // O(1) hash lookup instead of O(n) linear scan
        guard let hits = prefixIndex[trimmed] else {
            return []
        }
        
        // Sort by score descending, then by alias length (prefer shorter names)
        let sorted = hits.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            let aLen = emojis[a.index].aliases.first?.count ?? 999
            let bLen = emojis[b.index].aliases.first?.count ?? 999
            return aLen < bLen
        }
        
        // Return top 10 only — matches Discord's behavior and keeps SwiftUI fast
        return sorted.prefix(10).map { emojis[$0.index] }
    }
}
