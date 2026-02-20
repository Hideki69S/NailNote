import Foundation

enum NailProductCategory: String, CaseIterable, Identifiable, Hashable {
    case color
    case base
    case top
    case deco
    case art
    case care
    case remove
    case tool
    case stock
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .color:  return "カラー"
        case .base:   return "ベース"
        case .top:    return "トップ"
        case .deco:   return "デコ"
        case .art:    return "アート"
        case .care:   return "ケア"
        case .remove: return "リムーブ"
        case .tool:   return "ツール"
        case .stock:  return "ストック"
        case .other:  return "その他"
        }
    }
}
