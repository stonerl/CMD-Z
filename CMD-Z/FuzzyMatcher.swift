//
//  FuzzyMatcher.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import Foundation

/// Scores menu entries against a query using subsequence fuzzy matching,
/// with a Jaro-Winkler fallback for typo-tolerant word matches.
enum FuzzyMatcher {
    private static let jaroThreshold = 0.85
    private static let levelDecay = 0.5

    /// Returns a match score, or `nil` when the query does not match at all.
    /// `ancestors` contains the menu levels above the title, nearest-first;
    /// matches deeper up the hierarchy decay by `levelDecay` per level.
    static func score(query: String, title: String, ancestors: [String]) -> Double? {
        let tokens = normalize(query).split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return 0 }

        let levels = ([title] + ancestors).map(normalize)
        var total = 0.0
        for token in tokens {
            var tokenScore: Double?
            for (depth, level) in levels.enumerated() {
                let subsequence = subsequenceScore(query: token, text: level)
                if subsequence > 0 {
                    tokenScore = subsequence * pow(levelDecay, Double(depth))
                    break
                }
            }
            if tokenScore == nil {
                for (depth, level) in levels.enumerated() {
                    let best = words(in: level).map { jaroWinkler(token, $0) }.max() ?? 0
                    if best >= jaroThreshold {
                        tokenScore = best * 0.6 * pow(levelDecay, Double(depth))
                        break
                    }
                }
            }
            guard let tokenScore else {
                return nil
            }
            total += tokenScore
        }
        return total
    }

    // MARK: - Normalization

    private static func normalize(_ string: String) -> String {
        string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }

    private static func words(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: - Subsequence

    private static func subsequenceScore(query: String, text: String) -> Double {
        let queryChars = Array(query)
        let textChars = Array(text)
        var queryIndex = 0
        var previous = -1
        var run = 0
        var score = 0.0

        for textIndex in 0 ..< textChars.count {
            if queryIndex >= queryChars.count {
                break
            }
            guard textChars[textIndex] == queryChars[queryIndex] else { continue }

            var bonus = 0.0
            if textIndex == 0 {
                bonus += 1.0
            }
            if previous != -1, textIndex == previous + 1 {
                run += 1
                bonus += 1.0 + Double(run) * 0.1
            } else {
                run = 0
            }
            if textIndex > 0, !isWordCharacter(textChars[textIndex - 1]) {
                bonus += 0.8
            }

            score += 1.0 + bonus
            previous = textIndex
            queryIndex += 1
        }

        return queryIndex == queryChars.count ? score : 0
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    // MARK: - Jaro-Winkler

    private static func jaroWinkler(_ first: String, _ second: String) -> Double {
        let lhs = Array(first)
        let rhs = Array(second)
        if lhs.isEmpty || rhs.isEmpty {
            return 0
        }
        if lhs == rhs {
            return 1.0
        }

        let matchWindow = max(lhs.count, rhs.count) / 2 - 1
        var matchedLHS = Array(repeating: false, count: lhs.count)
        var matchedRHS = Array(repeating: false, count: rhs.count)
        var matchCount = 0

        for lhsIndex in 0 ..< lhs.count {
            let start = max(0, lhsIndex - matchWindow)
            let end = min(rhs.count - 1, lhsIndex + matchWindow)
            guard start <= end else { continue }
            for rhsIndex in start ... end where !matchedRHS[rhsIndex] && lhs[lhsIndex] == rhs[rhsIndex] {
                matchedLHS[lhsIndex] = true
                matchedRHS[rhsIndex] = true
                matchCount += 1
                break
            }
        }

        if matchCount == 0 {
            return 0
        }

        var transpositions = 0
        var rhsIndex = 0
        for lhsIndex in 0 ..< lhs.count where matchedLHS[lhsIndex] {
            while !matchedRHS[rhsIndex] {
                rhsIndex += 1
            }
            if lhs[lhsIndex] != rhs[rhsIndex] {
                transpositions += 1
            }
            rhsIndex += 1
        }
        transpositions /= 2

        let matches = Double(matchCount)
        let jaro = (
            matches / Double(lhs.count)
                + matches / Double(rhs.count)
                + (matches - Double(transpositions)) / matches
        ) / 3.0

        let prefix = commonPrefixLength(lhs, rhs)
        return jaro + Double(prefix) * 0.1 * (1.0 - jaro)
    }

    private static func commonPrefixLength(_ lhs: [Character], _ rhs: [Character]) -> Int {
        var prefix = 0
        let maxPrefix = min(4, min(lhs.count, rhs.count))
        while prefix < maxPrefix, lhs[prefix] == rhs[prefix] {
            prefix += 1
        }
        return prefix
    }
}
