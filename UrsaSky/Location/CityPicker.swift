import SwiftUI

struct CityPickerView: View {
    @EnvironmentObject var app: AppState
    @State private var filter = ""
    private let cities = CityStore.load()

    var body: some View {
        List {
            ForEach(filtered) { city in
                Button {
                    app.location.applyCity(city)
                    app.clock.timeZoneId = city.timeZoneId
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(city.name).foregroundStyle(app.theme.primaryText)
                            Text(city.country).font(.caption).foregroundStyle(app.theme.secondaryText)
                        }
                        Spacer()
                        Text(city.timeZoneId)
                            .font(.caption2)
                            .foregroundStyle(app.theme.secondaryText)
                    }
                }
            }
        }
        .searchable(text: $filter, prompt: "City")
        .scrollContentBackground(.hidden)
        .background(app.theme.background)
        .navigationTitle("Cities")
    }

    private var filtered: [City] {
        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return cities }
        return cities.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.country.localizedCaseInsensitiveContains(q)
        }
    }
}
