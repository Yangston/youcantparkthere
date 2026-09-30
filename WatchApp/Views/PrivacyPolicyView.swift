import SwiftUI

struct PrivacyPolicyView: View {
    private let document = PrivacyDocument.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Privacy policy").font(.headline)
                if let document {
                    Text("Updated \(document.updated)").font(.caption2).foregroundStyle(.secondary)
                    ForEach(document.sections, id: \.title) { section in
                        Text(section.title).font(.headline)
                        Text(section.body).font(.caption)
                    }
                    if let url = URL(string: document.supportURL) {
                        Link("Contact support", destination: url)
                    }
                } else {
                    Text("Policy unavailable. Please use the App Support link on the App Store product page.")
                        .font(.caption)
                }
            }.padding()
        }
    }
}

private struct PrivacyDocument: Decodable {
    struct Section: Decodable { let title: String; let body: String }
    let updated: String
    let supportURL: String
    let sections: [Section]

    static func load() -> Self? {
        guard let url = Bundle.main.url(forResource: "privacy-policy", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
