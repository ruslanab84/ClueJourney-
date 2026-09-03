import PPApplication
import PPDesignSystem
import PPDomain
import SwiftUI

struct PassportPuzzleScreen: View {
    @Environment(\.dismiss) private var dismiss

    let model: JourneyFlowModel
    let onCompletion: () -> Void

    var body: some View {
        ZStack {
            PPPaperBackground()
            if let experience = model.experience {
                ScrollView {
                    VStack(spacing: PPSpacing.small) {
                        header(experience)
                        puzzleSurface(experience)
                    }
                    .padding(.horizontal, PPSpacing.small)
                    .padding(.vertical, PPSpacing.xSmall)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                }
                .disabled(model.isOutOfMoves)
            } else {
                ProgressView()
            }
        }
        .overlay {
            if model.isOutOfMoves {
                OutOfMovesOverlay(
                    onRestart: { Task { await model.restart() } },
                    onLeave: { dismiss() }
                )
            }
        }
        .sensoryFeedback(.error, trigger: model.refusal?.attempt ?? 0)
        .foregroundStyle(PPColor.ink)
        .ppPuzzleNavigationBarHidden()
    }

    private func header(_ experience: PuzzleExperience) -> some View {
        HStack(spacing: PPSpacing.xSmall) {
            PPBackButton { dismiss() }

            VStack(spacing: 1) {
                Text(ppLocalized("location.\(experience.level.locationID.rawValue).name").uppercased())
                    .font(.headline.weight(.black))
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(ppLocalized(experience.level.titleKey))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PPColor.teal)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            PPMoveBadge(moveCount: model.remainingMoves ?? experience.session.moveCount)
        }
    }

    private func puzzleSurface(_ experience: PuzzleExperience) -> some View {
        PPPostcardCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: PPSpacing.small) {
                    gameColumn(experience)
                        .frame(minWidth: 430, maxWidth: .infinity)
                    sideRail(experience)
                        .frame(width: 190)
                }

