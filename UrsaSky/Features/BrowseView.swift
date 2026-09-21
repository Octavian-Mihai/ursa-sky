import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var mode = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Mode", selection: $mode) {
                    Text("Search").tag(0)
                    Text("Constellations").tag(1)
                    Text("Bright stars").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                if mode == 0 {
                    searchList
                } else if mode == 1 {
                    constellations
                } else {
                    bright
                }
            }
            .background(app.theme.background)
            .navigationTitle("Browse")
        }
        .searchable(text: $query, prompt: "Star or constellation")
    }

    private var searchList: some View {
        List(hits) { hit in
            Button {
                switch hit.kind {
                case .star:
                    app.selectedConstellation = nil
                    app.selectedStar = hit.star
                case .constellation:
                    app.selectedStar = nil
                    app.selectedConstellation = hit.constellation
                }
            } label: {
                VStack(alignment: .leading) {
                    Text(hit.title).foregroundStyle(app.theme.primaryText)
                    Text(hit.subtitle).font(.caption).foregroundStyle(app.theme.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var constellations: some View {
        List(app.catalog.allConstellations()) { c in
            Button {
                app.selectedConstellation = c
            } label: {
                VStack(alignment: .leading) {
                    Text(c.name).foregroundStyle(app.theme.primaryText)
                    Text("\(c.iau) · \(c.season)").font(.caption).foregroundStyle(app.theme.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var bright: some View {
        List(app.catalog.stars(brighterThan: 2.5)) { s in
            Button { app.selectedStar = s } label: {
                HStack {
                    Text(s.displayName).foregroundStyle(app.theme.primaryText)
                    Spacer()
                    Text(String(format: "%.2f", s.mag)).foregroundStyle(app.theme.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var hits: [SearchHit] {
        SearchIndex.search(query: query, catalog: app.catalog)
    }
}
