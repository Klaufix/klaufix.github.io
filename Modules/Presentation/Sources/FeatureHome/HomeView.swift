import CreatureRenderer
import DesignSystem
import GameEngine
import SwiftUI

/// Der Hauptbildschirm.
///
/// Aufteilung nach UI-Konzept §4: Der Kreatur gehört die Bühne, Bedürfnisse
/// stehen klein darunter, und statt einer Aufgabenliste steht dort höchstens
/// ein freundlicher Vorschlag.
@MainActor
public struct HomeView: View {
    @Environment(\.palette) private var palette
    @State private var model: HomeModel

    public init(model: HomeModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            stage
            tray
        }
        .background(palette.canvas)
        .onAppear { model.refresh() }
        .sheet(isPresented: $model.showsReunion) {
            ReunionSheet(text: model.reunionText)
        }
    }

    // MARK: - Bühne

    private var stage: some View {
        ZStack {
            palette.accentSoft.opacity(0.45)

            VStack(spacing: Layout.spacing) {
                if let descriptor = model.descriptor {
                    CreatureView(
                        descriptor: descriptor,
                        mood: model.mood,
                        size: 200,
                        accessibilityDescription: model.accessibilitySummary
                    )
                    // Streicheln ist eine Berührung, kein Formular: kein Dialog,
                    // keine Bestätigung.
                    .onTapGesture { model.pet() }
                }

                Text(model.displayName)
                    .font(Typography.title)
                    .foregroundStyle(palette.ink)

                Text(model.moodDescription)
                    .font(Typography.body)
                    .foregroundStyle(palette.inkSoft)
            }
            .padding(Layout.spacingSection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ablage

    private var tray: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            if let suggestion = model.suggestion {
                Text(suggestion)
                    .font(Typography.label)
                    .foregroundStyle(palette.ink)
                    .padding(.bottom, Layout.spacingTiny)
            }

            ForEach(model.needs, id: \.title) { need in
                NeedMeter(
                    title: need.title,
                    systemImage: need.symbol,
                    fraction: need.fraction,
                    stateDescription: need.state
                )
            }

            HStack(spacing: Layout.spacing) {
                PrimaryActionButton("Füttern", systemImage: "fork.knife") {
                    model.feed()
                }
                PrimaryActionButton(
                    model.isAsleep ? "Wecken" : "Schlafen",
                    systemImage: model.isAsleep ? "sun.max.fill" : "moon.fill"
                ) {
                    model.toggleSleep()
                }
            }
            .padding(.top, Layout.spacingSmall)
        }
        .padding(Layout.spacingSection)
        .background(palette.surface)
    }
}

private struct ReunionSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    let text: String

    var body: some View {
        VStack(spacing: Layout.spacingSection) {
            Text(text)
                .font(Typography.title)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)

            PrimaryActionButton("Schön, wieder da zu sein") {
                dismiss()
            }
        }
        .padding(Layout.spacingScreen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.canvas)
    }
}
