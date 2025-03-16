//
//  CoreDataStack.swift
//  Bablo
//
//  Created by Anton Bredykhin on 3/13/25.
//

import Foundation
import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BabloModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                Logger.e("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                Logger.e("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
