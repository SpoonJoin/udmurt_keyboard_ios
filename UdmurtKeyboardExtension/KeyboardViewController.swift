import UIKit

final class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {

    private enum KeyboardMode {
        case letters
        case numbers
        case symbols
    }

    private struct Key {
        let title: String
        let flex: CGFloat
        let kind: Kind

        enum Kind {
            case character(String)
            case shift
            case backspace
            case space
            case `return`
            case nextKeyboard
            case switchMode
        }
    }

    private let letterRowsLower: [[String]] = [
        ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"],
        ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
        ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"]
    ]

    private let numberRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "₽", "&", "@", "\""],
        [".", ",", "?", "!", "'", "«", "»", "—"]
    ]

    private let symbolRows: [[String]] = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "€", "£", "$", "₽"],
        [".", ",", "?", "!", "'", "«", "»", "…"]
    ]

    private let longPressMapLower: [String: String] = [
        "е": "ё",
        "ж": "ӝ",
        "з": "ӟ",
        "и": "ӥ",
        "о": "ӧ",
        "ч": "ӵ"
    ]

    private let longPressMapUpper: [String: String] = [
        "Е": "Ё",
        "Ж": "Ӝ",
        "З": "Ӟ",
        "И": "Ӥ",
        "О": "Ӧ",
        "Ч": "Ӵ"
    ]
    
    private struct DictionaryEntry {
        let word: String
        let weight: Int
    }

    private var dictionary: [DictionaryEntry] = []
    private var dictionaryIndex: [String: [DictionaryEntry]] = [:]
    private let maxUserWords = 500
    private var userWordWeights: [String: Int] = [:]
    private var priorityWords: Set<String> = []
    private var autocorrections: [String: String] = [:]
    private var mode: KeyboardMode = .letters
    private var isShiftOn = false
    private var isCapsLockOn = false
    private var lastShiftTapDate: Date?

    private var rootStack: UIStackView!
    private var popupButton: UIButton?
    private var suggestionsRow: UIStackView?
    
    private var keyPreviewView: UIView?
    
    private weak var spaceLanguageLabel: UILabel?
    
    private var letterKeyButtons: [KeyboardButton] = []
    private weak var shiftKeyButton: UIButton?
    
    private let keySpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 7
    private let keyCornerRadius: CGFloat = 6
    private let keyHeight: CGFloat = 42
    private let suggestionsRowHeight: CGFloat = 36
    private let keyboardHeight: CGFloat = 258
    private let bottomKeyHeight: CGFloat = 42
    
    private var backspaceTimer: Timer?
    private var lastSpaceTapDate: Date?
    private let doubleSpaceThreshold: TimeInterval = 0.45
    
    private var suggestionsEnabled: Bool {
        SharedSettings.bool(SharedSettings.suggestionsEnabledKey)
    }

    private var autocorrectionEnabled: Bool {
        SharedSettings.bool(SharedSettings.autocorrectionEnabledKey)
    }

    private var personalDictionaryEnabled: Bool {
        SharedSettings.bool(SharedSettings.personalDictionaryEnabledKey)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        SharedSettings.registerDefaults()
        
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        
        loadDictionary()
        consumePendingPersonalDictionaryResetIfNeeded()
        loadAutocorrections()
        loadPriorityWords()
        loadUserWordWeights()
        buildDictionaryIndex()
        isShiftOn = shouldAutoCapitalize()
        buildKeyboard()
    }
    
    var enableInputClicksWhenVisible: Bool {
        true
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
            return
        }

        buildKeyboard()
    }
    
    private func keyPreviewBackgroundColor() -> UIColor {
        characterKeyBackgroundColor()
    }
    
    private func keyTextColor() -> UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.white
        } else {
            return UIColor.black
        }
    }

    private func secondaryKeyTextColor() -> UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.45)
        } else {
            return UIColor.black.withAlphaComponent(0.28)
        }
    }
    
    private func keyboardBackgroundColor() -> UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 28 / 255, green: 29 / 255, blue: 32 / 255, alpha: 1)
        } else {
            return UIColor(red: 209 / 255, green: 213 / 255, blue: 219 / 255, alpha: 1)
        }
    }

    private func characterKeyBackgroundColor() -> UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 74 / 255, green: 75 / 255, blue: 80 / 255, alpha: 1)
        } else {
            return UIColor(red: 250 / 255, green: 250 / 255, blue: 252 / 255, alpha: 1)
        }
    }

    private func controlKeyBackgroundColor() -> UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 54 / 255, green: 55 / 255, blue: 60 / 255, alpha: 1)
        } else {
            return UIColor(red: 183 / 255, green: 190 / 255, blue: 200 / 255, alpha: 1)
        }
    }

    private func suggestionSeparatorColor() -> UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.systemGray
        } else {
            return UIColor(white: 0.45, alpha: 0.35)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopBackspaceRepeat()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateReturnKeyTitle()
        updateAutoCapitalizationState()
    }
    
    private func loadDictionary() {
        guard let url = Bundle.main.url(forResource: "udmurt_words", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            dictionary = [
                DictionaryEntry(word: "ческыт", weight: 100),
                DictionaryEntry(word: "удмурт", weight: 95),
                DictionaryEntry(word: "мон", weight: 90),
                DictionaryEntry(word: "тон", weight: 85),
                DictionaryEntry(word: "ӵош", weight: 80),
                DictionaryEntry(word: "ӟеч", weight: 75)
            ]
            return
        }

        dictionary = contents
            .components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    return nil
                }

                let parts = trimmed.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }

                guard let word = parts.first else {
                    return nil
                }

                let weight: Int

                if parts.count >= 2, let parsedWeight = Int(parts[1]) {
                    weight = parsedWeight
                } else {
                    weight = 1
                }

                return DictionaryEntry(word: word, weight: weight)
            }
    }
    
    private func buildDictionaryIndex() {
        dictionaryIndex.removeAll()

        for entry in dictionary {
            let word = entry.word.lowercased()
            let key = prefixKey(for: word)

            guard !key.isEmpty else {
                continue
            }

            dictionaryIndex[key, default: []].append(entry)
        }

        for key in dictionaryIndex.keys {
            dictionaryIndex[key]?.sort { first, second in
                if first.weight == second.weight {
                    return first.word.count < second.word.count
                }

                return first.weight > second.weight
            }
        }
    }

    private func prefixKey(for word: String) -> String {
        let normalized = word.lowercased()

        guard normalized.count >= 2 else {
            return normalized
        }

        return String(normalized.prefix(2))
    }
    
    private func loadAutocorrections() {
        guard let url = Bundle.main.url(forResource: "autocorrections", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            autocorrections = [
                "ческит": "ческыт",
                "чоскыт": "ческыт",
                "честкыт": "ческыт",
                "удмуртес": "удмуртъёс",
                "овол": "ӧвӧл",
                "оз": "ӧз",
                "ой": "ӧй",
                "зеч": "ӟеч",
                "жыт": "ӝыт",
                "ивол": "ӥвӧл"
            ]
            return
        }

        var loadedAutocorrections: [String: String] = [:]

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                continue
            }

            guard !trimmed.hasPrefix("#") else {
                continue
            }

            let parts = trimmed
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard parts.count >= 2 else {
                continue
            }

            let typo = parts[0].lowercased()
            let correction = parts[1]

            loadedAutocorrections[typo] = correction
        }

        autocorrections = loadedAutocorrections
    }
    
    private func loadUserWordWeights() {
        let stored = SharedSettings.defaults.dictionary(forKey: SharedSettings.userWordWeightsKey) ?? [:]

        userWordWeights = stored.reduce(into: [String: Int]()) { result, item in
            guard let value = item.value as? Int else {
                return
            }

            result[item.key] = value
        }

        let existingWords = Set(dictionary.map { $0.word.lowercased() })

        for word in userWordWeights.keys {
            guard !existingWords.contains(word) else {
                continue
            }

            dictionary.append(
                DictionaryEntry(
                    word: word,
                    weight: 60_000 + (userWordWeights[word] ?? 0)
                )
            )
        }
    }

    private func saveUserWordWeights() {
        let limitedPairs = userWordWeights
            .sorted { first, second in
                first.value > second.value
            }
            .prefix(maxUserWords)

        let limitedDictionary = Dictionary(
            uniqueKeysWithValues: limitedPairs.map { key, value in
                (key, value)
            }
        )

        userWordWeights = limitedDictionary
        SharedSettings.defaults.set(limitedDictionary, forKey: SharedSettings.userWordWeightsKey)
    }
    
    private func resetUserDictionary() {
        userWordWeights.removeAll()
        SharedSettings.defaults.removeObject(forKey: SharedSettings.userWordWeightsKey)

        dictionary.removeAll()
        dictionaryIndex.removeAll()

        loadDictionary()
        buildDictionaryIndex()
        updateSuggestions()
    }
    
    private func consumePendingPersonalDictionaryResetIfNeeded() {
        guard SharedSettings.defaults.bool(forKey: SharedSettings.resetPersonalDictionaryRequestedKey) else {
            return
        }

        SharedSettings.defaults.set(false, forKey: SharedSettings.resetPersonalDictionaryRequestedKey)
        resetUserDictionary()
    }
    
    private func loadPriorityWords() {
        let fallbackPriorityWords: Set<String> = [
            "мон",
            "тон",
            "со",
            "ми",
            "ти",
            "та",
            "ты",
            "мар",
            "кин",
            "кытын",
            "кыӵе",
            "малы",
            "ческыт",
            "ӵош",
            "ӵук",
            "ӧвӧл",
            "ӧй",
            "ӧз",
            "ӟеч",
            "ӝыт",
            "удмурт",
            "удмуртъёс",
            "кыл",
            "тыл"
        ]

        guard let url = Bundle.main.url(forResource: "priority_words", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            priorityWords = fallbackPriorityWords
            return
        }

        let loadedWords = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .filter { !$0.hasPrefix("#") }

        if loadedWords.isEmpty {
            priorityWords = fallbackPriorityWords
        } else {
            priorityWords = Set(loadedWords)
        }
    }
    
    private func makeSpaceButton() -> UIButton {
        let button = KeyboardButton(type: .custom)

        button.isExclusiveTouch = false
        button.isMultipleTouchEnabled = true

        button.backgroundColor = characterKeyBackgroundColor()
        button.layer.cornerRadius = keyCornerRadius
        button.clipsToBounds = true
        button.heightAnchor.constraint(equalToConstant: keyHeight).isActive = true

        button.addTarget(self, action: #selector(keyTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        button.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)

        let languageLabel = UILabel()
        languageLabel.text = "УДМ"
        languageLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        languageLabel.textColor = secondaryKeyTextColor()
        languageLabel.textAlignment = .right
        languageLabel.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(languageLabel)

        NSLayoutConstraint.activate([
            languageLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -10),
            languageLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -5)
        ])

        spaceLanguageLabel = languageLabel

        return button
    }

    private func buildKeyboard() {
        hideKeyPreview()

        letterKeyButtons.removeAll()
        shiftKeyButton = nil

        view.backgroundColor = keyboardBackgroundColor()
        view.isMultipleTouchEnabled = true

        rootStack?.removeFromSuperview()

        rootStack = UIStackView()
        rootStack.axis = .vertical
        rootStack.spacing = rowSpacing
        rootStack.alignment = .fill
        rootStack.distribution = .fill
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.isMultipleTouchEnabled = true

        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])

        rootStack.addArrangedSubview(makeSuggestionsRow())

        switch mode {
        case .letters:
            buildLetterKeyboard()
        case .numbers:
            buildNumberKeyboard()
        case .symbols:
            buildSymbolKeyboard()
        }
    }

    private func buildLetterKeyboard() {
        rootStack.addArrangedSubview(makeCharacterRow(letterRowsLower[0], horizontalInset: 0))
        rootStack.addArrangedSubview(makeCharacterRow(letterRowsLower[1], horizontalInset: 16))

        let thirdRowContainer = UIView()

        let thirdRow = UIStackView()
        thirdRow.axis = .horizontal
        thirdRow.spacing = keySpacing
        thirdRow.distribution = .fillEqually
        thirdRow.translatesAutoresizingMaskIntoConstraints = false

        thirdRowContainer.addSubview(thirdRow)

        NSLayoutConstraint.activate([
            thirdRow.leadingAnchor.constraint(equalTo: thirdRowContainer.leadingAnchor),
            thirdRow.trailingAnchor.constraint(equalTo: thirdRowContainer.trailingAnchor),
            thirdRow.topAnchor.constraint(equalTo: thirdRowContainer.topAnchor),
            thirdRow.bottomAnchor.constraint(equalTo: thirdRowContainer.bottomAnchor)
        ])

        let shiftButton = makeControlButton(title: shiftTitle(), width: 0)
        shiftButton.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
        shiftKeyButton = shiftButton
        updateShiftKeyAppearance()
        
        thirdRow.addArrangedSubview(shiftButton)

        for rawLetter in letterRowsLower[2] {
            let letter = displayLetter(rawLetter)
            let button = makeLetterButton(title: letter)
            configureCharacterButton(button, text: letter)
            thirdRow.addArrangedSubview(button)
        }

        let backspaceButton = makeControlButton(title: "⌫", width: 0)
        backspaceButton.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)

        let backspaceLongPress = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:)))
        backspaceLongPress.minimumPressDuration = 0.35
        backspaceButton.addGestureRecognizer(backspaceLongPress)

        thirdRow.addArrangedSubview(backspaceButton)

        rootStack.addArrangedSubview(thirdRowContainer)
        rootStack.addArrangedSubview(makeBottomRow())
    }

    private func buildNumberKeyboard() {
        rootStack.addArrangedSubview(makeCharacterRow(numberRows[0], horizontalInset: 0))
        rootStack.addArrangedSubview(makeCharacterRow(numberRows[1], horizontalInset: 0))

        let thirdRow = UIStackView()
        thirdRow.axis = .horizontal
        thirdRow.spacing = keySpacing
        thirdRow.distribution = .fillEqually

        let symbolsButton = makeControlButton(title: "#+=", width: 0)
        symbolsButton.addTarget(self, action: #selector(symbolModeTapped), for: .touchUpInside)
        thirdRow.addArrangedSubview(symbolsButton)

        for symbol in numberRows[2] {
            let button = makeLetterButton(title: symbol)
            configureCharacterButton(button, text: symbol)
            thirdRow.addArrangedSubview(button)
        }

        let backspaceButton = makeControlButton(title: "⌫", width: 0)
        backspaceButton.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)

        let backspaceLongPress = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:)))
        backspaceLongPress.minimumPressDuration = 0.35
        backspaceLongPress.cancelsTouchesInView = true
        backspaceButton.addGestureRecognizer(backspaceLongPress)

        thirdRow.addArrangedSubview(backspaceButton)

        rootStack.addArrangedSubview(thirdRow)
        rootStack.addArrangedSubview(makeBottomRow())
    }
    
    private func buildSymbolKeyboard() {
        rootStack.addArrangedSubview(makeCharacterRow(symbolRows[0], horizontalInset: 0))
        rootStack.addArrangedSubview(makeCharacterRow(symbolRows[1], horizontalInset: 0))

        let thirdRow = UIStackView()
        thirdRow.axis = .horizontal
        thirdRow.spacing = keySpacing
        thirdRow.distribution = .fillEqually

        let numbersButton = makeControlButton(title: "123", width: 0)
        numbersButton.addTarget(self, action: #selector(numberModeTapped), for: .touchUpInside)
        thirdRow.addArrangedSubview(numbersButton)

        for symbol in symbolRows[2] {
            let button = makeLetterButton(title: symbol)
            configureCharacterButton(button, text: symbol)
            thirdRow.addArrangedSubview(button)
        }

        let backspaceButton = makeControlButton(title: "⌫", width: 0)
        backspaceButton.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)

        let backspaceLongPress = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:)))
        backspaceLongPress.minimumPressDuration = 0.35
        backspaceLongPress.cancelsTouchesInView = true
        backspaceButton.addGestureRecognizer(backspaceLongPress)

        thirdRow.addArrangedSubview(backspaceButton)

        rootStack.addArrangedSubview(thirdRow)
        rootStack.addArrangedSubview(makeBottomRow())
    }
    
    private func makeSuggestionsRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 0
        row.distribution = .fill
        row.alignment = .fill
        row.backgroundColor = keyboardBackgroundColor()

        row.heightAnchor.constraint(equalToConstant: suggestionsRowHeight).isActive = true

        suggestionsRow = row
        return row
    }

    private func updateSuggestions() {
        consumePendingPersonalDictionaryResetIfNeeded()

        guard let suggestionsRow else {
            return
        }

        suggestionsRow.arrangedSubviews.forEach { view in
            suggestionsRow.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let suggestions: [String]

        if mode == .letters {
            suggestions = currentSuggestions()
        } else {
            suggestions = []
        }

        var suggestionButtons: [UIButton] = []

        for index in 0..<3 {
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = suggestionSeparatorColor()
                separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
                suggestionsRow.addArrangedSubview(separator)
            }

            let button = UIButton(type: .system)
            let title = index < suggestions.count ? suggestions[index] : ""

            button.setTitle(title, for: .normal)
            button.setTitleColor(keyTextColor(), for: .normal)
            button.setTitleColor(keyTextColor().withAlphaComponent(0.45), for: .highlighted)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.75
            button.backgroundColor = .clear
            button.isEnabled = !title.isEmpty

            button.addTarget(
                self,
                action: #selector(suggestionTapped(_:)),
                for: .touchUpInside
            )

            suggestionsRow.addArrangedSubview(button)
            suggestionButtons.append(button)
        }

        if let firstButton = suggestionButtons.first {
            for button in suggestionButtons.dropFirst() {
                button.widthAnchor.constraint(equalTo: firstButton.widthAnchor).isActive = true
            }
        }
    }
    
    private func isReasonableSuggestion(_ word: String, for prefix: String) -> Bool {
        if priorityWords.contains(word) {
            return true
        }

        if prefix.count <= 2 && word.count > 12 {
            return false
        }

        if prefix.count <= 3 && word.count > 16 {
            return false
        }

        return true
    }
    
    private func suggestionScore(for entry: DictionaryEntry, prefix: String) -> Int {
        var score = entry.weight
        let word = entry.word.lowercased()
       
        if personalDictionaryEnabled,
           let userWeight = userWordWeights[word] {
            score += 200_000 + userWeight
        }

        if priorityWords.contains(word) {
            score += 100_000
        }

        if containsUdmurtSpecificLetter(word) {
            score += 10_000
        }

        let extraLength = word.count - prefix.count

        if extraLength <= 3 {
            score += 5_000
        } else if extraLength <= 6 {
            score += 2_000
        } else if extraLength >= 12 {
            score -= 5_000
        }

        if word.contains("-") {
            score -= 1_000
        }

        return score
    }

    private func containsUdmurtSpecificLetter(_ word: String) -> Bool {
        word.contains("ӝ") ||
        word.contains("ӟ") ||
        word.contains("ӥ") ||
        word.contains("ӧ") ||
        word.contains("ӵ") ||
        word.contains("Ӝ") ||
        word.contains("Ӟ") ||
        word.contains("Ӥ") ||
        word.contains("Ӧ") ||
        word.contains("Ӵ")
    }
    
    private func looksTechnical(_ word: String) -> Bool {
        let technicalEndings = [
            "ировать",
            "изировать",
            "изация",
            "ической",
            "тической",
            "ческой",
            "тельной",
            "ательной",
            "ительной",
            "альной",
            "овой",
            "евой",
            "ной"
        ]

        return technicalEndings.contains { ending in
            word.hasSuffix(ending)
        }
    }

    private func currentSuggestions() -> [String] {
        guard suggestionsEnabled else {
            return []
        }
        
        let prefix = currentWordBeforeCursor().lowercased()

        guard prefix.count >= 2 else {
            return []
        }

        let key = prefixKey(for: prefix)
        let candidates = dictionaryIndex[key] ?? []

        return candidates
            .filter { entry in
                let word = entry.word.lowercased()

                return word.hasPrefix(prefix)
                    && word != prefix
                    && isReasonableSuggestion(word, for: prefix)
            }
            .sorted { first, second in
                let firstScore = suggestionScore(for: first, prefix: prefix)
                let secondScore = suggestionScore(for: second, prefix: prefix)

                if firstScore == secondScore {
                    return first.word.count < second.word.count
                }

                return firstScore > secondScore
            }
            .prefix(3)
            .map { $0.word }
    }

    private func currentWordBeforeCursor() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput,
              !context.isEmpty
        else {
            return ""
        }

        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)

        let parts = context.components(separatedBy: separators)
        return parts.last ?? ""
    }
    
    private func applyAutocorrectionIfNeeded() {
        guard autocorrectionEnabled else {
            return
        }
        
        let currentWord = currentWordBeforeCursor()

        guard !currentWord.isEmpty else {
            return
        }

        let lookupKey = currentWord.lowercased()

        guard let correction = autocorrections[lookupKey] else {
            return
        }

        let finalCorrection = preserveCapitalization(
            original: currentWord,
            correction: correction
        )

        replaceCurrentWord(with: finalCorrection)
    }
    
    private func handleSpecialCommandIfNeeded() -> Bool {
        guard let context = textDocumentProxy.documentContextBeforeInput else {
            return false
        }

        let command = "##сброс"

        guard context.lowercased().hasSuffix(command) else {
            return false
        }

        deleteCharacters(count: command.count)
        resetUserDictionary()

        return true
    }

    private func replaceCurrentWord(with replacement: String) {
        let currentWord = currentWordBeforeCursor()

        guard !currentWord.isEmpty else {
            textDocumentProxy.insertText(replacement)
            return
        }

        for _ in currentWord {
            textDocumentProxy.deleteBackward()
        }

        textDocumentProxy.insertText(replacement)
    }
    
    private func deleteCharacters(count: Int) {
        guard count > 0 else {
            return
        }

        for _ in 0..<count {
            textDocumentProxy.deleteBackward()
        }
    }

    private func preserveCapitalization(original: String, correction: String) -> String {
        guard let firstCharacter = original.first else {
            return correction
        }

        let firstLetter = String(firstCharacter)

        if firstLetter == firstLetter.uppercased() && firstLetter != firstLetter.lowercased() {
            return correction.prefix(1).uppercased() + correction.dropFirst()
        }

        return correction
    }

    private func applySuggestion(_ suggestion: String) {
        replaceCurrentWord(with: suggestion)
        rememberWord(suggestion, boost: 500)
        updateSuggestions()
    }
    
    private func rememberWord(_ rawWord: String, boost: Int) {
        guard personalDictionaryEnabled else {
            return
        }
        
        guard let word = normalizedWordForLearning(rawWord) else {
            return
        }

        userWordWeights[word, default: 0] += boost
        saveUserWordWeights()

        let alreadyInDictionary = dictionary.contains { entry in
            entry.word.lowercased() == word
        }

        if !alreadyInDictionary {
            dictionary.append(
                DictionaryEntry(
                    word: word,
                    weight: 60_000 + userWordWeights[word, default: 0]
                )
            )

            buildDictionaryIndex()
        }
    }

    private func normalizedWordForLearning(_ rawWord: String) -> String? {
        let word = rawWord
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard word.count >= 3 && word.count <= 30 else {
            return nil
        }

        guard word.allSatisfy({ character in
            isCyrillicOrUdmurtLetter(character) || character == "-"
        }) else {
            return nil
        }

        // Не запоминаем слишком технические/русские формы автоматически.
        if looksTechnical(word) {
            return nil
        }

        return word
    }

    private func isCyrillicOrUdmurtLetter(_ character: Character) -> Bool {
        for scalar in String(character).unicodeScalars {
            if (0x0400...0x04FF).contains(Int(scalar.value)) {
                return true
            }
        }

        return false
    }

    private func makeCharacterRow(_ characters: [String], horizontalInset: CGFloat) -> UIView {
        let container = UIView()

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = keySpacing
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalInset),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset),
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        for raw in characters {
            let text = mode == .letters ? displayLetter(raw) : raw
            let button = makeLetterButton(title: text)
            configureCharacterButton(button, text: text)
            row.addArrangedSubview(button)
        }

        return container
    }

    private func makeBottomRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = keySpacing
        row.distribution = .fill
        row.alignment = .fill

        let modeButtonTitle = mode == .letters ? "123" : "АБВ"
        let modeButton = makeControlButton(title: modeButtonTitle, width: 54)
        modeButton.addTarget(self, action: #selector(switchModeTapped), for: .touchUpInside)
        row.addArrangedSubview(modeButton)

        if needsInputModeSwitchKey {
            let nextButton = makeControlButton(title: "🌐", width: 44)
            nextButton.addTarget(
                self,
                action: #selector(handleInputModeList(from:with:)),
                for: .allTouchEvents
            )
            row.addArrangedSubview(nextButton)
        }

        let spaceButton = makeSpaceButton()
        row.addArrangedSubview(spaceButton)
        spaceButton.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        row.addArrangedSubview(spaceButton)

        let returnButton = makeControlButton(title: returnKeyTitle(), width: 76)
        returnButton.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        row.addArrangedSubview(returnButton)

        return row
    }
    
    private func makeLetterButton(title: String) -> UIButton {
        makeKeyButton(
            title: title,
            backgroundColor: characterKeyBackgroundColor(),
            fontSize: fontSizeForCharacterKey(title),
            weight: .regular
        )
    }
    
    private func fontSizeForCharacterKey(_ title: String) -> CGFloat {
        guard title.count == 1 else {
            return 21
        }

        guard let character = title.first else {
            return 22
        }

        if isCyrillicOrUdmurtLetter(character) {
            if title == title.lowercased() {
                return 25
            } else {
                return 23
            }
        }

        if character.isNumber {
            return 23
        }

        return 22
    }

    private func makeControlButton(title: String, width: CGFloat) -> UIButton {
        let button = makeKeyButton(
            title: title,
            backgroundColor: controlKeyBackgroundColor(),
            fontSize: 17,
            weight: .regular
        )

        if width > 0 {
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
        }

        return button
    }

    private func makeKeyButton(
        title: String,
        backgroundColor: UIColor,
        fontSize: CGFloat,
        weight: UIFont.Weight
    ) -> UIButton {
        let button = KeyboardButton(type: .custom)
        
        button.isExclusiveTouch = false
        button.isMultipleTouchEnabled = true

        button.setTitle(title, for: .normal)
        button.setTitleColor(keyTextColor(), for: .normal)
        button.setTitleColor(keyTextColor().withAlphaComponent(0.45), for: .highlighted)

        button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.baselineAdjustment = .alignCenters
        button.titleLabel?.adjustsFontSizeToFitWidth = false

        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.titleEdgeInsets = UIEdgeInsets(top: -1, left: 0, bottom: 1, right: 0)

        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = keyCornerRadius
        button.clipsToBounds = true

        button.heightAnchor.constraint(equalToConstant: keyHeight).isActive = true

        button.addTarget(self, action: #selector(keyTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(keyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        return button
    }
    
    @objc private func keyTouchDown(_ sender: UIButton) {
        sender.layer.removeAllAnimations()
        showKeyPreview(for: sender)

        UIView.animate(
            withDuration: 0.025,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            sender.transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
        }
    }

    @objc private func keyTouchUp(_ sender: UIButton) {
        sender.layer.removeAllAnimations()
        hideKeyPreview()

        UIView.animate(
            withDuration: 0.045,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            sender.transform = .identity
            sender.alpha = 1
        }
    }
    
    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let suggestion = sender.title(for: .normal),
              !suggestion.isEmpty
        else {
            return
        }

        UIDevice.current.playInputClick()

        let textToInsert = adjustedSuggestionForInsertion(suggestion)

        replaceCurrentWord(with: textToInsert)
        rememberWord(suggestion, boost: 40)

        textDocumentProxy.insertText(" ")
        lastSpaceTapDate = nil

        if mode == .letters && !isCapsLockOn {
            isShiftOn = shouldAutoCapitalize()
            updateLetterKeysForShiftState()
        }

        updateSuggestions()
    }

    private func adjustedSuggestionForInsertion(_ suggestion: String) -> String {
        let currentWord = currentWordBeforeCursor()

        guard !currentWord.isEmpty else {
            if shouldAutoCapitalize() {
                return capitalizedFirstLetter(suggestion)
            }

            return suggestion
        }

        if currentWord == currentWord.uppercased() {
            return suggestion.uppercased()
        }

        guard let firstCharacter = currentWord.first else {
            return suggestion
        }

        let firstLetter = String(firstCharacter)

        if firstLetter == firstLetter.uppercased(),
           firstLetter != firstLetter.lowercased() {
            return capitalizedFirstLetter(suggestion)
        }

        return suggestion
    }

    private func capitalizedFirstLetter(_ word: String) -> String {
        guard let firstCharacter = word.first else {
            return word
        }

        let first = String(firstCharacter).uppercased()
        let rest = String(word.dropFirst())

        return first + rest
    }
    
    private func configurePopupPreviewIfNeeded(for button: UIButton, text: String) {
        guard let keyboardButton = button as? KeyboardButton else {
            return
        }

        keyboardButton.popupPreviewText = text
        keyboardButton.showsPopupPreview = shouldShowPopupPreview(for: text)
    }

    private func shouldShowPopupPreview(for text: String) -> Bool {
        guard text.count == 1 else {
            return false
        }

        let functionalKeys: Set<String> = [
            "⌫",
            "⇧",
            "123",
            "АБВ",
            "#+=",
            "Пробел",
            " ",
            "ввод",
            "поиск",
            "🌐"
        ]

        if functionalKeys.contains(text) {
            return false
        }

        return true
    }

    private func showKeyPreview(for button: UIButton) {
        guard let keyboardButton = button as? KeyboardButton,
              keyboardButton.showsPopupPreview,
              let text = keyboardButton.popupPreviewText,
              !text.isEmpty
        else {
            return
        }

        hideKeyPreview()

        let keyFrame = button.convert(button.bounds, to: view)

        let popupWidth = max(keyFrame.width + 22, 48)
        let popupHeight: CGFloat = 62

        var popupX = keyFrame.midX - popupWidth / 2
        let minX: CGFloat = 4
        let maxX = view.bounds.width - popupWidth - 4
        popupX = max(minX, min(popupX, maxX))

        var popupY = keyFrame.minY - popupHeight + 4

        // Если сверху мало места, показываем поверх строки подсказок, но не выходим за экран клавиатуры.
        if popupY < 2 {
            popupY = 2
        }

        let popup = UIView(
            frame: CGRect(
                x: popupX,
                y: popupY,
                width: popupWidth,
                height: popupHeight
            )
        )

        popup.isUserInteractionEnabled = false
        popup.alpha = 0
        popup.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)

        let bubbleHeight = popupHeight - 10

        let bubble = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: popupWidth,
                height: bubbleHeight
            )
        )

        bubble.backgroundColor = keyPreviewBackgroundColor()
        bubble.layer.cornerRadius = 12
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.25 : 0.18
        bubble.layer.shadowRadius = 4
        bubble.layer.shadowOffset = CGSize(width: 0, height: 2)

        let label = UILabel(frame: bubble.bounds)
        label.text = text
        label.textAlignment = .center
        label.textColor = keyTextColor()
        label.font = UIFont.systemFont(ofSize: 34, weight: .regular)

        bubble.addSubview(label)
        popup.addSubview(bubble)

        let tailSize: CGFloat = 16
        let tail = UIView(
            frame: CGRect(
                x: (popupWidth - tailSize) / 2,
                y: bubbleHeight - 4,
                width: tailSize,
                height: tailSize
            )
        )

        tail.backgroundColor = keyPreviewBackgroundColor()
        tail.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 4)
        popup.addSubview(tail)
        popup.sendSubviewToBack(tail)

        view.addSubview(popup)
        keyPreviewView = popup

        UIView.animate(
            withDuration: 0.055,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            popup.alpha = 1
            popup.transform = .identity
        }
    }

    private func hideKeyPreview() {
        guard let popup = keyPreviewView else {
            return
        }

        keyPreviewView = nil

        UIView.animate(
            withDuration: 0.045,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            popup.alpha = 0
            popup.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            popup.removeFromSuperview()
        }
    }
    
    private func configureCharacterButton(_ button: UIButton, text: String) {
        if let keyboardButton = button as? KeyboardButton {
            keyboardButton.inputText = text
            keyboardButton.longPressText = longPressAlternative(for: text)

            if text.count == 1,
               let character = text.first,
               isCyrillicOrUdmurtLetter(character) {
                keyboardButton.baseLowerText = text.lowercased()
                letterKeyButtons.append(keyboardButton)
            }

            let longPress = UILongPressGestureRecognizer(
                target: self,
                action: #selector(characterLongPressed(_:))
            )
            longPress.minimumPressDuration = 0.35
            longPress.cancelsTouchesInView = true
            keyboardButton.addGestureRecognizer(longPress)
        }

        configurePopupPreviewIfNeeded(for: button, text: text)

        button.addTarget(
            self,
            action: #selector(characterButtonTapped(_:)),
            for: .touchUpInside
        )
    }

    @objc private func characterButtonTapped(_ sender: UIButton) {
        guard let keyboardButton = sender as? KeyboardButton,
              let text = keyboardButton.inputText
        else {
            return
        }

        insertCharacter(text)
    }
    
    private func displayLetter(_ lower: String) -> String {
        if isShiftOn || isCapsLockOn {
            return lower.uppercased()
        }
        return lower
    }
    
    private func shouldAutoCapitalize() -> Bool {
        guard let context = textDocumentProxy.documentContextBeforeInput else {
            return true
        }

        if context.isEmpty {
            return true
        }

        // Идем назад по тексту перед курсором.
        // Пробелы пропускаем, но перенос строки считаем началом нового предложения.
        for character in context.reversed() {
            if character == "\n" || character == "\r" {
                return true
            }

            if character == " " || character == "\t" {
                continue
            }

            return character == "."
                || character == "!"
                || character == "?"
                || character == "…"
        }

        return true
    }

    private func updateAutoCapitalizationState() {
        guard mode == .letters else {
            return
        }

        guard !isCapsLockOn else {
            return
        }

        let shouldShift = shouldAutoCapitalize()

        if isShiftOn != shouldShift {
            isShiftOn = shouldShift
            updateLetterKeysForShiftState()
        }
    }

    private func isLetterText(_ text: String) -> Bool {
        guard text.count == 1 else {
            return false
        }

        return text.allSatisfy { character in
            isCyrillicOrUdmurtLetter(character)
        }
    }

    private func insertCharacter(_ text: String) {
        UIDevice.current.playInputClick()
        lastSpaceTapDate = nil

        textDocumentProxy.insertText(text)

        if isShiftOn && !isCapsLockOn && isLetterText(text) {
            isShiftOn = false
            updateLetterKeysForShiftState()
        }

        updateSuggestions()

        if text == "." || text == "!" || text == "?" || text == "…" {
            updateAutoCapitalizationState()
        }
    }

    private func longPressAlternative(for text: String) -> String? {
        if let lower = longPressMapLower[text] {
            return lower
        }

        if let upper = longPressMapUpper[text] {
            return upper
        }

        return nil
    }

    private func shiftTitle() -> String {
        if isCapsLockOn {
            return "⇪"
        }

        if isShiftOn {
            return "⇧"
        }

        return "⇧"
    }

    private func returnKeyTitle() -> String {
        switch textDocumentProxy.returnKeyType {
        case .search:
            return "поиск"
        case .go:
            return "перейти"
        case .done:
            return "готово"
        case .send:
            return "отпр."
        case .next:
            return "далее"
        default:
            return "Ввод"
        }
    }

    private func updateReturnKeyTitle() {
        guard let returnButton = view.viewWithTag(777) as? UIButton else { return }
        returnButton.setTitle(returnKeyTitle(), for: .normal)
    }

    @objc private func shiftTapped() {
        let now = Date()

        if let last = lastShiftTapDate, now.timeIntervalSince(last) < 0.35 {
            isCapsLockOn.toggle()
            isShiftOn = false
        } else {
            if isCapsLockOn {
                isCapsLockOn = false
                isShiftOn = false
            } else {
                isShiftOn.toggle()
            }
        }

        lastShiftTapDate = now
        updateLetterKeysForShiftState()
    }
    
    private func updateLetterKeysForShiftState() {
        guard mode == .letters else {
            return
        }

        for button in letterKeyButtons {
            guard let lowerText = button.baseLowerText else {
                continue
            }

            let updatedText = displayLetter(lowerText)

            button.inputText = updatedText
            button.popupPreviewText = updatedText
            button.setTitle(updatedText, for: .normal)
            button.longPressText = longPressAlternative(for: updatedText)
            button.titleLabel?.font = UIFont.systemFont(
                ofSize: fontSizeForCharacterKey(updatedText),
                weight: .regular
            )

            configurePopupPreviewIfNeeded(for: button, text: updatedText)
        }

        updateShiftKeyAppearance()
    }

    private func updateShiftKeyAppearance() {
        guard let shiftKeyButton else {
            return
        }

        shiftKeyButton.setTitleColor(keyTextColor(), for: .normal)

        if isCapsLockOn {
            shiftKeyButton.backgroundColor = characterKeyBackgroundColor()
            shiftKeyButton.setTitle("⇪", for: .normal)
        } else if isShiftOn {
            shiftKeyButton.backgroundColor = characterKeyBackgroundColor()
            shiftKeyButton.setTitle("⇧", for: .normal)
        } else {
            shiftKeyButton.backgroundColor = controlKeyBackgroundColor()
            shiftKeyButton.setTitle("⇧", for: .normal)
        }
    }

    @objc private func switchModeTapped() {
        UIDevice.current.playInputClick()

        if mode == .letters {
            mode = .numbers
        } else {
            mode = .letters
        }

        buildKeyboard()
    }
    
    @objc private func symbolModeTapped() {
        UIDevice.current.playInputClick()
        mode = .symbols
        buildKeyboard()
    }

    @objc private func numberModeTapped() {
        UIDevice.current.playInputClick()
        mode = .numbers
        buildKeyboard()
    }
    
    private func shouldApplyDoubleSpacePeriod() -> Bool {
        guard let lastSpaceTapDate else {
            return false
        }

        guard Date().timeIntervalSince(lastSpaceTapDate) <= doubleSpaceThreshold else {
            return false
        }

        guard let context = textDocumentProxy.documentContextBeforeInput,
              context.hasSuffix(" ")
        else {
            return false
        }

        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let lastCharacter = trimmedContext.last else {
            return false
        }

        return lastCharacter != "."
            && lastCharacter != "!"
            && lastCharacter != "?"
            && lastCharacter != "…"
    }

    private func applyDoubleSpacePeriod() {
        textDocumentProxy.deleteBackward()
        textDocumentProxy.insertText(". ")
        lastSpaceTapDate = nil
        updateSuggestions()
        updateAutoCapitalizationState()
    }

    @objc private func spaceTapped() {
        UIDevice.current.playInputClick()

        if shouldApplyDoubleSpacePeriod() {
            applyDoubleSpacePeriod()
            return
        }
        
        if handleSpecialCommandIfNeeded() {
            textDocumentProxy.insertText(" ")
            lastSpaceTapDate = Date()
            updateSuggestions()
            updateAutoCapitalizationState()
            return
        }

        let wordBeforeCorrection = currentWordBeforeCursor()

        applyAutocorrectionIfNeeded()

        let wordAfterCorrection = currentWordBeforeCursor()

        if !wordAfterCorrection.isEmpty {
            rememberWord(wordAfterCorrection, boost: 20)
        } else {
            rememberWord(wordBeforeCorrection, boost: 20)
        }

        textDocumentProxy.insertText(" ")
        lastSpaceTapDate = Date()

        updateSuggestions()
        updateAutoCapitalizationState()
    }

    @objc private func backspaceTapped() {
        deleteBackwardOnce()
    }

    @objc private func returnTapped() {
        UIDevice.current.playInputClick()
        lastSpaceTapDate = nil
        textDocumentProxy.insertText("\n")
        updateSuggestions()

        if mode == .letters && !isCapsLockOn {
            isShiftOn = true
            updateLetterKeysForShiftState()
        }
    }

    @objc private func characterLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard let sourceButton = gesture.view as? UIButton,
              let text = sourceButton.title(for: .normal),
              let alternative = longPressAlternative(for: text)
        else {
            return
        }

        switch gesture.state {
        case .began:
            showPopupButton(title: alternative, above: sourceButton)
        case .ended:
            hidePopupButton()
            insertCharacter(alternative)
        case .cancelled, .failed:
            hidePopupButton()
        default:
            break
        }
    }

    private func showPopupButton(title: String, above sourceButton: UIButton) {
        hidePopupButton()

        let popup = UIButton(type: .system)
        popup.setTitle(title, for: .normal)
        popup.titleLabel?.font = UIFont.systemFont(ofSize: 25, weight: .regular)
        popup.backgroundColor = .systemBackground
        popup.setTitleColor(.label, for: .normal)
        popup.layer.cornerRadius = 8
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.25
        popup.layer.shadowOffset = CGSize(width: 0, height: 2)
        popup.layer.shadowRadius = 3
        popup.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(popup)

        let sourceFrame = sourceButton.convert(sourceButton.bounds, to: view)

        NSLayoutConstraint.activate([
            popup.widthAnchor.constraint(equalToConstant: 48),
            popup.heightAnchor.constraint(equalToConstant: 54),
            popup.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: sourceFrame.midX),
            popup.bottomAnchor.constraint(equalTo: view.topAnchor, constant: max(sourceFrame.minY - 6, 54))
        ])

        popupButton = popup
    }

    private func hidePopupButton() {
        popupButton?.removeFromSuperview()
        popupButton = nil
    }

    @objc private func backspaceLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            startBackspaceRepeat()

        case .ended, .cancelled, .failed:
            stopBackspaceRepeat()

        default:
            break
        }
    }
    
    private func deleteBackwardOnce() {
        UIDevice.current.playInputClick()
        lastSpaceTapDate = nil
        textDocumentProxy.deleteBackward()
        updateSuggestions()
        updateAutoCapitalizationState()
    }

    private func startBackspaceRepeat() {
        stopBackspaceRepeat()
        deleteBackwardOnce()

        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.deleteBackwardOnce()
        }

        RunLoop.main.add(timer, forMode: .common)
        backspaceTimer = timer
    }

    private func stopBackspaceRepeat() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
    }
}

private final class KeyboardButton: UIButton {
    var hitTestEdgeInsets = UIEdgeInsets(top: -6, left: -4, bottom: -6, right: -4)

    var showsPopupPreview = false
    var popupPreviewText: String?

    var inputText: String?
    var baseLowerText: String?
    
    var longPressText: String?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let largerBounds = bounds.inset(by: hitTestEdgeInsets)
        return largerBounds.contains(point)
    }
}
