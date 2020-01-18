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
        return Promise<Void>(on: queue) { [weak self] fulfill, reject throws in
            guard let self = self else {
                reject(Error.selfDeinit)
                return
            }
            try block(&self.value)
            fulfill(())
        }
    }
    
    public func map <T> (using block: @escaping (inout Wrapped) throws -> T) -> Promise<T> {
        var value: T!
        return use{ value = try block(&$0) }.then(on: queue) { value }
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
        set { try! await(self.set(value: newValue)) }
    }
    
    func get () -> Promise<Wrapped> {
        var obj: Wrapped!
        return use({ obj = $0}).then(on: self.queue) { obj }
    }
    func set (value: Wrapped) -> Promise<Void> { use { $0 = value } }
}