import SwiftUI
import MapKit

final class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = .address
        super.init()
        completer.delegate = self
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error:", error.localizedDescription)
    }
}

struct AddressSearchView: View {
    @Binding var text: String
    @StateObject private var vm = SearchCompleter()
    @State private var showSuggestions = false
    var placeholder: String

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .onChange(of: text) { newValue in
                    showSuggestions = true
                    vm.update(query: newValue)
                }

            if showSuggestions && !text.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(vm.suggestions.prefix(10), id: \.self) { item in
                            Button {
                                let full = item.subtitle.isEmpty
                                    ? item.title
                                    : "\(item.title), \(item.subtitle)"
                                text = full
                                showSuggestions = false
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.body)
                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                            }
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200) // keep it compact
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.top, 10)
    }
}
