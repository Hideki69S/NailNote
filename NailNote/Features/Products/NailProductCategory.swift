import Foundation

enum NailProductCategory: String, CaseIterable, Identifiable, Hashable {
    case color
    case top
    case base
    case care
    case tool
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .color: return "カラー"
        case .top:   return "トップ"
        case .base:  return "ベース"
        case .care:  return "ケア"
        case .tool:  return "ツール"
        case .other: return "その他"
        }
    }
}
