import Foundation

struct WeatherInfo: Sendable {
    let temperatureCelsius: Double
    let symbolName: String
    let conditionLabel: String
    let timezoneAbbreviation: String
    let timezoneIdentifier: String
}

// MARK: - Protocol

protocol TripWeatherServiceProtocol {
    func fetch(latitude: Double, longitude: Double) async throws -> WeatherInfo
}

// MARK: - Implementation

final class TripWeatherService: TripWeatherServiceProtocol {

    func fetch(latitude: Double, longitude: Double) async throws -> WeatherInfo {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,weather_code"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
            .init(name: "temperature_unit", value: "celsius")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        return WeatherInfo(
            temperatureCelsius: decoded.current.temperature_2m,
            symbolName: Self.symbol(for: decoded.current.weather_code),
            conditionLabel: Self.condition(for: decoded.current.weather_code),
            timezoneAbbreviation: decoded.timezone_abbreviation,
            timezoneIdentifier: decoded.timezone
        )
    }

    // MARK: - WMO Code Mapping

    private static func symbol(for code: Int) -> String {
        switch code {
        case 0, 1:      return "sun.max.fill"
        case 2:         return "cloud.sun.fill"
        case 3:         return "cloud.fill"
        case 45, 48:    return "cloud.fog.fill"
        case 51...57:   return "cloud.drizzle.fill"
        case 61...67:   return "cloud.rain.fill"
        case 71...77:   return "cloud.snow.fill"
        case 80...82:   return "cloud.heavyrain.fill"
        case 85, 86:    return "snowflake"
        case 95:        return "cloud.bolt.fill"
        case 96, 99:    return "cloud.bolt.rain.fill"
        default:        return "cloud.fill"
        }
    }

    private static func condition(for code: Int) -> String {
        switch code {
        case 0:          return "Clear Sky"
        case 1:          return "Mainly Clear"
        case 2:          return "Partly Cloudy"
        case 3:          return "Overcast"
        case 45:         return "Foggy"
        case 48:         return "Icy Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57:     return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67:     return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77:         return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86:     return "Snow Showers"
        case 95:         return "Thunderstorm"
        case 96, 99:     return "Hail Storm"
        default:         return "Cloudy"
        }
    }
}

// MARK: - Decodable Response

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
    }
    let current: Current
    let timezone: String
    let timezone_abbreviation: String
}
