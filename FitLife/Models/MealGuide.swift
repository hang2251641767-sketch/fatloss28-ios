import Foundation

struct NutritionPreferences: Codable {
    var allergens: [String] = []
    var avoidedFoods = ""
}
struct PersonalDietSettings: Codable {
    var version: Int
    var height: Double?
    var weight: Double?
    var targetCalories: Int?
    var avoidedFoods: String?
}
struct MealIngredient: Codable, Identifiable {
    var id: String
    var name: String
    var grams: Double
    var basis: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var allergens: [String]
    var amountText: String { String(format: "%.0f g · %@", grams, basis) }
    func avoidReason(_ preferences: NutritionPreferences) -> String? {
        let matches = allergens.filter { preferences.allergens.contains($0) }
        if !matches.isEmpty { return "含" + matches.joined(separator: "、") }
        let words = preferences.avoidedFoods.components(separatedBy: CharacterSet(charactersIn: ",，、;；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if words.contains(where: { name.localizedCaseInsensitiveContains($0) }) { return "在你的忌口清单中" }
        return nil
    }
}
struct SuggestedMeal: Codable, Identifiable {
    var id: String
    var name: String
    var note: String
    var ingredients: [MealIngredient]
    var calories: Int { Int(ingredients.reduce(0) { $0 + $1.calories * $1.grams / 100 }.rounded()) }
    var protein: Double { ingredients.reduce(0) { $0 + $1.protein * $1.grams / 100 } }
    var carbs: Double { ingredients.reduce(0) { $0 + $1.carbs * $1.grams / 100 } }
    var fat: Double { ingredients.reduce(0) { $0 + $1.fat * $1.grams / 100 } }
    func isBlocked(_ preferences: NutritionPreferences) -> Bool { ingredients.contains { $0.avoidReason(preferences) != nil } }
    func entry(on date: Date) -> NutritionEntry {
        NutritionEntry(date: date, calories: calories, protein: protein, carbs: carbs, fat: fat,
                       meal: name + " · 按菜单记录（估算）", guideMealID: id)
    }
}
struct MealDay: Codable, Identifiable {
    var id: Int
    var title: String
    var meals: [SuggestedMeal]
    var calories: Int { meals.reduce(0) { $0 + $1.calories } }
    var protein: Double { meals.reduce(0) { $0 + $1.protein } }
}
enum MealGuide {
    static func load(bundle: Bundle = .main) throws -> [MealDay] {
        guard let url = bundle.url(forResource: "MealGuide", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        let days = try JSONDecoder().decode([MealDay].self, from: Data(contentsOf: url))
        guard days.count == 7, Set(days.map(\.id)).count == 7,
              days.allSatisfy({ $0.meals.count == 4 && $0.calories > 1200 && $0.calories < 2600 }) else { throw DataError.invalidBackup }
        return days.sorted { $0.id < $1.id }
    }
    static func dayIndex(on date: Date, courseStart: Date?) -> Int {
        let cal = Calendar.current
        if let start = courseStart {
            let offset = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: date)).day ?? 0
            if offset >= 0 { return offset % 7 }
        }
        return (cal.component(.weekday, from: date) + 5) % 7
    }
}
