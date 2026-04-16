import CoreData

@MainActor
final class PersistenceController: ObservableObject, Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CardCollection")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                let storeURL = self.container.persistentStoreDescriptions.first?.url
                if let url = storeURL {
                    try? FileManager.default.removeItem(at: url)
                    self.container.loadPersistentStores { _, retryError in
                        if let retryError = retryError as NSError? {
                            fatalError("Unresolved error after reset \(retryError), \(retryError.userInfo)")
                        }
                    }
                } else {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save error: \(error)")
            }
        }
    }

    func createEntry(from item: CardEntryItem) -> CardEntry {
        let context = container.viewContext
        let entry = CardEntry(context: context)
        entry.updateFromItem(item)
        entry.createdAt = Date()
        entry.updatedAt = Date()
        for subItem in item.subcards {
            let sub = SubCard(context: context)
            sub.updateFromItem(subItem)
            sub.entry = entry
        }
        save()
        return entry
    }

    func updateEntry(_ entry: CardEntry, with item: CardEntryItem) {
        entry.updateFromItem(item)
        let existingSubs = entry.subcardsSorted
        let existingIds = Set(existingSubs.compactMap { $0.id })
        let newItemIds = Set(item.subcards.map { $0.id })
        for sub in existingSubs {
            if let subId = sub.id, !newItemIds.contains(subId) {
                container.viewContext.delete(sub)
            }
        }
        for subItem in item.subcards {
            if let existing = existingSubs.first(where: { $0.id == subItem.id }) {
                existing.updateFromItem(subItem)
            } else {
                let sub = SubCard(context: container.viewContext)
                sub.updateFromItem(subItem)
                sub.entry = entry
            }
        }
        save()
    }

    func deleteEntry(_ entry: CardEntry) {
        container.viewContext.delete(entry)
        save()
    }

    func fetchAllEntries() -> [CardEntry] {
        let request: NSFetchRequest<CardEntry> = CardEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CardEntry.createdAt, ascending: false)]
        do {
            return try container.viewContext.fetch(request)
        } catch {
            return []
        }
    }

    func searchEntries(query: String) -> [CardEntry] {
        let request: NSFetchRequest<CardEntry> = CardEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "nickname CONTAINS[cd] %@ OR ANY subcards.name CONTAINS[cd] %@ OR ANY subcards.set CONTAINS[cd] %@ OR ANY subcards.number CONTAINS[cd] %@",
            query, query, query, query
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CardEntry.createdAt, ascending: false)]
        do {
            return try container.viewContext.fetch(request)
        } catch {
            return []
        }
    }
}
