import PPDesignSystem
import PPDomain
import SwiftUI

struct JourneyScreen: View {
    let level: CampaignLevel
    let progress: LevelProgress?
    let onOpen: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PPSpacing.large) {
                    VStack(alignment: .leading, spacing: PPSpacing.xSmall) {
                        Text(ppLocalized("journey.title"))
                            .font(.largeTitle.bold())
                            .fontDesign(.rounded)
                        Text(ppLocalized("journey.subtitle"))
                            .font(.title3)
                            .foregroundStyle(PPColor.ink.opacity(0.72))
                    }

                    TravelArtwork(symbol: "globe.europe.africa.fill")
                        .frame(height: 220)

                    PPPostcardCard {
                        VStack(alignment: .leading, spacing: PPSpacing.medium) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: PPSpacing.xxSmall) {
                                    Text(ppLocalized("country.\(level.countryID.rawValue).name"))
                                        .font(.title2.bold())
                                        .fontDesign(.rounded)
                                    Text(ppLocalized("country.\(level.countryID.rawValue).tagline"))
                                        .foregroundStyle(PPColor.ink.opacity(0.68))
                                }
                                Spacer()
                                PPStatusBadge(
                                    progress?.isCompleted == true ? "Completed" : "Ready",
                                    kind: progress?.isCompleted == true ? .completed : .active
                                )
                            }

                            Button(ppLocalized("journey.explore"), action: onOpen)
                                .buttonStyle(.ppPrimary)
                        }
                    }
                }
                .padding(PPSpacing.medium)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
    }
}

struct CountryScreen: View {
    let level: CampaignLevel
    let onOpen: () -> Void

    var body: some View {
        TravelDetailScreen(
            eyebrow: ppLocalized("journey.destination"),
            title: ppLocalized("country.\(level.countryID.rawValue).name"),
            subtitle: ppLocalized("country.\(level.countryID.rawValue).description"),
            symbol: "map.fill",
            cardTitle: ppLocalized("city.\(level.cityID.rawValue).name"),
            cardSubtitle: ppLocalized("city.\(level.cityID.rawValue).tagline"),
            actionTitle: ppLocalized("country.\(level.countryID.rawValue).action"),
            action: onOpen
        )
    }
}

struct CityScreen: View {
    let level: CampaignLevel
    let progress: LevelProgress?
    let onOpen: () -> Void

    var body: some View {
        TravelDetailScreen(
            eyebrow: ppLocalized("country.\(level.countryID.rawValue).name"),
            title: ppLocalized("city.\(level.cityID.rawValue).name"),
            subtitle: ppLocalized("city.\(level.cityID.rawValue).description"),
            symbol: "building.columns.fill",
            cardTitle: ppLocalized("location.\(level.locationID.rawValue).name"),
            cardSubtitle: progress?.isCompleted == true
                ? ppLocalized("level.completed")
                : ppLocalized("level.\(level.id.rawValue).summary"),
            actionTitle: ppLocalized("city.\(level.cityID.rawValue).action"),
            action: onOpen
        )
    }
}

struct VenueScreen: View {
    let level: CampaignLevel
    let onStart: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpacing.large) {
                    TravelArtwork(symbol: "theatermasks.fill")
                        .frame(height: 230)

                    VStack(alignment: .leading, spacing: PPSpacing.xSmall) {
                        Text(ppLocalized("city.\(level.cityID.rawValue).name"))
                            .font(.headline)
                            .foregroundStyle(PPColor.teal)
                        Text(ppLocalized("location.\(level.locationID.rawValue).name"))
                            .font(.largeTitle.bold())
                            .fontDesign(.rounded)
                        Text(ppLocalized("location.\(level.locationID.rawValue).description"))
                            .font(.body)
                            .foregroundStyle(PPColor.ink.opacity(0.72))
                    }

                    PPPostcardCard {
                        VStack(alignment: .leading, spacing: PPSpacing.small) {
                            Label(ppLocalized("puzzle.logicChallenge"), systemImage: "square.grid.2x2")
                                .font(.headline)
                            Text(ppLocalized("level.\(level.id.rawValue).objective"))
                                .foregroundStyle(PPColor.ink.opacity(0.72))
                            Button(
                                ppLocalized("location.\(level.locationID.rawValue).action"),
                                action: onStart
                            )
                                .buttonStyle(.ppPrimary)
                        }
                    }
                }
                .padding(PPSpacing.medium)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .navigationTitle(ppLocalized("location.\(level.locationID.rawValue).name"))
        .ppInlineNavigationTitle()
    }
}

private struct TravelDetailScreen: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let symbol: String
    let cardTitle: String
    let cardSubtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpacing.large) {
                    VStack(alignment: .leading, spacing: PPSpacing.xxSmall) {
                        Text(eyebrow.uppercased())
                            .font(.subheadline.bold())
                            .foregroundStyle(PPColor.teal)
                        Text(title)
                            .font(.largeTitle.bold())
                            .fontDesign(.rounded)
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(PPColor.ink.opacity(0.72))
                    }

                    TravelArtwork(symbol: symbol)
                        .frame(height: 240)

                    PPPostcardCard {
                        VStack(alignment: .leading, spacing: PPSpacing.small) {
                            Text(cardTitle)
                                .font(.title3.bold())
                            Text(cardSubtitle)
                                .foregroundStyle(PPColor.ink.opacity(0.68))
                            Button(actionTitle, action: action)
                                .buttonStyle(.ppPrimary)
                        }
                    }
                }
                .padding(PPSpacing.medium)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .navigationTitle(title)
        .ppInlineNavigationTitle()
    }
}

private struct TravelArtwork: View {
    let symbol: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [PPColor.travelBlue.opacity(0.88), PPColor.teal.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MosaicRoute()
                .stroke(PPColor.gold.opacity(0.68), style: StrokeStyle(lineWidth: 3, dash: [7, 8]))
                .padding(PPSpacing.large)

            Image(systemName: symbol)
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityHidden(true)
    }
}

private struct MosaicRoute: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.78))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            control1: CGPoint(x: rect.width * 0.28, y: rect.height * 0.15),
            control2: CGPoint(x: rect.width * 0.68, y: rect.height * 0.90)
        )
        return path
    }
}

extension View {
    @ViewBuilder
    func ppInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
