//
//  UsageQuota+CoreDataProperties.swift
//  NailNote
//
//  Created by Hideki Sato on 2026/02/19.
//
//

public import Foundation
public import CoreData


public typealias UsageQuotaCoreDataPropertiesSet = NSSet

extension UsageQuota {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UsageQuota> {
        return NSFetchRequest<UsageQuota>(entityName: "UsageQuota")
    }

    @NSManaged public var updatedAt: Date?
    @NSManaged public var freeSimRemaining: Int16
    @NSManaged public var monthKey: String?

}

extension UsageQuota : Identifiable {

}
