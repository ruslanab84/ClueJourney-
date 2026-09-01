import Foundation
import PPDomain
import Testing

@Suite("Puzzle domain values")
struct PuzzleDomainTests {
    @Test(
        "Star thresholds map moves to authored ratings",
        arguments: zip([4, 5, 8], [StarRating.three, .two, .one])
    )
    func starRating(moveCount: Int, expected: StarRating) {
        let thresholds = StarThresholds(
            threeStarMaximumMoves: 4,
            twoStarMaximumMoves: 7
        )

        #expect(thresholds.rating(for: moveCount) == expected)
    }

    @Test("Stable IDs encode as strings and preserve their concrete type")
    func stableIDRoundTrip() throws {
        let id = PuzzleID("rome.theatre.001")
        let encoded = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(PuzzleID.self, from: encoded)

        #expect(decoded == id)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"rome.theatre.001\"")
    }

    @Test("Empty stable IDs are rejected at the decoding boundary")
    func emptyStableIDIsRejected() {
        let encoded = Data("\"  \"".utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(EntityID.self, from: encoded)
        }
    }
}