                VStack(spacing: PPSpacing.small) {
                    gameColumn(experience)
                    sideRail(experience)
                }
            }
        }
    }

    private func sideRail(_ experience: PuzzleExperience) -> some View {
        VStack(alignment: .trailing, spacing: PPSpacing.xxSmall) {
            actionsMenu(
                canUndo: !experience.session.history.isEmpty,
                isBudgeted: experience.level.puzzle.movePolicy.moveLimit != nil
            )

            ClueRail(
                keys: experience.level.clueKeys,
                evaluations: model.clueEvaluations
            )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func actionsMenu(canUndo: Bool, isBudgeted: Bool) -> some View {
        Menu {
            // A budgeted level spends moves on refusals too, so undo cannot refund them honestly.
            if !isBudgeted {
                Button {
                    Task { await model.undo() }
                } label: {
                    Label(ppLocalized("puzzle.undo"), systemImage: "arrow.uturn.backward")
                }
                .disabled(!canUndo)
            }

            Button {
                Task { await model.requestHint() }
            } label: {
                Label(ppLocalized("puzzle.hint"), systemImage: "lightbulb")
            }

            Button(role: .destructive) {
                Task { await model.restart() }
            } label: {
                Label(ppLocalized("puzzle.restart"), systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.headline)
                .foregroundStyle(PPColor.teal)
                .frame(width: 40, height: 40)
                .background(PPColor.paper.opacity(0.86), in: .circle)
                .overlay {
                    Circle().stroke(PPColor.border.opacity(0.75), lineWidth: 1)
                }
        }
        .accessibilityLabel(Text(ppLocalized("puzzle.actions")))
    }

    private func gameColumn(_ experience: PuzzleExperience) -> some View {
        VStack(spacing: PPSpacing.xSmall) {
            IllustratedTheatreBoard(
                level: experience.level,
                session: experience.session,
                selectedEntityID: model.selectedEntityID,
                hintedEntityID: model.hintedEntityID,
                refusal: model.refusal,
                isLocked: { model.isLocked($0, in: experience.level) },
                onTapPosition: tap,
                onPlace: place
            )
            CompactTravellerTray(
                level: experience.level,
                session: experience.session,
                selectedEntityID: model.selectedEntityID,
                hintedEntityID: model.hintedEntityID,
                onSelect: model.select
            )
        }
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

private struct IllustratedTheatreBoard: View {
    let level: CampaignLevel
    let session: PuzzleSession
    let selectedEntityID: EntityID?
    let hintedEntityID: EntityID?
    let refusal: RefusedPlacement?
    let isLocked: (PositionID) -> Bool
    let onTapPosition: (PositionID) -> Void
    let onPlace: (EntityID, PositionID) -> Void

    private var rows: [Int] {
        Array(Set(level.puzzle.positions.map(\.coordinate.row))).sorted()
    }

    var body: some View {
        ZStack {
            Image("PPTheatreBoard", bundle: .main)
                .resizable()
                .scaledToFill()

            Grid(horizontalSpacing: PPSpacing.small, verticalSpacing: PPSpacing.xSmall) {
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        ForEach(positions(in: row)) { position in
                            seat(position)
                        }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 46)
            .padding(.bottom, 20)
        }
        .aspectRatio(1.48, contentMode: .fit)
        .clipShape(.rect(cornerRadius: PPRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PPRadius.card)
                .stroke(PPColor.border, lineWidth: 1)
        }
        .shadow(color: PPColor.ink.opacity(0.1), radius: 4, y: 2)
    }

    private func seat(_ position: PuzzlePosition) -> some View {
        let occupant = session.arrangement.entity(at: position.id)
        let locked = isLocked(position.id)
        return IllustratedSeatTarget(
            position: position,
            entityID: occupant,
            nameKey: occupant.flatMap { level.entityNameKeys[$0] },
            selected: occupant != nil && occupant == selectedEntityID,
            hinted: occupant != nil && occupant == hintedEntityID,
            targetHighlighted: selectedEntityID != nil && !locked,
            locked: locked,
            refusedAttempt: refusal?.positionID == position.id ? refusal?.attempt : nil,
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

private struct IllustratedSeatTarget: View {
    let position: PuzzlePosition
    let entityID: EntityID?
    let nameKey: String?
    let selected: Bool
    let hinted: Bool
    let targetHighlighted: Bool
    let locked: Bool
    /// Rises on every refusal aimed at this seat; `nil` while the seat has not refused anyone.
    let refusedAttempt: Int?
    let onTap: () -> Void
    let onDrop: (EntityID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            Group {
                if let entityID, let nameKey {
                    if locked {
                        PassportCharacterToken(
                            entityID: entityID,
                            nameKey: nameKey,
                            selected: selected,
                            hinted: hinted,
                            locked: true
                        )
                    } else {
                        PassportCharacterToken(
                            entityID: entityID,
                            nameKey: nameKey,
                            selected: selected,
                            hinted: hinted,
                            locked: false
                        )
                        .draggable(entityID.rawValue)
                    }
                } else {
                    RoundedRectangle(cornerRadius: PPRadius.small)
                        .fill(PPColor.surface.opacity(targetHighlighted ? 0.8 : 0.24))
                        .overlay {
                            Image(systemName: "plus")
                                .font(.caption.bold())
                                .foregroundStyle(targetHighlighted ? PPColor.gold : .white.opacity(0.65))
                        }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(.rect)
            .animation(reduceMotion ? nil : .bouncy(duration: 0.32), value: entityID)
            .overlay {
                if targetHighlighted {
                    RoundedRectangle(cornerRadius: PPRadius.small)
                        .stroke(PPColor.gold, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
            }
        }
        .buttonStyle(.plain)
        .keyframeAnimator(
            initialValue: RefusalReaction(),
            trigger: refusedAttempt ?? 0
        ) { [shakes = !reduceMotion] view, reaction in
            view
                .offset(x: shakes ? reaction.offsetX : 0)
                .overlay(alignment: .top) {
                    Text(ppLocalized("puzzle.refused.badge"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(PPColor.terracotta, in: .capsule)
                        .offset(y: -12)
                        .opacity(reaction.bubbleOpacity)
                        .allowsHitTesting(false)
                }
        } keyframes: { _ in
            KeyframeTrack(\.offsetX) {
                CubicKeyframe(-10, duration: 0.07)
                CubicKeyframe(9, duration: 0.07)
                CubicKeyframe(-6, duration: 0.07)
                CubicKeyframe(0, duration: 0.09)
            }
            KeyframeTrack(\.bubbleOpacity) {
                LinearKeyframe(1, duration: 0.05)
                LinearKeyframe(1, duration: 0.75)
                LinearKeyframe(0, duration: 0.3)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard !locked, let rawID = items.first else { return false }
            onDrop(EntityID(rawID))
            return true
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var seatName: String {
        "\(ppLocalized("puzzle.row")) \(position.coordinate.row + 1), "
            + "\(ppLocalized("puzzle.seat")) \(position.coordinate.column + 1)"
    }

    private var accessibilityLabel: String {
        "\(nameKey.map(ppLocalized) ?? ppLocalized("puzzle.emptySeat")), \(seatName)"
    }

    private var accessibilityValue: String {
        if refusedAttempt != nil { return ppLocalized("puzzle.refused") }
        if locked { return ppLocalized("puzzle.fixedSeat") }
        if selected { return ppLocalized("puzzle.selected") }
        return ""
    }

    private var accessibilityHint: String {
        if locked { return ppLocalized("puzzle.fixedSeatHint") }
        return targetHighlighted ? ppLocalized("puzzle.placeHint") : ppLocalized("puzzle.selectHint")
    }
}

private struct CompactTravellerTray: View {
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
        HStack(spacing: PPSpacing.xSmall) {
            if unplaced.isEmpty {
                Label(ppLocalized("puzzle.allSeated"), systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(PPColor.teal)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(unplaced, id: \.self) { entityID in
                    Button { onSelect(entityID) } label: {
                        PassportCharacterToken(
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
        .padding(PPSpacing.xSmall)
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(PPColor.surface, in: .rect(cornerRadius: PPRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PPRadius.card)
                .stroke(PPColor.border.opacity(0.78), lineWidth: 1)
        }
    }
}

private struct PassportCharacterToken: View {
    let entityID: EntityID
    let nameKey: String
    let selected: Bool
    let hinted: Bool
    let locked: Bool

    private var assetName: String {
        "PPCharacter" + entityID.rawValue.prefix(1).uppercased() + entityID.rawValue.dropFirst()
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottomTrailing) {
                Image(assetName, bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(.circle)
                    .overlay {
                        Circle().stroke(
                            selected || hinted ? PPColor.gold : PPColor.surface,
                            lineWidth: selected || hinted ? 3 : 2
                        )
                    }
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .padding(4)
                        .foregroundStyle(.white)
                        .background(PPColor.terracotta, in: .circle)
                }
            }
            Text(ppLocalized(nameKey))
                .font(.caption2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(PPColor.surface.opacity(0.94), in: .capsule)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ClueRail: View {
    let keys: [String]
    let evaluations: [ConstraintEvaluation]

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpacing.small) {
            Text(ppLocalized("puzzle.clues").uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(PPColor.ink.opacity(0.76))
                .frame(maxWidth: .infinity)

            ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                HStack(alignment: .top, spacing: PPSpacing.xxSmall) {
                    Text("\(index + 1).")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(PPColor.ink.opacity(0.7))
                    Text(ppLocalized(key))
                        .font(.caption2.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: symbol(at: index))
                        .font(.caption2)
                        .foregroundStyle(color(at: index))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(ppLocalized(key)))
                .accessibilityValue(Text(statusKey(at: index)))
            }
        }
        .padding(PPSpacing.small)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(PPColor.paper.opacity(0.72), in: .rect(cornerRadius: PPRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PPRadius.card)
                .stroke(PPColor.border.opacity(0.82), lineWidth: 1)
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
        case .undetermined: PPColor.ink.opacity(0.5)
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

/// Animatable state of a refused drop: the seat kicks sideways while an angry badge pops above it.
private struct RefusalReaction {
    var offsetX: Double = 0
    var bubbleOpacity: Double = 0
}

private struct OutOfMovesOverlay: View {
    let onRestart: () -> Void
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            PPColor.ink.opacity(0.55)
                .ignoresSafeArea()
            PPPostcardCard {
                VStack(spacing: PPSpacing.small) {
                    Image(systemName: "hourglass.bottomhalf.filled")
                        .font(.largeTitle)
                        .foregroundStyle(PPColor.terracotta)
                    Text(ppLocalized("puzzle.outOfMoves.title"))
                        .font(.headline.weight(.black))
                    Text(ppLocalized("puzzle.outOfMoves.body"))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button(ppLocalized("puzzle.outOfMoves.retry"), action: onRestart)
                        .buttonStyle(.ppPrimary)
                    Button(ppLocalized("puzzle.outOfMoves.leave"), action: onLeave)
                        .font(.caption.bold())
                        .foregroundStyle(PPColor.teal)
                        .frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(PPSpacing.large)
            .frame(maxWidth: 420)
        }
        .accessibilityAddTraits(.isModal)
    }
}

private extension View {
    @ViewBuilder
    func ppPuzzleNavigationBarHidden() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
