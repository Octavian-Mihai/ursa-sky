import SwiftUI

private enum BrowseSection: Int, CaseIterable {
    case constellations
    case brightStars
    case meteors

    var title: String {
        switch self {
        case .constellations: return "Constellations"
        case .brightStars: return "Bright stars"
        case .meteors: return "Meteors"
        }
    }

    var searchPrompt: String {
        switch self {
        case .constellations: return "Name or IAU letters"
        case .brightStars: return "Name or Bayer letter"
        case .meteors: return "Shower name"
        }
    }
}

private enum ConstellationFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case visible = "Visible now"
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"
    var id: String { rawValue }
}

private enum StarBrightness: Double, CaseIterable, Identifiable {
    case mag1 = 1.0
    case mag25 = 2.5
    var id: Double { rawValue }
    var title: String {
        switch self {
        case .mag1: return "≤ 1"
        case .mag25: return "≤ 2.5"
        }
    }
}

private enum MeteorFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active now"
    case upcoming = "Upcoming"
    var id: String { rawValue }
}

struct BrowseView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var section = BrowseSection.constellations
    @State private var conFilter = ConstellationFilter.all
    @State private var brightness = StarBrightness.mag25
    @State private var starsVisibleNow = false
    @State private var meteorFilter = MeteorFilter.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Picker("Section", selection: $section) {
                    ForEach(BrowseSection.allCases, id: \.self) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                filters
                if needsLocationHint {
                    Text("Set a location in Settings to use Visible now.")
                        .font(.caption)
                        .foregroundStyle(app.theme.secondaryText)
                        .padding(.horizontal)
                }

                switch section {
                case .constellations:
                    constellationList
                case .brightStars:
                    starList
                case .meteors:
                    meteorList
                }
            }
            .background(app.theme.background)
            .navigationTitle("Browse")
        }
        .searchable(text: $query, prompt: section.searchPrompt)
    }

    @ViewBuilder
    private var filters: some View {
        switch section {
        case .constellations:
            HStack {
                Text("Filter")
                    .foregroundStyle(app.theme.secondaryText)
                Spacer()
                Picker("Filter", selection: $conFilter) {
                    ForEach(ConstellationFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
        case .brightStars:
            VStack(spacing: 6) {
                Picker("Brightness", selection: $brightness) {
                    ForEach(StarBrightness.allCases) { b in
                        Text(b.title).tag(b)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Visible now", isOn: $starsVisibleNow)
            }
            .padding(.horizontal)
        case .meteors:
            Picker("Filter", selection: $meteorFilter) {
                ForEach(MeteorFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }

    private var constellationList: some View {
        List(filteredConstellations) { c in
            Button {
                app.showConstellation(c)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).foregroundStyle(app.theme.primaryText)
                    Text(guideLine(c.equatorial))
                        .font(.caption)
                        .foregroundStyle(app.theme.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var starList: some View {
        List(filteredStars) { s in
            Button { app.showStar(s) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.displayName).foregroundStyle(app.theme.primaryText)
                        Text(guideLine(s.equatorial))
                            .font(.caption)
                            .foregroundStyle(app.theme.secondaryText)
                    }
                    Spacer()
                    Text(String(format: "%.2f", s.mag)).foregroundStyle(app.theme.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var meteorList: some View {
        List(filteredMeteors) { s in
            NavigationLink {
                MeteorDetailView(shower: s)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name)
                        Text("Peak \(s.peak)")
                            .font(.caption)
                            .foregroundStyle(app.theme.secondaryText)
                    }
                    Spacer()
                    if s.isActive(on: app.clock.now()) {
                        Text("Active")
                            .font(.caption2.weight(.bold))
                            .padding(4)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var filteredConstellations: [Constellation] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.catalog.allConstellations().filter { c in
            if !q.isEmpty {
                let hit = c.name.lowercased().contains(q) || c.iau.lowercased().contains(q)
                if !hit { return false }
            }
            switch conFilter {
            case .all:
                return true
            case .visible:
                return isVisible(c.equatorial)
            case .spring, .summer, .autumn, .winter:
                let season = c.season.lowercased()
                return season == conFilter.rawValue.lowercased() || season == "year-round"
            }
        }
    }

    private var filteredStars: [Star] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.catalog.stars(brighterThan: brightness.rawValue).filter { s in
            if !q.isEmpty {
                let nameHit = s.commonName?.lowercased().contains(q) == true
                    || s.displayName.lowercased().contains(q)
                let bayerHit = s.bayer?.lowercased().contains(q) == true
                    || s.bayerLabel?.lowercased().contains(q) == true
                if !nameHit && !bayerHit { return false }
            }
            if starsVisibleNow {
                return isVisible(s.equatorial)
            }
            return true
        }
    }

    private var filteredMeteors: [MeteorShower] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let now = app.clock.now()
        return app.meteors.sortedForCalendar(around: now).filter { s in
            if !q.isEmpty, !s.name.lowercased().contains(q) { return false }
            switch meteorFilter {
            case .all: return true
            case .active: return s.isActive(on: now)
            case .upcoming: return s.isUpcoming(on: now)
            }
        }
    }

    private var needsLocationHint: Bool {
        guard app.location.current == nil else { return false }
        switch section {
        case .constellations: return conFilter == .visible
        case .brightStars: return starsVisibleNow
        case .meteors: return false
        }
    }

    private func isVisible(_ equatorial: Equatorial) -> Bool {
        guard let loc = app.location.current else { return false }
        let h = SkyGuide.horizontal(equatorial: equatorial, jd: app.clock.julianDay(), location: loc)
        return h.alt > 0
    }

    private func guideLine(_ equatorial: Equatorial) -> String {
        guard let loc = app.location.current else {
            return "Set a location to see where to look."
        }
        return SkyGuide.phrase(equatorial: equatorial, jd: app.clock.julianDay(), location: loc)
    }
}
