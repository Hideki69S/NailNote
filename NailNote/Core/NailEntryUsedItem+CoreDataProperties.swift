//
//  NailEntryUsedItem+CoreDataProperties.swift
//  NailNote
//
//  Created by Hideki Sato on 2026/02/20.
//
//

public import Foundation
public import CoreData


public typealias NailEntryUsedItemCoreDataPropertiesSet = NSSet

extension NailEntryUsedItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NailEntryUsedItem> {
        return NSFetchRequest<NailEntryUsedItem>(entityName: "NailEntryUsedItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var orderIndex: Int16
    @NSManaged public var entry: NailEntry?
    @NSManaged public var product: NailProduct?

}

extension NailEntryUsedItem : Identifiable {

}
