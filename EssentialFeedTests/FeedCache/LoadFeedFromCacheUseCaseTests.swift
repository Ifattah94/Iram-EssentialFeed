//
//  LoadFeedFromCacheUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Fattah, Iram on 5/7/23.
//

import XCTest
import EssentialFeed

class LoadFeedFromCacheUseCaseTests: XCTestCase {

    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store) = makeSUT()

        XCTAssertEqual(store.recievedMessages, [])
    }

    func test_load_requestsCacheRetrieval() {
        let (sut, store) = makeSUT()

        sut.load { _ in }

        XCTAssertEqual(store.recievedMessages, [.retrieve])
    }

    func test_load_fails_OnRetrievalError() {
        let (sut, store) = makeSUT()
        let retrievalError = anyNSError()

        expect(sut, toCompleteWith: .failure(retrievalError), when: {
            store.completeRetrieval(with: retrievalError)
        })
    }

    func test_load_deliversNoImagesOnEmptyCache() {
        let (sut, store) = makeSUT()

        expect(sut, toCompleteWith: .success([]), when: {
            store.completeRetrievalWithEmptyCache()
        })
    }

    func test_load_deliversCachedImagesOnNonExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()

        let nonExpiredTimeStamp = fixedCurrentDate.minusFeedCacheMaxAge().adding(seconds: 1)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })

        expect(sut, toCompleteWith: .success(feed.models), when : {
            store.completeRetrieval(with: feed.local, timestamp: nonExpiredTimeStamp)
        })
    }

    func test_load_deliversNoImagesOnCacheExpiration() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()

        let expirationTimeStamp = fixedCurrentDate.minusFeedCacheMaxAge()
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })

        expect(sut, toCompleteWith: .success([]), when : {
            store.completeRetrieval(with: feed.local, timestamp: expirationTimeStamp)
        })
    }

    func test_load_deliversNoImagesExpiredOldCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()

        let expiredTimeStamp = fixedCurrentDate.minusFeedCacheMaxAge().adding(seconds: -1)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })

        expect(sut, toCompleteWith: .success([]), when : {
            store.completeRetrieval(with: feed.local, timestamp: expiredTimeStamp)
        })
    }

    func test_load_hasNoSideEffectsOnRetrievalError() {
        let (sut, store) = makeSUT()
        sut.load { _ in }

        store.completeRetrieval(with: anyNSError())
        XCTAssertEqual(store.recievedMessages, [.retrieve])
    }

    func test_load_hasNoSideEffectsOnEmptyCache() {
        let (sut, store) = makeSUT()
        sut.load { _ in }

        store.completeRetrievalWithEmptyCache()
        XCTAssertEqual(store.recievedMessages, [.retrieve])
    }

    func test_hasNoSideEffectsOnNonExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let nonExpiredTimeStamp = fixedCurrentDate.minusFeedCacheMaxAge().adding(seconds: 1)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })

        sut.load { _ in }
        store.completeRetrieval(with: feed.local, timestamp: nonExpiredTimeStamp)
        XCTAssertEqual(store.recievedMessages, [.retrieve])
    }

    func test_load_hasNoSideEffectsOnCacheExpiration() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let expirationTimeStamp = fixedCurrentDate.minusFeedCacheMaxAge()
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })

        sut.load { _ in }
        store.completeRetrieval(with: feed.local, timestamp: expirationTimeStamp)
        XCTAssertEqual(store.recievedMessages, [.retrieve])
    }

    func test_load_hasNoSideEffectsOnExpiredCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let expiredTimeStamp = fixedCurrentDate.minusFeedCacheMaxAge().adding(seconds: -1)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate })

        sut.load { _ in }
        store.completeRetrieval(with: feed.local, timestamp: expiredTimeStamp)
        XCTAssertEqual(store.recievedMessages, [.retrieve])
    }

    func test_load_DoesNotDeliverResultAfterSUTInstanceHasBeenDeallocated() {
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: Date.init)

        var recievedResults = [LocalFeedLoader.LoadResult]()
        sut?.load(completion: { recievedResults.append($0) })
        sut = nil
        store.completeRetrievalWithEmptyCache()

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

    private func expect(_ sut: LocalFeedLoader, toCompleteWith expectedResult: LocalFeedLoader.LoadResult, when action: () -> Void, file: StaticString = #file, line: UInt = #line) {
        let exp = expectation(description: "Wait for load completion")

        sut.load { recievedResult in
            switch (recievedResult, expectedResult) {
            case let (.success(recievedImages), .success(expectedImages)):
                XCTAssertEqual(recievedImages, expectedImages, file: file, line: line)
            case let (.failure(recievedError as NSError), .failure(expectedError as NSError)):
                XCTAssertEqual(recievedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected result \(expectedResult) got \(recievedResult) instead")
            }
            exp.fulfill()
        }
        action()
        wait(for: [exp], timeout: 1.0)
    }

}
