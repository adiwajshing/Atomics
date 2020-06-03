//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 1/3/20.
//

import Foundation
import NIO

public class AtomicMutablePointer<Wrapped> {
	var value: Wrapped
    let queue = DispatchQueue(label: String(describing: Wrapped.self) + "_atomic", attributes: [])
    
	public init(_ value: Wrapped) { self.value = value }
    
    ///Asyncrously & safely get the object and modify it as well
	public func map <T> (on ev: EventLoop, using block: @escaping (inout Wrapped) throws -> T) -> EventLoopFuture<T> {
		flatMap(on: ev) { value in try ev.makeSucceededFuture(block (&value)) }
    }
	public func flatMap <T> (on ev: EventLoop, using block: @escaping (inout Wrapped) throws -> EventLoopFuture<T>) -> EventLoopFuture<T> {
		let promise = ev.makePromise(of: T.self)
		queue.async { [weak self] in
			guard let self = self else {
				promise.fail(Error.selfDeinit)
				return
			}
			do {
				let future = try block(&self.value)
				future.whenSuccess(promise.succeed)
				future.whenFailure(promise.fail)
			} catch {
				promise.fail(error)
			}
		}
		return promise.futureResult
    }
    public enum Error: Swift.Error {
        case selfDeinit
    }
}
public extension AtomicMutablePointer {
    
    ///Safely sets & gets the object; Modification of the object post the get is not thread safe if the object is a class
    var syncPointee: Wrapped {
        get {
            var obj: Wrapped!
            queue.sync { obj = value }
            return obj
        }
        set { queue.sync { value = newValue } }
    }
	func get (on ev: EventLoop) -> EventLoopFuture<Wrapped> {
		map (on: ev) { $0 }
    }
	func set (on ev: EventLoop, value: Wrapped) -> EventLoopFuture<Void> { map (on: ev) { $0 = value } }
}
