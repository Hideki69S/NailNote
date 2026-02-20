import Foundation

enum NailDesignCategory: String, CaseIterable, Identifiable, Hashable {
    case oneColor = "oneColor"
    case gradation = "gradation"
    case french = "french"
    case nuance = "nuance"
    case deco = "deco"
    case magnet = "magnet"
    case mirror = "mirror"
    case aurora = "aurora"
    case marble = "marble"
    case ink = "ink"
    case simple = "simple"
    case event = "event"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneColor:  return "ワンカラー"
        case .gradation: return "グラデ"
        case .french:    return "フレンチ"
        case .nuance:    return "ニュアンス"
        case .deco:      return "デコ"
        case .magnet:    return "マグネット"
        case .mirror:    return "ミラー"
        case .aurora:    return "オーロラ"
        case .marble:    return "マーブル"
        case .ink:       return "インク"
        case .simple:    return "シンプル"
        case .event:     return "イベント"
        case .other:     return "その他"
        }
    }
}
