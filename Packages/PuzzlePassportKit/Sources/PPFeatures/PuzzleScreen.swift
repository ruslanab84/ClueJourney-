import PPApplication
import PPDesignSystem
import PPDomain
import SwiftUI

struct PuzzleScreen: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: JourneyFlowModel
    let onCompletion: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()

            if let experience = model.experience {
                ScrollView {
                    VStack(spacing: PPSpacing.medium) {
                        header(experience)
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: PPSpacing.medium) {
                                gameColumn(experience)
                                ClueCard(keys: experience.level.clueKeys, evaluations: model.clueEvaluations)
                                    .frame(width: 280)
                            }
                            VStack(spacing: PPSpacing.medium) {
                                gameColumn(experience)
                                ClueCard(keys: experience.level.clueKeys, evaluations: model.clueEvaluations)
                            }
                        }
                        actions(canUndo: !experience.session.history.isEmpty)
                    }
                    .padding(PPSpacing.medium)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ProgressView()
            }
        }
        .foregroundStyle(PPColor.ink)
        .navigationTitle(ppLocalized("puzzle.title"))
        .ppInlineNavigationTitle()
    }

    private func header(_ experience: PuzzleExperience) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: PPSpacing.xxSmall) {
                Text(ppLocalized("city.\(experience.level.cityID.rawValue).name"))
                    .font(.subheadline.bold())
                    .foregroundStyle(PPColor.teal)
                Text(ppLocalized(experience.level.titleKey))
                    .font(.title2.bold())
                    .fontDesign(.rounded)
                Text(ppLocalized("level.\(experience.level.id.rawValue).objective"))
                    .font(.subheadline)
                    .foregroundStyle(PPColor.ink.opacity(0.7))
            }
            Spacer()
            PPMoveBadge(moveCount: experience.session.moveCount)
        }
    }

    private func gameColumn(_ experience: PuzzleExperience) -> some View {
        VStack(spacing: PPSpacing.medium) {
            TheatreBoard(
                level: experience.level,
                session: experience.session,
                selectedEntityID: model.selectedEntityID,
                hintedEntityID: model.hintedEntityID,
                isLocked: { model.isLocked($0, in: experience.level) },
                onTapPosition: tap,
                onPlace: place
            )
            TravellerTray(
                level: experience.level,
                session: experience.session,
                selectedEntityID: model.selectedEntityID,
                hintedEntityID: model.hintedEntityID,
                onSelect: model.select
            )
        }
        .frame(maxWidth: 560)
    }

    private func actions(canUndo: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: PPSpacing.small))
            : AnyLayout(HStackLayout(spacing: PPSpacing.small))
        return layout {
            action("puzzle.undo", symbol: "arrow.uturn.backward") { Task { await model.undo() } }
                .disabled(!canUndo)
            action("puzzle.hint", symbol: "lightbulb") { Task { await model.requestHint() } }
            action("puzzle.restart", symbol: "arrow.clockwise") { Task { await model.restart() } }
        }
    }

    private func action(_ key: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(ppLocalized(key), systemImage: symbol)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(PPColor.travelBlue)
    }

    private func place(_ entityID: EntityID, at positionID: PositionID) {
        Task {
            if await model.place(entityID: entityID, at: positionID) {
                onCompletion()
            }
        }
    }

    private func tap(_ positionID: PositionID) {
        Task {
            if await model.tap(positionID: positionID) {
                onCompletion()
            }
        }
    }
}

private struct TheatreBoard: View {
    let level: CampaignLevel
    let session: PuzzleSession
    let selectedEntityID: EntityID?
    let hintedEntityID: EntityID?
    let isLocked: (PositionID) -> Bool
    let onTapPosition: (PositionID) -> Void
    let onPlace: (EntityID, PositionID) -> Void

    private var rows: [Int] {
        Array(Set(level.puzzle.positions.map(\.coordinate.row))).sorted()
    }

    var body: some View {
        PPPostcardCard {
            VStack(spacing: PPSpacing.medium) {
                Label(ppLocalized("puzzle.stage"), systemImage: "theatermasks.fill")
                    .font(.headline)
                    .foregroundStyle(PPColor.terracotta)

                Grid(horizontalSpacing: PPSpacing.small, verticalSpacing: PPSpacing.small) {
                    ForEach(rows, id: \.self) { row in
                        GridRow {
                            ForEach(positions(in: row)) { position in
                                seat(position)
                            }
                        }
                    }
                }
            }
        }
    }

    private func seat(_ position: PuzzlePosition) -> some View {
        let occupant = session.arrangement.entity(at: position.id)
        let locked = isLocked(position.id)
        return SeatTarget(
            position: position,
            entityID: occupant,
            nameKey: occupant.flatMap { level.entityNameKeys[$0] },
            selected: occupant == selectedEntityID,
            hinted: occupant == hintedEntityID,
            targetHighlighted: selectedEntityID != nil && !locked,
            locked: locked,
            onTap: { onTapPosition(position.id) },
            onDrop: { onPlace($0, position.id) }
        )
    }

    private func positions(in row: Int) -> [PuzzlePosition] {
        level.puzzle.positions
            .filter { $0.coordinate.row == row }
            .sorted { $0.coordinate.column < $1.coordinate.column }
    }
}

