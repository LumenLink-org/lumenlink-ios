//
//  SiriIntegration.swift
//  LumenLink
//
//  Siri Shortcuts integration for emergency panic mode
//

import Foundation
import Intents
import IntentsUI

/**
 * Siri Integration
 * 
 * Provides Siri shortcuts for activating/deactivating panic mode
 */
class SiriIntegration {
    
    private let emergencyManager: EmergencyContactManager
    
    init(emergencyManager: EmergencyContactManager) {
        self.emergencyManager = emergencyManager
    }
    
    /**
     * Create Siri shortcut for panic mode activation
     */
    func createPanicModeShortcut() -> INIntent {
        let intent = INIntent()
        intent.suggestedInvocationPhrase = "Activate panic mode"
        return intent
    }
    
    /**
     * Handle Siri shortcut invocation
     */
    func handleShortcut(_ intent: INIntent) {
        if intent is INActivatePanicModeIntent {
            emergencyManager.activatePanicMode()
        } else if intent is INDeactivatePanicModeIntent {
            emergencyManager.deactivatePanicMode()
        }
    }
    
    /**
     * Donate shortcut to Siri for better recognition
     */
    func donateShortcut() {
        let interaction = INInteraction(intent: createPanicModeShortcut(), response: nil)
        interaction.identifier = "com.lumenlink.panic-mode"
        interaction.donate { error in
            if let error = error {
                print("Failed to donate Siri shortcut: \(error.localizedDescription)")
            } else {
                print("Siri shortcut donated successfully")
            }
        }
    }
}

/**
 * Custom Intent for activating panic mode
 */
@available(iOS 12.0, *)
class INActivatePanicModeIntent: INIntent {
    override init() {
        super.init()
    }
}

/**
 * Custom Intent for deactivating panic mode
 */
@available(iOS 12.0, *)
class INDeactivatePanicModeIntent: INIntent {
    override init() {
        super.init()
    }
}
