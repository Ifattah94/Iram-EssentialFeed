//
//  CacheFeedUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Fattah, Iram on 5/3/23.
//

import XCTest
import EssentialFeed

class CacheFeedUseCaseTests: XCTestCase {

    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store) = makeSUT()
        XCTAssertEqual(store.recievedMessages, [])
    }

    func test_save_requestCacheDeletion() {
        let (sut, store) = makeSUT()
        
        sut.save(uniqueImageFeed().models) { _ in }

        XCTAssertEqual(store.recievedMessages, [.deleteCacheFeed])
    }

    func test_save_doesNotRequestCacheInsertOnDeletionError() {
        let (sut, store) = makeSUT()
        let deletionError = anyNSError()
        sut.save(uniqueImageFeed().models) { _ in }
        store.completeDeletion(with: deletionError)

        XCTAssertEqual(store.recievedMessages, [.deleteCacheFeed])

    }

    func test_save_requestsNewCacheInsertionWithTimeStampOnSuccessfulDeletion() {
        let timestamp = Date()
        let feed = uniqueImageFeed()
        let (sut, store) = makeSUT(currentDate: { timestamp })

        sut.save(feed.models) { _ in }
        store.completeDeletionSuccessfully()

        XCTAssertEqual(store.recievedMessages, [.deleteCacheFeed, .insert(feed.local, timestamp)])

    }

    func test_save_failsOnDeletionError() {
        let (sut, store) = makeSUT()

        let deletionError = anyNSError()
        expect(sut, toCompleteWithError: deletionError) {
            store.completeDeletion(with: deletionError)
        }
    }

    func test_save_failsOnInsertionError() {
        let (sut, store) = makeSUT()
        let insertionError = anyNSError()

        expect(sut, toCompleteWithError: insertionError) {
            store.completeDeletionSuccessfully()
            store.completeInsertion(with: insertionError)
        }


    }

    func test_save_succeedsOnSuccessfulCacheInsertion() {
        let (sut, store) = makeSUT()

        expect(sut, toCompleteWithError: nil) {
            store.completeDeletionSuccessfully()
            store.completeInsertionSuccessfully()
        }
    }

    func test_save_doesNotDeliverDeletionErrorAfterSUTInstanceHasBeenDeallocated() {
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: Date.init)

        var recievedResults = [LocalFeedLoader.SaveResult]()

        sut?.save(uniqueImageFeed().models) { recievedResults.append($0) }
        sut = nil

        store.completeDeletion(with: anyNSError())

        XCTAssertTrue(recievedResults.isEmpty)
    }

    func test_save_doesNotDeliverInsertionErrorAfterSUTInstanceHasBeenDeallocated() {
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: Date.init)

        var recievedResults = [LocalFeedLoader.SaveResult]()

        sut?.save(uniqueImageFeed().models) { recievedResults.append($0) }
        store.completeDeletionSuccessfully()
        sut = nil

        store.completeInsertion(with: anyNSError())

        XCTAssertTrue(recievedResults.isEmpty)
    }


    // MARK: Helpers

    private func makeSUT(currentDate: @escaping () -> Date = Date.init, file: StaticString = #file, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, currentDate: currentDate)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store)
    }

    private func expect(_ sut: LocalFeedLoader, toCompleteWithError expectedError: NSError?, when action: () -> Void, file: StaticString = #file, line: UInt = #line) {
        let exp = expectation(description: "Wait for save completion")

        var receivedError: Error?
            sut.save(uniqueImageFeed().models) { result in
            if case let Result.failure(error) = result { receivedError = error }
            exp.fulfill()
        }

        action()
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(receivedError as NSError?, expectedError, file: file, line: line)

    }

}
