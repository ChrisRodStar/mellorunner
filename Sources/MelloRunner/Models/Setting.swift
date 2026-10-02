import Foundation

/// Identifier representing the interactive control or display type of a setting.
public enum SettingType: String, Sendable, Codable {
    case group
    case select
    case multiselect = "multi-select"
    case toggle = "switch"
    case stepper
    case segment
    case text
    case button
    case link
    case login
    case page
    case editableList = "editable-list"
    case picker
    case custom

    public init?(_ byteValue: UInt8) {
        switch byteValue {
            case 0: self = .group
            case 1: self = .select
            case 2: self = .multiselect
            case 3: self = .toggle
            case 4: self = .stepper
            case 5: self = .segment
            case 6: self = .text
            case 7: self = .button
            case 8: self = .link
            case 9: self = .login
            case 10: self = .page
            case 11: self = .editableList
            case 12: self = .custom
            case 13: self = .picker
            default: return nil
        }
    }

    public var byteValue: UInt8 {
        switch self {
            case .group: 0
            case .select: 1
            case .multiselect: 2
            case .toggle: 3
            case .stepper: 4
            case .segment: 5
            case .text: 6
            case .button: 7
            case .link: 8
            case .login: 9
            case .page: 10
            case .editableList: 11
            case .custom: 12
            case .picker: 13
        }
    }

    public var requiresKey: Bool {
        switch self {
            case .group, .button, .link, .page: false
            default: true
        }
    }
}

/// A configurable setting item exposed by a source extension.
public struct Setting: Sendable, Hashable, Identifiable {
    public let key: String
    public var title: String
    public var notification: String?
    public var requires: String?
    public var requiresFalse: String?
    public var refreshes: [String]
    public var value: Value

    public var id: String { key.isEmpty ? title : key }

    public enum Value: Sendable, Hashable {
        case group(GroupSetting)
        case select(SelectSetting)
        case multiselect(MultiSelectSetting)
        case toggle(ToggleSetting)
        case stepper(StepperSetting)
        case segment(SegmentSetting)
        case text(TextSetting)
        case button(ButtonSetting)
        case link(LinkSetting)
        case login(LoginSetting)
        case page(PageSetting)
        case editableList(EditableListSetting)
        case picker(PickerSetting)
        case custom
    }

    public init(
        key: String = "",
        title: String = "",
        notification: String? = nil,
        requires: String? = nil,
        requiresFalse: String? = nil,
        refreshes: [String] = [],
        value: Value
    ) {
        self.key = key
        self.title = title
        self.notification = notification
        self.requires = requires
        self.requiresFalse = requiresFalse
        self.refreshes = refreshes
        self.value = value
    }

    public var type: SettingType {
        switch value {
            case .group: .group
            case .select: .select
            case .multiselect: .multiselect
            case .toggle: .toggle
            case .stepper: .stepper
            case .segment: .segment
            case .text: .text
            case .button: .button
            case .link: .link
            case .login: .login
            case .page: .page
            case .editableList: .editableList
            case .picker: .picker
            case .custom: .custom
        }
    }
}

public struct GroupSetting: Sendable, Codable, Hashable {
    public let footer: String?
    public let items: [Setting]

    public init(footer: String? = nil, items: [Setting]) {
        self.footer = footer
        self.items = items
    }
}

public struct SelectSetting: Sendable, Codable, Hashable {
    public let values: [String]
    public let titles: [String]?
    public let authToOpen: Bool?
    public let defaultValue: String?

    public init(
        values: [String],
        titles: [String]? = nil,
        authToOpen: Bool? = nil,
        defaultValue: String? = nil
    ) {
        self.values = values
        self.titles = titles
        self.authToOpen = authToOpen
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case values
        case titles
        case authToOpen
        case defaultValue = "default"
    }
}

public struct MultiSelectSetting: Sendable, Codable, Hashable {
    public let values: [String]
    public let titles: [String]?
    public let authToOpen: Bool?
    public let defaultValue: [String]?

    public init(
        values: [String],
        titles: [String]? = nil,
        authToOpen: Bool? = nil,
        defaultValue: [String]? = nil
    ) {
        self.values = values
        self.titles = titles
        self.authToOpen = authToOpen
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case values
        case titles
        case authToOpen
        case defaultValue = "default"
    }
}

public struct ToggleSetting: Sendable, Codable, Hashable {
    public let subtitle: String?
    public var authToDisable: Bool?
    public var defaultValue: Bool?

    public init(subtitle: String? = nil, authToDisable: Bool? = nil, defaultValue: Bool = false) {
        self.subtitle = subtitle
        self.authToDisable = authToDisable
        self.defaultValue = defaultValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.authToDisable = try container.decodeIfPresent(Bool.self, forKey: .authToDisable)
        self.defaultValue = (try? container.decode(Bool.self, forKey: .defaultValue)) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(authToDisable, forKey: .authToDisable)
        try container.encode(defaultValue ?? false, forKey: .defaultValue)
    }

