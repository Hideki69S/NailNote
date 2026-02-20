import Foundation

enum NailColorTone: String, CaseIterable, Identifiable, Hashable {
    case pink
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case brown
    case beige
    case white
    case gray
    case black
    case clear
    case multicolor
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pink:       return "ピンク"
        case .red:        return "レッド"
        case .orange:     return "オレンジ"
        case .yellow:     return "イエロー"
        case .green:      return "グリーン"
        case .blue:       return "ブルー"
        case .purple:     return "パープル"
        case .brown:      return "ブラウン"
        case .beige:      return "ベージュ"
        case .white:      return "ホワイト"
        case .gray:       return "グレー"
        case .black:      return "ブラック"
        case .clear:      return "クリア"
        case .multicolor: return "マルチ"
        case .other:      return "その他"
        }
    }
}
