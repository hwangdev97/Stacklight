import SwiftUI
import StackLightCore

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @SettingsValue(\.pollIntervalSeconds) private var pollInterval: Double
    @SettingsValue(\.notificationsEnabled) private var notificationsEnabled: Bool

    var body: some View {
        ZStack {
            DesignTokens.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    SettingsCard(title: "Refresh Interval",
                                 footer: "How often StackLight fetches new deployment data.") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            HStack {
                                Label("Interval", systemImage: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(Int(pollInterval))s")
                                    .font(DesignTokens.Typography.numeric(size: 18))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .liquidGlassChip()
                            }

                            Slider(value: $pollInterval, in: 30...300, step: 30) {
                                Text("Refresh interval")
                            } minimumValueLabel: {
                                Text("30s")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            } maximumValueLabel: {
                                Text("5m")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .tint(DesignTokens.Palette.review)
                            .onChange(of: pollInterval) { _, _ in
                                appState.restartPolling()
                            }
                        }
                    }

                    SettingsCard(title: "Notifications",
                                 footer: "Notify when a deployment succeeds or fails.") {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("Status Change Notifications", systemImage: "bell.badge")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .tint(DesignTokens.Palette.success)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
            .environmentObject(AppState())
    }
    .preferredColorScheme(.dark)
}