    enum CodingKeys: String, CodingKey {
        case subtitle
        case authToDisable
        case defaultValue = "default"
    }
}

public struct StepperSetting: Sendable, Codable, Hashable {
    public let minimumValue: Double
    public let maximumValue: Double
    public let stepValue: Double?
    public var defaultValue: Double?

    public init(
        minimumValue: Double,
        maximumValue: Double,
        stepValue: Double? = nil,
        defaultValue: Double? = nil
    ) {
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.stepValue = stepValue
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case minimumValue
        case maximumValue
        case stepValue
        case defaultValue = "default"
    }
}

public struct SegmentSetting: Sendable, Codable, Hashable {
    public let options: [String]
    public var defaultValue: Int?

    public init(options: [String], defaultValue: Int? = nil) {
        self.options = options
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case options
        case defaultValue = "default"
    }
}

public struct TextSetting: Sendable, Codable, Hashable {
    public let placeholder: String?
    public let autocapitalizationType: Int?
    public let keyboardType: Int?
    public let returnKeyType: Int?
    public let autocorrectionDisabled: Bool?
    public let secure: Bool?
    public var defaultValue: String?

    public init(
        placeholder: String? = nil,
        autocapitalizationType: Int? = nil,
        keyboardType: Int? = nil,
        returnKeyType: Int? = nil,
        autocorrectionDisabled: Bool = false,
        secure: Bool = false,
        defaultValue: String? = nil
    ) {
        self.placeholder = placeholder
        self.autocapitalizationType = autocapitalizationType
        self.keyboardType = keyboardType
        self.returnKeyType = returnKeyType
        self.autocorrectionDisabled = autocorrectionDisabled
        self.secure = secure
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case placeholder
        case autocapitalizationType
        case keyboardType
        case returnKeyType
        case autocorrectionDisabled
        case secure
        case defaultValue = "default"
    }
}

public struct ButtonSetting: Sendable, Codable, Hashable {
    public let destructive: Bool?
    public let confirmTitle: String?
    public let confirmText: String?

    public init(destructive: Bool = false, confirmTitle: String? = nil, confirmText: String? = nil) {
        self.destructive = destructive
        self.confirmTitle = confirmTitle
        self.confirmText = confirmText
    }
}

public struct LinkSetting: Sendable, Codable, Hashable {
    public let url: String
    public let external: Bool?

    public init(url: String, external: Bool? = nil) {
        self.url = url
        self.external = external
    }
}

public struct LoginSetting: Sendable, Codable, Hashable {
    public let method: Method
    public let url: String?
    public let urlKey: String?
    public let logoutTitle: String?
    public let pkce: Bool?
    public let tokenUrl: String?
    public let callbackScheme: String?
    public let useEmail: Bool?
    public let localStorageKeys: [String]?
    public let clearCookiesOnLogOut: Bool?

    public enum Method: String, Sendable, Codable {
        case basic
        case oauth
        case web
    }

    public init(
        method: Method,
        url: String? = nil,
        urlKey: String? = nil,
        logoutTitle: String? = nil,
        pkce: Bool = false,
        tokenUrl: String? = nil,
        callbackScheme: String? = nil,
        useEmail: Bool? = nil,
        localStorageKeys: [String]? = nil,
        clearCookiesOnLogOut: Bool = false
    ) {
        self.method = method
        self.url = url
        self.urlKey = urlKey
        self.logoutTitle = logoutTitle
        self.pkce = pkce
        self.tokenUrl = tokenUrl
        self.callbackScheme = callbackScheme
        self.useEmail = useEmail
        self.localStorageKeys = localStorageKeys
        self.clearCookiesOnLogOut = clearCookiesOnLogOut
    }
}

public struct PageSetting: Sendable, Codable, Hashable {
    public let items: [Setting]
    public let inlineTitle: Bool?
    public let authToOpen: Bool?
    public let icon: Icon?
    public let info: String?

    public init(
        items: [Setting],
        inlineTitle: Bool = false,
        authToOpen: Bool = false,
        icon: Icon? = nil,
        info: String? = nil
    ) {
        self.items = items
        self.inlineTitle = inlineTitle
        self.authToOpen = authToOpen
        self.icon = icon
        self.info = info
    }

