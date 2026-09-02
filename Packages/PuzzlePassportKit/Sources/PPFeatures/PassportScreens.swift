import PPDesignSystem
import PPDomain
import SwiftUI

struct PassportLaunchScreen: View {
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(spacing: PPSpacing.medium) {
                    Image("PPWordmark", bundle: .main)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 310)
                        .accessibilityLabel(Text(ppLocalized("app.name")))

                    Text(ppLocalized("launch.tagline"))
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, PPSpacing.medium)
                        .padding(.vertical, PPSpacing.xSmall)
                        .background(PPColor.teal, in: .rect(cornerRadius: PPRadius.small))
                        .rotationEffect(.degrees(-3))

                    Image("PPWelcomeHero", bundle: .main)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 430)
                        .frame(height: 330)
                        .clipped()
                        .mask { RoundedRectangle(cornerRadius: PPRadius.card) }
                        .accessibilityHidden(true)

                    PPPostcardCard {
                        VStack(spacing: PPSpacing.medium) {
                            Text(ppLocalized("launch.description"))
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            Button(action: onPlay) {
                                Label(ppLocalized("launch.play"), systemImage: "puzzlepiece.fill")
                            }
                            .buttonStyle(.ppPrimary)

                            Button(ppLocalized("launch.restore"), action: onPlay)
                                .font(.footnote.bold())
                                .foregroundStyle(PPColor.travelBlue)
                        }
                    }
                }
                .padding(PPSpacing.medium)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .ppHiddenNavigationBar()
    }
}

struct PassportDestinationScreen: View {
    let level: CampaignLevel
    let completedLevels: Int
    let totalLevels: Int
    let stars: Int
    let discoveredFacts: Int
    let onOpen: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(spacing: PPSpacing.medium) {
                    HStack(spacing: PPSpacing.small) {
                        Image("PPWelcomeHero", bundle: .main)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(.circle)
                            .overlay { Circle().stroke(PPColor.border, lineWidth: 2) }
                            .accessibilityHidden(true)
                        Spacer()
                        PPMetricPill(
                            symbol: "star.fill",
                            value: stars
                        )
                        PPMetricPill(
                            symbol: "book.closed.fill",
                            value: discoveredFacts,
                            tint: PPColor.travelBlue
                        )
                    }

                    Text(ppLocalized("destinations.title"))
                        .font(.title2.weight(.black))
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button(action: onOpen) {
                        PassportDestinationRow(
                            imageName: "PPRomeHero",
                            cityName: ppLocalized("city.\(level.cityID.rawValue).name"),
                            countryName: ppLocalized("country.\(level.countryID.rawValue).name"),
                            progressText: "\(completedLevels)/\(totalLevels)",
                            isLocked: false
                        )
                    }
                    .buttonStyle(.plain)

                    PassportDestinationRow(
                        imageName: "PPParisHero",
                        cityName: ppLocalized("city.paris.name"),
                        countryName: ppLocalized("country.fr.name"),
                        progressText: "0/25",
                        isLocked: true
                    )

                    PassportDestinationRow(
                        imageName: "PPLondonHero",
                        cityName: ppLocalized("city.london.name"),
                        countryName: ppLocalized("country.gb.name"),
                        progressText: "0/25",
                        isLocked: true
                    )

                    HStack(spacing: PPSpacing.xxSmall) {
                        Image(systemName: "sparkles")
                        Text(ppLocalized("destinations.moreSoon"))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PPColor.ink.opacity(0.62))
                    .padding(.top, PPSpacing.small)

                    Spacer(minLength: 48)

                    HStack {
                        Label(ppLocalized("nav.destinations"), systemImage: "safari.fill")
                            .foregroundStyle(PPColor.travelBlue)
                        Spacer()
                        Label(ppLocalized("nav.passport"), systemImage: "book.closed.fill")
                            .foregroundStyle(PPColor.ink.opacity(0.45))
                    }
                    .font(.caption.bold())
                    .padding(PPSpacing.small)
                    .background(PPColor.surface.opacity(0.8), in: .rect(cornerRadius: PPRadius.card))
                }
                .padding(PPSpacing.medium)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .ppHiddenNavigationBar()
    }
}

