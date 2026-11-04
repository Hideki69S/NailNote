import Foundation

enum NailProductCategory: String, CaseIterable, Identifiable, Hashable {
    case color
    case base
    case top
    case deco
    case art
    case parts
    case sticker
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
        case .parts:  return "パーツ"
        case .sticker:return "シール"
        case .care:   return "ケア"
        case .remove: return "リムーブ"
        case .tool:   return "ツール"
        case .stock:  return "ストック"
        case .other:  return "その他"
        }
    }
}

/// 一覧専用の分類。商品の保存カテゴリとは分け、旧保存値も検索対象に残す。
enum NailProductCategoryFilter: String, CaseIterable, Identifiable, Hashable {
    case all, color, baseTop, art, parts, sticker, careRemove, toolsOther

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "すべて"
        case .color: return "カラー"
        case .baseTop: return "ベース系"
        case .art: return "アート"
        case .parts: return "パーツ"
        case .sticker: return "シール"
        case .careRemove: return "ケア系"
        case .toolsOther: return "ツール系"
        }
    }

    var buttonTitle: String {
        title
    }

    func matches(_ category: NailProductCategory) -> Bool {
        switch self {
        case .all: return true
        case .color: return category == .color
        case .baseTop: return category == .base || category == .top
        case .art: return category == .art || category == .deco
        case .parts: return category == .parts
        case .sticker: return category == .sticker
        case .careRemove: return category == .care || category == .remove
        case .toolsOther: return category == .tool || category == .stock || category == .other
        }
    }
}

/// 一覧の生存期間だけ保持する選択状態。全解除は0件として扱う。
struct NailProductCategorySelection {
    private static let categories = Set(NailProductCategoryFilter.allCases.filter { $0 != .all })
    private(set) var selected = categories

    var allSelected: Bool { selected == Self.categories }

    func isSelected(_ filter: NailProductCategoryFilter) -> Bool {
        filter == .all ? allSelected : selected.contains(filter)
    }

    mutating func toggle(_ filter: NailProductCategoryFilter) {
        if filter == .all {
            selected = allSelected ? [] : Self.categories
        } else if selected.contains(filter) {
            selected.remove(filter)
        } else {
            selected.insert(filter)
        }
    }

    func matches(_ category: NailProductCategory) -> Bool {
        selected.contains { $0.matches(category) }
    }
}
