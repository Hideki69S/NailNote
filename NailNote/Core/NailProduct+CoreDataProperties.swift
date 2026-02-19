//
//  NailProduct+CoreDataProperties.swift
//  NailNote
//
//  Created by Hideki Sato on 2026/02/20.
//
//

public import Foundation
public import CoreData


public typealias NailProductCoreDataPropertiesSet = NSSet

extension NailProduct {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NailProduct> {
        return NSFetchRequest<NailProduct>(entityName: "NailProduct")
    }

    @NSManaged public var category: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var photoId: UUID?
    @NSManaged public var priceYenTaxIn: Int32
    @NSManaged public var purchasedAt: Date?
    @NSManaged public var purchasePlace: String?
    @NSManaged public var samplePhotoId: UUID?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var usedInEntries: NSSet?

}

// MARK: Generated accessors for usedInEntries
extension NailProduct {

    @objc(addUsedInEntriesObject:)
    @NSManaged public func addToUsedInEntries(_ value: NailEntryUsedItem)

    @objc(removeUsedInEntriesObject:)
    @NSManaged public func removeFromUsedInEntries(_ value: NailEntryUsedItem)

    @objc(addUsedInEntries:)
    @NSManaged public func addToUsedInEntries(_ values: NSSet)

    @objc(removeUsedInEntries:)
    @NSManaged public func removeFromUsedInEntries(_ values: NSSet)

}

extension NailProduct : Identifiable {

}
