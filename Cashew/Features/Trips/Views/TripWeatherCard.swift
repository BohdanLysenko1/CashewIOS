import SwiftUI

struct TripWeatherCard: View {
    let info: WeatherInfo?
    let isLoading: Bool

    @AppStorage("weather.useFahrenheit") private var useFahrenheit = false
    @AppStorage("weather.use24Hour") private var use24Hour = false

    var body: some View {
        if isLoading {
            loadingView
        } else if let info {
            loadedCard(info)
        }
    }

    // MARK: - Loaded

    private func loadedCard(_ info: WeatherInfo) -> some View {
        HStack(spacing: AppTheme.Space.md) {
            // Timezone / time
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localTime(for: info))
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                    Text(info.timezoneAbbreviation)
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurface.opacity(0.50))
                }
            }

            Divider().frame(height: 28)

            // Weather
            HStack(spacing: 8) {
                Image(systemName: info.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTemp(from: info))
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(AppTheme.onSurface)
                    Text(info.conditionLabel)
                        .font(AppTheme.TextStyle.caption)
                        .foregroundStyle(AppTheme.onSurface.opacity(0.50))
                }
            }

            Spacer(minLength: 0)

            // Format toggles
            HStack(spacing: 6) {
                toggleChip(label: use24Hour ? "24h" : "12h") {
                    use24Hour.toggle()
                }
                toggleChip(label: useFahrenheit ? "°F" : "°C") {
                    useFahrenheit.toggle()
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, 12)
        .cardStyle()
    }

    private func toggleChip(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.primary.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: AppTheme.Space.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.primary)
                .scaleEffect(0.85)
            Text("Loading weather…")
                .font(AppTheme.TextStyle.caption)
                .foregroundStyle(AppTheme.onSurface.opacity(0.45))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.vertical, 14)
        .cardStyle()
    }

    // MARK: - Formatting

    private func displayTemp(from info: WeatherInfo) -> String {
        let value = useFahrenheit
            ? info.temperatureCelsius * 9 / 5 + 32
            : info.temperatureCelsius
        let unit = useFahrenheit ? "°F" : "°C"
        return "\(Int(value.rounded()))\(unit)"
    }

    private func localTime(for info: WeatherInfo) -> String {
        let tz = TimeZone(identifier: info.timezoneIdentifier) ?? .current
        let formatter = DateFormatter()
        formatter.timeZone = tz
        formatter.dateStyle = .none
        if use24Hour {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.timeStyle = .short
        }
        return formatter.string(from: Date())
    }
}
