import Foundation

nonisolated enum AboutContent {
    static let developerName = "olcchi"
    static let xiaohongshuHandle = "黑色聖女果"
    static let appName = "chocho"
    static let contactEmail = "chochoapp@outlook.com"
    static let privacyPolicyURL = URL(string: "https://www.chocho.cc/privacy")!
    static let termsOfServiceURL = URL(string: "https://www.chocho.cc/terms")!
    static let supportURL = URL(string: "https://www.chocho.cc/support")!
    static let developerWebsiteURL = URL(string: "https://olcchi.me")!
    static let xiaohongshuURL = URL(string: "https://www.xiaohongshu.com/user/profile/5f0d7494000000000101d602")!
    static var contactEmailURL: URL {
        URL(string: "mailto:\(contactEmail)")!
    }
}

enum AboutLegalDocument: String, Identifiable, CaseIterable {
    case privacyPolicy
    case termsOfService

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy:
            "隐私协议"
        case .termsOfService:
            "用户服务协议"
        }
    }

    var externalURL: URL {
        switch self {
        case .privacyPolicy:
            AboutContent.privacyPolicyURL
        case .termsOfService:
            AboutContent.termsOfServiceURL
        }
    }
}
