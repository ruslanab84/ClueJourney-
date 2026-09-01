import PPApplication
import PPDesignSystem
import PPDomain
import SwiftUI

struct CompletionScreen: View {
    let outcome: CompletionOutcome
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(spacing: PPSpacing.large) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 82))
                        .foregroundStyle(PPColor.teal)
                        .accessibilityHidden(true)

                    VStack(spacing: PPSpacing.xSmall) {
                        Text(ppLocalized("completion.title"))
                            .font(.largeTitle.bold())
                            .fontDesign(.rounded)
                        Text(ppLocalized("completion.subtitle"))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(PPColor.ink.opacity(0.7))
                    }

                    PPPostcardCard {
                        HStack {
                            VStack(alignment: .leading, spacing: PPSpacing.xSmall) {
                                Text(ppLocalized("completion.reward")).font(.headline)
                                PPRewardStars(earned: outcome.result.stars.rawValue)
                            }
                            Spacer()
                            PPMoveBadge(moveCount: outcome.result.moveCount)
                        }
                    }

                    Button(ppLocalized("completion.discover"), action: onContinue)
                        .buttonStyle(.ppPrimary)
                }
                .padding(PPSpacing.large)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .navigationBarBackButtonHidden()
    }
}

struct DiscoveryScreen: View {
    let fact: TravelFact
    let onDone: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpacing.large) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(PPColor.terracotta)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: PPSpacing.xSmall) {
                        Text(ppLocalized("discovery.eyebrow"))
                            .font(.subheadline.bold())
                            .foregroundStyle(PPColor.teal)
                        Text(ppLocalized(fact.titleKey))
                            .font(.largeTitle.bold())
                            .fontDesign(.rounded)
                    }

                    PPPostcardCard {
                        VStack(alignment: .leading, spacing: PPSpacing.medium) {
                            Text(ppLocalized(fact.bodyKey))
                                .font(.title3)
                                .lineSpacing(4)
                            Link(destination: fact.source.url) {
                                Label(fact.source.title, systemImage: "safari")
                                    .font(.footnote.bold())
                            }
                        }
                    }

                    Button(ppLocalized("discovery.done"), action: onDone)
                        .buttonStyle(.ppPrimary)
                }
                .padding(PPSpacing.large)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(PPColor.ink)
        .navigationBarBackButtonHidden()
    }
}