private struct SeatTarget: View {
    let position: PuzzlePosition
    let entityID: EntityID?
    let nameKey: String?
    let selected: Bool
    let hinted: Bool
    let targetHighlighted: Bool
    let locked: Bool
    let onTap: () -> Void
    let onDrop: (EntityID) -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if let entityID, let nameKey {
                    if locked {
                        token(entityID, nameKey: nameKey)
                    } else {
                        token(entityID, nameKey: nameKey)
                            .draggable(entityID.rawValue)
                    }
                } else {
                    VStack(spacing: PPSpacing.xSmall) {
                        Image(systemName: "chair.lounge.fill").font(.title2)
                        Text(ppLocalized("puzzle.emptySeat")).font(.caption)
                    }
                    .foregroundStyle(PPColor.ink.opacity(0.72))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .padding(PPSpacing.xSmall)
            .background(
                targetHighlighted ? PPColor.gold.opacity(0.2) : PPColor.paper.opacity(0.7),
                in: .rect(cornerRadius: PPRadius.control)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPRadius.control)
                    .stroke(
                        targetHighlighted ? PPColor.gold : PPColor.ink.opacity(0.14),
                        style: StrokeStyle(lineWidth: targetHighlighted ? 2 : 1, dash: [6, 4])
                    )
            }
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard !locked, let rawID = items.first else { return false }
            onDrop(EntityID(rawID))
            return true
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private func token(_ entityID: EntityID, nameKey: String) -> some View {
        CharacterToken(
            entityID: entityID,
            nameKey: nameKey,
            selected: selected,
            hinted: hinted,
            locked: locked
        )
    }

    private var seatName: String {
        "\(ppLocalized("puzzle.row")) \(position.coordinate.row + 1), "
            + "\(ppLocalized("puzzle.seat")) \(position.coordinate.column + 1)"
    }

    private var accessibilityLabel: String {
        let occupant = nameKey.map(ppLocalized) ?? ppLocalized("puzzle.emptySeat")
        return "\(occupant), \(seatName)"
    }

    private var accessibilityValue: String {
        if locked { return ppLocalized("puzzle.fixedSeat") }
        if selected { return ppLocalized("puzzle.selected") }
        return ""
    }

    private var accessibilityHint: String {
        if locked { return ppLocalized("puzzle.fixedSeatHint") }
        return targetHighlighted ? ppLocalized("puzzle.placeHint") : ppLocalized("puzzle.selectHint")
    }
}

private struct TravellerTray: View {
    let level: CampaignLevel
    let session: PuzzleSession
    let selectedEntityID: EntityID?
    let hintedEntityID: EntityID?
    let onSelect: (EntityID) -> Void

    private var unplaced: [EntityID] {
        level.puzzle.entities.map(\.id)
            .filter { session.arrangement.position(of: $0) == nil }
            .sorted()
    }

    var body: some View {
        PPPostcardCard {
            VStack(alignment: .leading, spacing: PPSpacing.small) {
                Text(ppLocalized("puzzle.travellers")).font(.headline)
                if unplaced.isEmpty {
                    Label(ppLocalized("puzzle.allSeated"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(PPColor.teal)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                        ForEach(unplaced, id: \.self) { entityID in
                            Button { onSelect(entityID) } label: {
                                CharacterToken(
                                    entityID: entityID,
                                    nameKey: level.entityNameKeys[entityID] ?? entityID.rawValue,
                                    selected: selectedEntityID == entityID,
                                    hinted: hintedEntityID == entityID,
                                    locked: false
                                )
                            }
                            .buttonStyle(.plain)
                            .draggable(entityID.rawValue)
                        }
                    }
                }
            }
        }
    }
}

private struct CharacterToken: View {
    let entityID: EntityID
    let nameKey: String
    let selected: Bool
    let hinted: Bool
    let locked: Bool

    var body: some View {
        VStack(spacing: PPSpacing.xxSmall) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(PPColor.travelBlue)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .padding(5)
                        .foregroundStyle(.white)
                        .background(PPColor.terracotta, in: .circle)
                }
            }
            Text(ppLocalized(nameKey))
                .font(.caption.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PPSpacing.xSmall)
        .frame(maxWidth: .infinity)
        .background(
            selected || hinted ? PPColor.gold.opacity(0.2) : Color.clear,
            in: .rect(cornerRadius: PPRadius.small)
        )
        .overlay {
            if selected || hinted {
                RoundedRectangle(cornerRadius: PPRadius.small).stroke(PPColor.gold, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ClueCard: View {
    let keys: [String]
    let evaluations: [ConstraintEvaluation]

    var body: some View {
        PPPostcardCard {
            VStack(alignment: .leading, spacing: PPSpacing.small) {
                Label(ppLocalized("puzzle.clues"), systemImage: "list.number").font(.headline)
                ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                    HStack(alignment: .top, spacing: PPSpacing.xSmall) {
                        Image(systemName: symbol(at: index))
                            .foregroundStyle(color(at: index))
                        Text(ppLocalized(key)).font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(ppLocalized(key)))
                    .accessibilityValue(Text(statusKey(at: index)))
                }
            }
        }
    }

    private func satisfaction(at index: Int) -> ConstraintSatisfaction {
        evaluations.indices.contains(index) ? evaluations[index].satisfaction : .undetermined
    }

    private func symbol(at index: Int) -> String {
        switch satisfaction(at: index) {
        case .satisfied: "checkmark.circle.fill"
        case .violated: "xmark.circle.fill"
        case .undetermined: "circle.dotted"
        }
    }

    private func color(at index: Int) -> Color {
        switch satisfaction(at: index) {
        case .satisfied: PPColor.teal
        case .violated: PPColor.terracotta
        case .undetermined: PPColor.ink.opacity(0.68)
        }
    }

    private func statusKey(at index: Int) -> String {
        switch satisfaction(at: index) {
        case .satisfied: ppLocalized("puzzle.clue.satisfied")
        case .violated: ppLocalized("puzzle.clue.violated")
        case .undetermined: ppLocalized("puzzle.clue.unresolved")
        }
    }
}
