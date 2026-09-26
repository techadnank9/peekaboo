import SwiftUI

/// The look of the cartoon Decart draws.
enum CartoonStyle: String, CaseIterable, Identifiable {
    case pixar, anime, superhero, astronaut, fairyTale, claymation, dinoRider

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pixar: "Pixar 3D"
        case .anime: "Anime"
        case .superhero: "Superhero"
        case .astronaut: "Astronaut"
        case .fairyTale: "Fairy Tale"
        case .claymation: "Claymation"
        case .dinoRider: "Dino Rider"
        }
    }

    var symbol: String {
        switch self {
        case .pixar: "cube.transparent"
        case .anime: "sparkles"
        case .superhero: "bolt.shield"
        case .astronaut: "moon.stars"
        case .fairyTale: "crown"
        case .claymation: "hand.draw"
        case .dinoRider: "lizard"
        }
    }

    var prompt: String {
        switch self {
        case .pixar: "a cute Pixar-style 3D cartoon character with big sparkling eyes"
        case .anime: "a Studio Ghibli-style hand-drawn anime character, soft watercolor background"
        case .superhero: "a tiny cartoon superhero with a flowing cape and a mask, city skyline behind"
        case .astronaut: "a tiny cartoon astronaut in a puffy space suit, floating among stars and planets"
        case .fairyTale: "a storybook fairy-tale royal with a little crown, in front of a magical castle"
        case .claymation: "a claymation figure with visible clay texture, stop-motion look"
        case .dinoRider: "a cartoon explorer riding a friendly green dinosaur in a jungle"
        }
    }
}

/// How the cartoon kid is posed.
enum CartoonPose: String, CaseIterable, Identifiable {
    case asTaken, waving, flying, dancing, jumping, hugging

    var id: String { rawValue }

    var title: String {
        switch self {
        case .asTaken: "As taken"
        case .waving: "Waving"
        case .flying: "Flying"
        case .dancing: "Dancing"
        case .jumping: "Jumping"
        case .hugging: "Hugging"
        }
    }

    var symbol: String {
        switch self {
        case .asTaken: "camera"
        case .waving: "hand.wave"
        case .flying: "airplane"
        case .dancing: "figure.dance"
        case .jumping: "figure.jumprope"
        case .hugging: "heart"
        }
    }

    func prompt(with character: Attractor) -> String {
        switch self {
        case .asTaken: "same pose and expression as the photo"
        case .waving: "happily waving at the viewer"
        case .flying: "flying through the air with arms stretched out"
        case .dancing: "dancing joyfully"
        case .jumping: "jumping in the air with excitement"
        case .hugging: "giving a big hug to a cuddly cartoon animal friend"
        }
    }
}

/// Dress-up: an outfit Decart puts the kid in.
enum CartoonCostume: String, CaseIterable, Identifiable {
    case none, pikachu, minion, mickey, superhero, princess, dinosaur

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Own clothes"
        case .pikachu: "Pikachu"
        case .minion: "Minion"
        case .mickey: "Mickey"
        case .superhero: "Superhero"
        case .princess: "Princess"
        case .dinosaur: "Dinosaur"
        }
    }

    var symbol: String {
        switch self {
        case .none: "tshirt"
        case .pikachu: "bolt.fill"
        case .minion: "eyeglasses"
        case .mickey: "music.note"
        case .superhero: "bolt.shield.fill"
        case .princess: "crown.fill"
        case .dinosaur: "lizard.fill"
        }
    }

    var prompt: String? {
        switch self {
        case .none: nil
        case .pikachu: "a cozy bright yellow animal onesie with pointy black-tipped ears on the hood and red circles on the cheeks"
        case .minion: "blue denim overalls, big round silver goggles and a bright yellow beanie"
        case .mickey: "red shorts with two white buttons, white gloves and a headband with two big round black ears"
        case .superhero: "a bright red and blue superhero suit with a flowing cape"
        case .princess: "a sparkly pink princess gown and a tiara"
        case .dinosaur: "a green dinosaur costume with little spikes on the hood"
        }
    }
}

/// Where the parent sets up Cartoon Me: style, pose and their own touch.
struct CartoonStudio: View {
    @Bindable var model: PeekabooModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Cartoon Me", systemImage: "wand.and.sparkles", isOn: $model.cartoonMe)
                } footer: {
                    Text("After each photo, Decart redraws your kid as a cartoon and the outer display reveals it. Only the finished photo is uploaded.")
                }

                Section("Style") {
                    chips(CartoonStyle.allCases, selected: model.cartoonStyle, title: \.title, symbol: \.symbol) {
                        model.cartoonStyle = $0
                    }
                }

                Section {
                    chips(CartoonCostume.allCases, selected: model.cartoonCostume, title: \.title, symbol: \.symbol) {
                        model.cartoonCostume = $0
                    }
                } header: {
                    Text("Virtual try-on")
                } footer: {
                    Text("Pick an outfit and Decart's try-on model dresses your kid in it. The outer display plays the video.")
                }

                Section("Pose") {
                    chips(CartoonPose.allCases, selected: model.cartoonPose, title: \.title, symbol: \.symbol) {
                        model.cartoonPose = $0
                    }
                }

                Section {
                    TextField("Wearing a birthday hat, with our cat…", text: $model.cartoonPrompt, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Your touch")
                } footer: {
                    Text(model.cartoonPromptPreview)
                        .font(.caption.monospaced())
                }
            }
            .navigationTitle("Cartoon Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    private func chips<Item: Identifiable & Equatable>(
        _ items: [Item], selected: Item,
        title: KeyPath<Item, String>, symbol: KeyPath<Item, String>,
        choose: @escaping (Item) -> Void
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    let isOn = item == selected
                    Button {
                        withAnimation(.snappy) { choose(item) }
                    } label: {
                        Label(item[keyPath: title], systemImage: item[keyPath: symbol])
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(isOn ? .black : .primary)
                            .background(isOn ? Color.yellow : Color.secondary.opacity(0.15), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}
