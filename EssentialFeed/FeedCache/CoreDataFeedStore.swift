//
//  CoreDataFeedStore.swift
//  EssentialFeed
//
//  Created by Fattah, Iram on 5/29/23.
//

import CoreData

public final class CoreDataFeedStore: FeedStore {
    private let container: NSPersistentContainer

    private let context: NSManagedObjectContext

    public init(storeURL: URL, bundle: Bundle = .main) throws {
        container = try NSPersistentContainer.load(modelName: "FeedStore", url: storeURL, in: bundle)
        context = container.newBackgroundContext()
    }

    public func retrieve(completion: @escaping RetrievalCompletion) {
        let context = self.context
                context.perform {
                    do {
                        if let cache = try ManagedCache.find(in: context){
                            completion(.found(feed: cache.localFeed, timestamp: cache.timestamp))
                        } else {
                            completion(.empty)
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
    }

    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        let context = self.context
                context.perform {
                    do {
                        let managedCache = try ManagedCache.newUniqueInstance(in: context)
                        managedCache.timestamp = timestamp
                        managedCache.feed = ManagedFeedImage.images(from: feed, in: context)
                        try context.save()
                        completion(nil)
                    } catch {
                        completion(error)
                    }
                }
    }

    public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        let context = self.context
        context.perform {
            do {
                try ManagedCache.find(in: context).map(context.delete).map(context.save)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

}

private extension NSPersistentContainer {
    enum LoadingError: Swift.Error {
        case modelNotFound
        case failedToLoadPersistentStores(Swift.Error)
    }

    static func load(modelName name: String, url: URL, in bundle: Bundle) throws -> NSPersistentContainer {
        guard let model = NSManagedObjectModel.with(name: name, in: bundle) else {
            throw LoadingError.modelNotFound
        }
        let description = NSPersistentStoreDescription(url: url)
        let container = NSPersistentContainer(name: name, managedObjectModel: model)
        container.persistentStoreDescriptions = [description]

        var loadError: Swift.Error?
        container.loadPersistentStores { loadError = $1 }
        try loadError.map { throw LoadingError.failedToLoadPersistentStores($0) }

        return container
    }
}

private extension NSManagedObjectModel {
    static func with(name: String, in bundle: Bundle) -> NSManagedObjectModel? {
        return bundle
            .url(forResource: name, withExtension: "momd")
            .flatMap { NSManagedObjectModel(contentsOf: $0) }
    }
}

@objc(ManagedCache)
public class ManagedCache: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ManagedCache> {
        return NSFetchRequest<ManagedCache>(entityName: "ManagedCache")
    }

    @NSManaged public var timestamp: Date
    @NSManaged public var feed: NSOrderedSet

    var localFeed: [LocalFeedImage] {
            return feed.compactMap { ($0 as? ManagedFeedImage)?.local }
        }

    static func find(in context: NSManagedObjectContext) throws -> ManagedCache? {
            let request = NSFetchRequest<ManagedCache>(entityName: entity().name!)
            request.returnsObjectsAsFaults = false
            return try context.fetch(request).first
        }

    static func newUniqueInstance(in context: NSManagedObjectContext) throws -> ManagedCache {
            try find(in: context).map(context.delete)
            return ManagedCache(context: context)
        }
}

@objc(ManagedFeedImage)
public class ManagedFeedImage: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ManagedFeedImage> {
        return NSFetchRequest<ManagedFeedImage>(entityName: "ManagedFeedImage")
    }

    @NSManaged public var id: UUID
    @NSManaged public var imageDescription: String?
    @NSManaged public var location: String?
    @NSManaged public var url: URL
    @NSManaged public var cache: ManagedCache

    var local: LocalFeedImage {
            return LocalFeedImage(id: id, description: imageDescription, location: location, url: url)
        }

    static func images(from localFeed: [LocalFeedImage], in context: NSManagedObjectContext) -> NSOrderedSet {
            return NSOrderedSet(array: localFeed.map { local in
                let managed = ManagedFeedImage(context: context)
                managed.id = local.id
                managed.imageDescription = local.description
                managed.location = local.location
                managed.url = local.url
                return managed
            })
        }

}

