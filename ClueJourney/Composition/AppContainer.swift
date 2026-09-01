import Foundation
import PPApplication
import PPData

struct AppContainer {
    let journey: PuzzleJourney

    static func live(bundle: Bundle = .main) throws -> AppContainer {
        let contentURL = try bundledContentURL(in: bundle)
        let content = CampaignContentRepository(rootURL: contentURL)
        let progress = try SwiftDataProgressRepository()
        return AppContainer(
            journey: PuzzleJourney(
                contentRepository: content,
                progressRepository: progress
            )
        )
    }

    private static func bundledContentURL(in bundle: Bundle) throws -> URL {
        if let url = bundle.url(forResource: "Content", withExtension: nil) {
            return url
        }
        if let url = bundle.resourceURL,
           FileManager.default.fileExists(atPath: url.appending(path: "Countries").path)
        {
            return url
        }
        throw AppBootstrapError.missingContent
    }
}

private enum AppBootstrapError: Error {
    case missingContent
}
