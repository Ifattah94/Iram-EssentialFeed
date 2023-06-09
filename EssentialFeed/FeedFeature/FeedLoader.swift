//
//  FeedLoader.swift
//  EssentialFeed
//
//  Created by Fattah, Iram on 3/31/23.
//

import Foundation


public protocol FeedLoader {
    typealias Result = Swift.Result<[FeedImage], Error>

    func load(completion: @escaping (Result) -> Void)
}
