import Foundation

/// Must match `normalise()` in tools/generate.py exactly. Only tashkeel, tatweel and
/// spaces are removed: hamza forms and ى are kept, so words show their real spelling.
enum ArabicText {
    private static let map: [Character: Character] = ["ٱ": "ا"]

    static func normalise(_ s: String) -> String {
        var out = ""
        for scalar in s.unicodeScalars {
            let v = scalar.value
            if (0x064B...0x0652).contains(v) || v == 0x0670 || v == 0x0640 || scalar == " " { continue }
            let ch = Character(scalar)
            out.append(map[ch] ?? ch)
        }
        return out
    }

    /// Common letters used as decoys in the letter bank.
    static let decoys: [String] = "ابتجحدرسعفقكلمنهوية".map(String.init)
}

/// Small deterministic RNG so a word's letter bank is the same on every launch
/// (Swift's hashValue is randomised per process, so it can't be the seed).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: String) {
        var h: UInt64 = 0xcbf29ce484222325           // FNV-1a
        for b in seed.utf8 { h ^= UInt64(b); h &*= 0x100000001b3 }
        state = h == 0 ? 0x9E3779B97F4A7C15 : h
    }
    mutating func next() -> UInt64 {                  // xorshift64*
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return state &* 2685821657736338717
    }
}