private struct PassportDestinationRow: View {
    let imageName: String
    let cityName: String
    let countryName: String
    let progressText: String
    let isLocked: Bool

    var body: some View {
        HStack(spacing: PPSpacing.small) {
            Image(imageName, bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: 128, height: 94)
                .clipShape(.rect(cornerRadius: PPRadius.small))

            VStack(alignment: .leading, spacing: PPSpacing.xxSmall) {
                Text(cityName.uppercased())
                    .font(.headline.weight(.black))
                Text(countryName)
                    .font(.caption)
                    .foregroundStyle(PPColor.ink.opacity(0.72))
                Spacer(minLength: 4)
                HStack(spacing: PPSpacing.xSmall) {
                    Text(progressText)
                        .font(.caption.bold().monospacedDigit())
                    if !isLocked {
                        Image(systemName: "star.fill")
                            .foregroundStyle(PPColor.gold)
                    }
                }
                .padding(.horizontal, PPSpacing.xSmall)
                .padding(.vertical, PPSpacing.xxSmall)
                .background(isLocked ? PPColor.paper : PPColor.ink, in: .capsule)
                .foregroundStyle(isLocked ? PPColor.ink : .white)
            }

            Spacer()
            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.headline.bold())
                .foregroundStyle(isLocked ? PPColor.ink.opacity(0.48) : PPColor.travelBlue)
        }
        .padding(PPSpacing.xSmall)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(PPColor.surface, in: .rect(cornerRadius: PPRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PPRadius.card)
                .stroke(PPColor.border.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: PPColor.ink.opacity(0.07), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(cityName), \(countryName)"))
        .accessibilityValue(Text(isLocked ? ppLocalized("destinations.locked") : progressText))
    }
}

struct RomeOverviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let levels: [CampaignLevel]
    let progress: [LevelID: LevelProgress]
    let onOpen: (CampaignLevel) -> Void

    private var orderedLevels: [CampaignLevel] {
        levels.sorted {
            if $0.boardStyle.displayOrder == $1.boardStyle.displayOrder {
                return $0.id < $1.id
            }
            return $0.boardStyle.displayOrder < $1.boardStyle.displayOrder
        }
    }

    private var firstLevel: CampaignLevel? { orderedLevels.first }

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpacing.medium) {
                    HStack(alignment: .top) {
                        PPBackButton { dismiss() }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(ppLocalized("city.\(firstLevel?.cityID.rawValue ?? "rome").name").uppercased())
                                .font(.title.weight(.black))
                                .fontDesign(.rounded)
                            Text(ppLocalized("country.\(firstLevel?.countryID.rawValue ?? "it").name").uppercased())
                                .font(.headline.bold())
                                .foregroundStyle(PPColor.teal)
                        }
                        Spacer()
                        Image("PPRomeStamp", bundle: .main)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 68, height: 68)
                            .rotationEffect(.degrees(5))
                            .accessibilityHidden(true)
                    }

                    Image("PPRomeHero", bundle: .main)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.36, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: PPRadius.card))
                        .overlay {
                            RoundedRectangle(cornerRadius: PPRadius.card)
                                .stroke(PPColor.border, lineWidth: 1)
                        }
                        .accessibilityHidden(true)

                    Text(ppLocalized("city.\(firstLevel?.cityID.rawValue ?? "rome").description"))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, PPSpacing.small)

                    VStack(spacing: PPSpacing.small) {
                        ForEach(Array(orderedLevels.enumerated()), id: \.element.id) { index, level in
                            let isUnlocked = isUnlocked(at: index)
                            Button {
                                if isUnlocked { onOpen(level) }
                            } label: {
                                RomeLocationRow(
                                    level: level,
                                    number: index + 1,
                                    progress: progress[level.id],
                                    isUnlocked: isUnlocked
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!isUnlocked)
                        }
                    }

                    PPPostcardCard {
                        HStack {
                            VStack(alignment: .leading, spacing: PPSpacing.xxSmall) {
                                Text(ppLocalized("city.reward").uppercased())
                                    .font(.caption.weight(.black))
                                Text(ppLocalized("city.rewardDescription"))
                                    .font(.caption)
                                    .foregroundStyle(PPColor.ink.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "building.columns.fill")
                                .font(.title)
                                .foregroundStyle(PPColor.gold)
                        }
                    }
                }
                .padding(PPSpacing.medium)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .ppHiddenNavigationBar()
    }

    private func isUnlocked(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return progress[orderedLevels[index - 1].id]?.isCompleted == true
    }
}

