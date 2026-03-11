import Foundation
import Observation

@Observable
final class CustomCategoryStore {

    static let shared = CustomCategoryStore()

    private init() {
        eventCategories = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.customEventCategories) ?? []
        taskCategories = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.customTaskCategories) ?? []
    }

    private(set) var eventCategories: [String]
    private(set) var taskCategories: [String]

    func addEventCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !eventCategories.contains(trimmed) else { return }
        eventCategories.append(trimmed)
        UserDefaults.standard.set(eventCategories, forKey: UserDefaultsKeys.customEventCategories)
    }

    func addTaskCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !taskCategories.contains(trimmed) else { return }
        taskCategories.append(trimmed)
        UserDefaults.standard.set(taskCategories, forKey: UserDefaultsKeys.customTaskCategories)
    }

    func removeEventCategory(_ name: String) {
        eventCategories.removeAll { $0 == name }
        UserDefaults.standard.set(eventCategories, forKey: UserDefaultsKeys.customEventCategories)
    }

    func removeTaskCategory(_ name: String) {
        taskCategories.removeAll { $0 == name }
        UserDefaults.standard.set(taskCategories, forKey: UserDefaultsKeys.customTaskCategories)
    }
}