    public enum Icon: Codable, Sendable, Hashable {
        case system(name: String, color: String, inset: Int = 5)
        case url(String)

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
                case "system":
                    let name = try container.decode(String.self, forKey: .name)
                    let color = try container.decode(String.self, forKey: .color)
                    let inset = (try? container.decodeIfPresent(Int.self, forKey: .inset)) ?? 5
                    self = .system(name: name, color: color, inset: inset)
                case "url":
                    let url = try container.decode(String.self, forKey: .url)
                    self = .url(url)
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: .type,
                        in: container,
                        debugDescription: "Invalid icon type: \(type)"
                    )
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
                case .system(let name, let color, let inset):
                    try container.encode("system", forKey: .type)
                    try container.encode(name, forKey: .name)
                    try container.encode(color, forKey: .color)
                    try container.encodeIfPresent(inset, forKey: .inset)
                case .url(let url):
                    try container.encode("url", forKey: .type)
                    try container.encode(url, forKey: .url)
            }
        }

        enum CodingKeys: CodingKey {
            case type
            case name
            case color
            case inset
            case url
        }
    }
}

public struct EditableListSetting: Sendable, Codable, Hashable {
    public let lineLimit: Int?
    public let inline: Bool?
    public let placeholder: String?
    public let defaultValue: [String]?

    public init(
        lineLimit: Int? = nil,
        inline: Bool = false,
        placeholder: String? = nil,
        defaultValue: [String]? = nil
    ) {
        self.lineLimit = lineLimit
        self.inline = inline
        self.placeholder = placeholder
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case lineLimit
        case inline
        case placeholder
        case defaultValue = "default"
    }
}

public struct PickerSetting: Sendable, Codable, Hashable {
    public let values: [String]
    public let titles: [String]?
    public let defaultValue: String?

    public init(
        values: [String],
        titles: [String]? = nil,
        defaultValue: String? = nil
    ) {
        self.values = values
        self.titles = titles
        self.defaultValue = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case values
        case titles
        case defaultValue = "default"
    }
}

extension Setting: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try? container.decode(SettingType.self, forKey: .type)
        guard let type else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid setting type"
            )
        }
        self.key = (try? container.decode(String.self, forKey: .key)) ?? ""
        if type.requiresKey && key.isEmpty {
            throw DecodingError.dataCorruptedError(
                forKey: .key,
                in: container,
                debugDescription: "Missing required key for setting type \(type)"
            )
        }
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.notification = try container.decodeIfPresent(String.self, forKey: .notification)
        self.requires = try container.decodeIfPresent(String.self, forKey: .requires)
        self.requiresFalse = try container.decodeIfPresent(String.self, forKey: .requiresFalse)
        self.refreshes = (try? container.decodeIfPresent([String].self, forKey: .refreshes)) ?? []

        _ = try? container.decode(UInt8.self, forKey: .enumValue)

        switch type {
            case .group: self.value = .group(try GroupSetting(from: decoder))
            case .select: self.value = .select(try SelectSetting(from: decoder))
            case .multiselect: self.value = .multiselect(try MultiSelectSetting(from: decoder))
            case .toggle: self.value = .toggle(try ToggleSetting(from: decoder))
            case .stepper: self.value = .stepper(try StepperSetting(from: decoder))
            case .segment: self.value = .segment(try SegmentSetting(from: decoder))
            case .text: self.value = .text(try TextSetting(from: decoder))
            case .button: self.value = .button(try ButtonSetting(from: decoder))
            case .link: self.value = .link(try LinkSetting(from: decoder))
            case .login: self.value = .login(try LoginSetting(from: decoder))
            case .page: self.value = .page(try PageSetting(from: decoder))
            case .editableList: self.value = .editableList(try EditableListSetting(from: decoder))
            case .picker: self.value = .picker(try PickerSetting(from: decoder))
            case .custom: self.value = .custom
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        let keyToEncode: String? = key.isEmpty ? nil : key
        try container.encode(keyToEncode, forKey: .key)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(notification, forKey: .notification)
        try container.encodeIfPresent(requires, forKey: .requires)
        try container.encodeIfPresent(requiresFalse, forKey: .requiresFalse)
        try container.encodeIfPresent(refreshes, forKey: .refreshes)
        try container.encode(type.byteValue, forKey: .enumValue)

        switch value {
            case .group(let val): try val.encode(to: encoder)
            case .select(let val): try val.encode(to: encoder)
            case .multiselect(let val): try val.encode(to: encoder)
            case .toggle(let val): try val.encode(to: encoder)
            case .stepper(let val): try val.encode(to: encoder)
            case .segment(let val): try val.encode(to: encoder)
            case .text(let val): try val.encode(to: encoder)
            case .button(let val): try val.encode(to: encoder)
            case .link(let val): try val.encode(to: encoder)
            case .login(let val): try val.encode(to: encoder)
            case .page(let val): try val.encode(to: encoder)
            case .editableList(let val): try val.encode(to: encoder)
            case .picker(let val): try val.encode(to: encoder)
            case .custom: break
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case key
        case title
        case notification
        case requires
        case requiresFalse
        case refreshes
        case enumValue
    }
}
