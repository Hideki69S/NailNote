//
//  NailEntry+CoreDataProperties.swift
//  NailNote
//
//  Created by Hideki Sato on 2026/02/19.
//
//

public import Foundation
public import CoreData


public typealias NailEntryCoreDataPropertiesSet = NSSet

extension NailEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NailEntry> {
        return NSFetchRequest<NailEntry>(entityName: "NailEntry")
    }

    @NSManaged public var updatedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: String?
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?

}

extension NailEntry : Identifiable {

}
