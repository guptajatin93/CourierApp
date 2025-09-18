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
    @State private var isSelecting = false
    @State private var isProgrammaticUpdate = false
    var placeholder: String
    @Binding var disableSuggestions: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .onChange(of: text) { newValue in
                    print("📝 Text changed to: '\(newValue)', disableSuggestions: \(disableSuggestions), isSelecting: \(isSelecting), isProgrammaticUpdate: \(isProgrammaticUpdate)")
                    
                    if !disableSuggestions && !isSelecting && !isProgrammaticUpdate && !newValue.isEmpty {
                        print("✅ Showing suggestions")
                        showSuggestions = true
                        vm.update(query: newValue)
                    } else if newValue.isEmpty {
                        print("❌ Hiding suggestions (empty text)")
                        showSuggestions = false
                    } else {
                        print("🚫 Not showing suggestions (disabled/selecting/programmatic)")
                    }
                    
                    // Reset programmatic update flag after a short delay
                    if isProgrammaticUpdate {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isProgrammaticUpdate = false
                        }
                    }
                }

            if showSuggestions && !text.isEmpty && !disableSuggestions {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(vm.suggestions.prefix(10), id: \.self) { item in
                            Button {
                                isSelecting = true
                                let full = item.subtitle.isEmpty
                                    ? item.title
                                    : "\(item.title), \(item.subtitle)"
                                text = full
                                showSuggestions = false
                                
                                // Reset selection flag after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSelecting = false
                                }
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
        .onTapGesture {
            // Dismiss suggestions when tapping outside
            if showSuggestions {
                showSuggestions = false
            }
        }
        .onChange(of: disableSuggestions) { isDisabled in
            print("🔧 disableSuggestions changed to: \(isDisabled)")
            if isDisabled {
                print("🚫 Hiding suggestions due to disableSuggestions")
                showSuggestions = false
            }
        }
    }
    
    // Method to set text programmatically without showing suggestions
    func setTextProgrammatically(_ newText: String) {
        isProgrammaticUpdate = true
        text = newText
    }
}
