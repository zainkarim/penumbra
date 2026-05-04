//
//  HUDState.swift
//  Penumbra
//

import Observation
import SwiftUI

enum MaterialOption: Equatable, CaseIterable {
    case matte
    case reflective
    case red
    case blue
    case green
    case yellow

    var label: String {
        switch self {
        case .matte:      return "Matte"
        case .reflective: return "Mirror"
        case .red:        return "Red"
        case .blue:       return "Blue"
        case .green:      return "Green"
        case .yellow:     return "Yellow"
        }
    }

    var swatchColor: Color {
        switch self {
        case .matte:      return Color(white: 0.85)
        case .reflective: return Color(white: 0.95)
        case .red:        return .red
        case .blue:       return Color(red: 0.15, green: 0.35, blue: 0.9)
        case .green:      return Color(red: 0.15, green: 0.75, blue: 0.3)
        case .yellow:     return Color(red: 0.95, green: 0.85, blue: 0.1)
        }
    }
}

enum LightMode: CaseIterable, Hashable {
    case auto
    case manual
    case off

    var label: String {
        switch self {
        case .auto:   return "Auto"
        case .manual: return "Manual"
        case .off:    return "Off"
        }
    }
}

@Observable @MainActor
final class HUDState {
    var detectedPlaneCount: Int = 0
    var hasPlacedObject: Bool = false
    var showSidebar: Bool = true
    var selectedMaterial: MaterialOption = .matte
    var lightMode: LightMode = .auto
    var manualAzimuth: Double = 135.0    // degrees around Y axis (0 = +Z, 90 = +X)
    var manualElevation: Double = 45.0   // degrees above horizon [15, 85]
    var manualIntensity: Double = 0.7    // [0, 1]
}
