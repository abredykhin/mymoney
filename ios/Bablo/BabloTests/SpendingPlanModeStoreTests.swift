import Testing
import Foundation
@testable import Bablo

struct SpendingPlanModeStoreTests {

    @Test func missingUserModeDefaultsToSafeToSpend() {
        let defaults = UserDefaults(suiteName: "SpendingPlanModeStoreTests.missing")!
        defaults.removePersistentDomain(forName: "SpendingPlanModeStoreTests.missing")
        let store = SpendingPlanModeStore(defaults: defaults)

        #expect(store.mode(for: "user-1") == .safeToSpend)
    }

    @Test func savesModePerUser() {
        let defaults = UserDefaults(suiteName: "SpendingPlanModeStoreTests.perUser")!
        defaults.removePersistentDomain(forName: "SpendingPlanModeStoreTests.perUser")
        let store = SpendingPlanModeStore(defaults: defaults)

        store.save(.monthlyPlan, for: "user-1")

        #expect(store.mode(for: "user-1") == .monthlyPlan)
        #expect(store.mode(for: "user-2") == .safeToSpend)
    }
}
