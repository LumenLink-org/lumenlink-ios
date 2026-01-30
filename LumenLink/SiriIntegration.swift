//
//  SiriIntegration.swift
//  LumenLink
//
//  Siri Shortcuts integration for emergency panic mode.
//

import Foundation
import Intents

final class SiriIntegration {
    private let emergencyManager: EmergencyContactManager

    init(emergencyManager: EmergencyContactManager = .shared) {
        self.emergencyManager = emergencyManager
    }

    func donateShortcut() {
        let intent = INIntent()
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = "com.lumenlink.panic-mode"
        interaction.donate { _ in }
    }

    func handlePanicModeActivation() {
        emergencyManager.activatePanicMode()
    }

    func handlePanicModeDeactivation() {
        emergencyManager.deactivatePanicMode()
    }
}
