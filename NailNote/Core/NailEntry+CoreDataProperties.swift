//
//  NailEntry+CoreDataProperties.swift
//  NailNote
//
//  Created by Hideki Sato on 2026/02/20.
//
//

public import Foundation
public import CoreData


public typealias NailEntryCoreDataPropertiesSet = NSSet

extension NailEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NailEntry> {
        return NSFetchRequest<NailEntry>(entityName: "NailEntry")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var note: String?
    @NSManaged public var photoId: UUID?
    @NSManaged public var designCategory: String?
    @NSManaged public var colorCategory: String?
    @NSManaged public var rating: Double
    @NSManaged public var title: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var usedItems: NSOrderedSet?

}

// MARK: Generated accessors for usedItems
extension NailEntry {

    @objc(insertObject:inUsedItemsAtIndex:)
    @NSManaged public func insertIntoUsedItems(_ value: NailEntryUsedItem, at idx: Int)

    @objc(removeObjectFromUsedItemsAtIndex:)
    @NSManaged public func removeFromUsedItems(at idx: Int)

    @objc(insertUsedItems:atIndexes:)
    @NSManaged public func insertIntoUsedItems(_ values: [NailEntryUsedItem], at indexes: NSIndexSet)

    @objc(removeUsedItemsAtIndexes:)
    @NSManaged public func removeFromUsedItems(at indexes: NSIndexSet)

    @objc(replaceObjectInUsedItemsAtIndex:withObject:)
    @NSManaged public func replaceUsedItems(at idx: Int, with value: NailEntryUsedItem)

    @objc(replaceUsedItemsAtIndexes:withUsedItems:)
    @NSManaged public func replaceUsedItems(at indexes: NSIndexSet, with values: [NailEntryUsedItem])

    @objc(addUsedItemsObject:)
    @NSManaged public func addToUsedItems(_ value: NailEntryUsedItem)

    @objc(removeUsedItemsObject:)
    @NSManaged public func removeFromUsedItems(_ value: NailEntryUsedItem)

    @objc(addUsedItems:)
    @NSManaged public func addToUsedItems(_ values: NSOrderedSet)

    @objc(removeUsedItems:)
    @NSManaged public func removeFromUsedItems(_ values: NSOrderedSet)

}

extension NailEntry : Identifiable {

}

// MARK: - Helper

extension NailEntry {
    var designCategoryValue: NailDesignCategory {
        get { NailDesignCategory(rawValue: designCategory ?? "") ?? .oneColor }
        set { designCategory = newValue.rawValue }
    }

    var colorCategoryValue: NailColorTone {
        get { NailColorTone(rawValue: colorCategory ?? "") ?? .pink }
        set { colorCategory = newValue.rawValue }
    }
}
