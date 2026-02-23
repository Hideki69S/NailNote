//
//  UsageQuota+CoreDataProperties.swift
//  NailNote
//
//  Created by Hideki Sato on 2026/02/20.
//
//

import Foundation
import CoreData


public typealias UsageQuotaCoreDataPropertiesSet = NSSet

extension UsageQuota {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UsageQuota> {
        return NSFetchRequest<UsageQuota>(entityName: "UsageQuota")
    }

    @NSManaged public var freeSimRemaining: Int16
    @NSManaged public var aiScoreUsed: Int16
    @NSManaged public var monthKey: String?
    @NSManaged public var updatedAt: Date?

}

extension UsageQuota : Identifiable {

}
