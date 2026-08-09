import SwiftUI

struct ContentView: View {
    @State private var testText: String = ""
    
    private let dictionaryVersion = "0.1"
    private let dictionaryWordCount = "≈ 3100"
    private let keyboardName = "Удмуртская"
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    introSection
                    featuresSection
                    statusSection
                    installSection
                    typingSection
                    dictionarySection
                    settingsSection
                    personalDictionarySection
                    privacySection
                    testSection
                }
                .padding()
            }
        }
    }

    @AppStorage(SharedSettings.suggestionsEnabledKey, store: SharedSettings.defaults)
    private var suggestionsEnabled = true

    @AppStorage(SharedSettings.autocorrectionEnabledKey, store: SharedSettings.defaults)
    private var autocorrectionEnabled = true

    @AppStorage(SharedSettings.personalDictionaryEnabledKey, store: SharedSettings.defaults)
    private var personalDictionaryEnabled = true

    @State private var didRequestPersonalDictionaryReset = false

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image("AppIconPreview")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("U-keyboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)

                    Text("Клавиатура для удмуртского")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }

            Text("Удобный набор удмуртских букв, подсказки слов, автозамена и личный словарь — локально на устройстве и без полного доступа.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusSection: some View {
        InfoCard(title: "Состояние") {
            VStack(alignment: .leading, spacing: 10) {
                Label(appVersionText, systemImage: "number")
                Label("Словарь: около 3100 слов", systemImage: "text.book.closed")
                Label("Подсказки, автозамена и личный словарь работают локально", systemImage: "checkmark.shield")
            }

            Text("Это предварительная версия. Клавиатура уже подходит для тестирования на устройстве, но словарь и подсказки будут постепенно улучшаться.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var installSection: some View {
        InfoCard(title: "Как включить?") {
            VStack(alignment: .leading, spacing: 10) {
                StepRow(number: 1, text: "Откройте Настройки iPhone")
                StepRow(number: 2, text: "Перейдите в Основные → Клавиатура")
                StepRow(number: 3, text: "Откройте Клавиатуры")
                StepRow(number: 4, text: "Нажмите Новые клавиатуры")
                StepRow(number: 5, text: "Выберите «Удмуртская»")
            }

            Text("Полный доступ включать не нужно.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
    
    private var featuresSection: some View {
        InfoCard(title: "Что умеет клавиатура") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Удмуртские буквы через долгое нажатие", systemImage: "character.cursor.ibeam")
                Label("Подсказки слов во время набора", systemImage: "text.bubble")
                Label("Автозамена частых ошибок", systemImage: "wand.and.stars")
                Label("Личный словарь для часто используемых слов", systemImage: "person.text.rectangle")
                Label("Светлая и темная тема", systemImage: "circle.lefthalf.filled")
            }

            Text("Удмуртские буквы доступны через долгое нажатие на похожие русские буквы: е → ё, ж → ӝ, з → ӟ, и → ӥ, о → ӧ, ч → ӵ.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var typingSection: some View {
        InfoCard(title: "Удмуртские буквы") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Зажмите клавишу, чтобы ввести нужную букву:")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    LetterPairView(base: "Е", extra: "Ё")
                    LetterPairView(base: "Ж", extra: "Ӝ")
                    LetterPairView(base: "З", extra: "Ӟ")
                    LetterPairView(base: "И", extra: "Ӥ")
                    LetterPairView(base: "О", extra: "Ӧ")
                    LetterPairView(base: "Ч", extra: "Ӵ")
                }

                Text("В нижнем регистре доступны: ё, ӝ, ӟ, ӥ, ӧ, ӵ.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var settingsSection: some View {
        InfoCard(title: "Настройки клавиатуры") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Подсказки слов", isOn: $suggestionsEnabled)
                Toggle("Автозамена", isOn: $autocorrectionEnabled)
                Toggle("Личный словарь", isOn: $personalDictionaryEnabled)

                Divider()

                Button(role: .destructive) {
                    resetPersonalDictionaryFromApp()
                } label: {
                    Label("Очистить личный словарь", systemImage: "trash")
                }

                if didRequestPersonalDictionaryReset {
                    Text("Личный словарь будет очищен при следующем открытии клавиатуры.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("Настройки хранятся локально на устройстве. Полный доступ к клавиатуре не требуется.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resetPersonalDictionaryFromApp() {
        SharedSettings.defaults.removeObject(forKey: SharedSettings.userWordWeightsKey)
        SharedSettings.defaults.set(true, forKey: SharedSettings.resetPersonalDictionaryRequestedKey)
        SharedSettings.defaults.synchronize()

        didRequestPersonalDictionaryReset = true
    }

    private var dictionarySection: some View {
        InfoCard(title: "Словарь и подсказки") {
            VStack(alignment: .leading, spacing: 10) {
                Label("\(dictionaryWordCount) слов в текущей версии", systemImage: "text.book.closed")
                Label("Подсказки появляются после двух букв", systemImage: "text.bubble")
                Label("Выбранные слова постепенно поднимаются выше", systemImage: "arrow.up.circle")
                Label("Автозамена срабатывает после пробела", systemImage: "wand.and.stars")
            }

            Text("Это первая рабочая версия, словарь будет расширяться")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
    
    private var personalDictionarySection: some View {
        InfoCard(title: "Личный словарь") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Клавиатура запоминает выбранные и часто набираемые слова", systemImage: "person.crop.circle.badge.plus")
                Label("Личные подсказки хранятся только на устройстве", systemImage: "lock")
                Label("Личный словарь можно очистить в настройках ниже", systemImage: "trash")
            }

            Text("Личный словарь помогает поднимать выше те слова, которые ты чаще используешь. Это работает локально и не требует полного доступа.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var privacySection: some View {
        InfoCard(title: "Приватность") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Клавиатура не требует полного доступа", systemImage: "lock.shield")
                Label("Введенный текст не отправляется на серверы", systemImage: "wifi.slash")
                Label("Настройки и личный словарь хранятся локально", systemImage: "iphone")
            }

            Text("Подсказки, автозамена и личный словарь работают на устройстве. Личный словарь нужен только для того, чтобы чаще используемые слова появлялись выше в подсказках. Его можно очистить в настройках приложения.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var testSection: some View {
        InfoCard(title: "Попробовать") {
            VStack(alignment: .leading, spacing: 12) {
                Text("После включения клавиатуры можно проверить набор здесь.")

                TextEditor(text: $testText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Примеры: ческыт, ӵош, ӧвӧл, ӟеч, ӝыт")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        return "Версия \(version) (\(build))"
    }
}

private struct InfoCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

private struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.body)
        }
    }
}

private struct LetterPairView: View {
    let base: String
    let extra: String

    var body: some View {
        HStack(spacing: 6) {
            Text(base)
                .font(.headline)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(extra)
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ContentView()
}