private struct RomeLocationRow: View {
    let level: CampaignLevel
    let number: Int
    let progress: LevelProgress?
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: PPSpacing.small) {
            Image(level.boardStyle.artworkAssetName, bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 88)
                .clipShape(.rect(cornerRadius: PPRadius.small))
                .saturation(isUnlocked ? 1 : 0.28)
                .overlay {
                    if !isUnlocked {
                        PPColor.ink.opacity(0.16)
                        Image(systemName: "lock.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }

            VStack(alignment: .leading, spacing: PPSpacing.xxSmall) {
                Text(ppLocalized("location.\(level.locationID.rawValue).name").uppercased())
                    .font(.subheadline.weight(.black))
                    .lineLimit(2)
                Text("\(ppLocalized("preview.level")) \(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PPColor.teal)
                Text(ppLocalized("level.\(level.id.rawValue).summary"))
                    .font(.caption2)
                    .foregroundStyle(PPColor.ink.opacity(0.68))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if isUnlocked {
                PPRewardStars(earned: progress?.bestStars.rawValue ?? 0)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(PPColor.ink.opacity(0.3))
            }
        }
        .padding(PPSpacing.xSmall)
        .frame(maxWidth: .infinity, minHeight: 108)
        .background(PPColor.surface, in: .rect(cornerRadius: PPRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PPRadius.card)
                .stroke(PPColor.border.opacity(0.78), lineWidth: 1)
        }
        .opacity(isUnlocked ? 1 : 0.82)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(isUnlocked ? ppLocalized("Ready") : ppLocalized("destinations.locked")))
    }
}

struct PuzzlePreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let level: CampaignLevel
    let onStart: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(spacing: PPSpacing.medium) {
                    HStack {
                        PPBackButton { dismiss() }
                        Spacer()
                        VStack(spacing: 0) {
                            Text(ppLocalized("preview.title").uppercased())
                                .font(.title3.weight(.black))
                            Text(ppLocalized("city.\(level.cityID.rawValue).name").uppercased())
                                .font(.subheadline.bold())
                                .foregroundStyle(PPColor.teal)
                        }
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }

                    PPPostcardCard {
                        VStack(alignment: .leading, spacing: PPSpacing.medium) {
                            Image(level.boardStyle.artworkAssetName, bundle: .main)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1.46, contentMode: .fit)
                                .clipShape(.rect(cornerRadius: PPRadius.small))
                                .accessibilityHidden(true)
                            Text(ppLocalized("location.\(level.locationID.rawValue).name").uppercased())
                                .font(.title3.weight(.black))
                            Text(ppLocalized("level.\(level.id.rawValue).objective"))
                                .foregroundStyle(PPColor.ink.opacity(0.72))
                            HStack {
                                Text("\(ppLocalized("preview.level")) \(level.boardStyle.displayOrder + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(PPColor.teal)
                                Spacer()
                                Image(systemName: "star.fill")
                                    .foregroundStyle(PPColor.gold)
                            }
                        }
                    }

                    Button(ppLocalized("preview.start"), action: onStart)
                        .buttonStyle(.ppPrimary)
                }
                .padding(PPSpacing.medium)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .ppHiddenNavigationBar()
    }
}

extension PuzzleBoardStyle {
    var artworkAssetName: String {
        switch self {
        case .theatre: "PPTheatreBoard"
        case .standing: "PPRomeHero"
        case .aircraft: "PPAircraftBoard"
        case .restaurant: "PPRestaurantBoard"
        case .grouping: "PPColosseumBoard"
        case .route: "PPRomeHero"
        }
    }

    var displayOrder: Int {
        switch self {
        case .theatre: 0
        case .standing: 1
        case .aircraft: 2
        case .restaurant: 3
        case .grouping: 4
        case .route: 5
        }
    }
}

private extension View {
    @ViewBuilder
    func ppHiddenNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
