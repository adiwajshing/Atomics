//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 1/3/20.
//

import Foundation
import Promises

public class AtomicMutablePointer<Wrapped> {
    
    var value: Wrapped
    let queue = DispatchQueue(label: String(describing: Wrapped.self) + "_atomic", attributes: [])
    
    public init(_ value: Wrapped) { self.value = value }
    
    ///Asyncrously & safely get the object and modify it as well
    public func use (_ block: @escaping (inout Wrapped) throws -> Void ) -> Promise<Void> {
		map(using: block) as Promise<Void>
    }
    public func map <T> (using block: @escaping (inout Wrapped) throws -> T) -> Promise<T> {
		map(using: { Promise(try block (&$0)) })
    }
	public func map <T> (using block: @escaping (inout Wrapped) throws -> Promise<T>) -> Promise<T> {
		Promise<Void>(())
		.then(on: queue) { [weak self] _ throws -> Promise<T> in
            guard let self = self else { throw Error.selfDeinit }
            return try block(&self.value)
		}
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
    
    func get () -> Promise<Wrapped> {
		map { $0 }
    }
    func set (value: Wrapped) -> Promise<Void> { use { $0 = value } }
}
