//
//  CachedObject.swift
//  
//
//  Created by Adhiraj Singh on 1/7/20.
//

import Foundation
import Promises

public class CachedObject<Wrapped> {
    
    private var lastCacheDate = Date(timeIntervalSince1970: 0)
    
    private let obj = AtomicMutablePointer<Wrapped?>(nil)
    private let cacheFunction: () -> Promise<Wrapped>
    private let mode: CacheMode
    private let timer: DispatchSourceTimer?
    
    public init(function: @escaping () -> Promise<Wrapped>, mode: CacheMode) {
        self.cacheFunction = function
        self.mode = mode
        
        switch mode {
        case .periodic(let interval):
            self.timer = DispatchSource.makeTimerSource(flags: [], queue: obj.queue)
            timer!.schedule(deadline: .now() + .milliseconds(Int(interval)*1000), repeating: .milliseconds(Int(interval)*1000), leeway: .milliseconds(25))
            timer!.setEventHandler { [weak self] in _ = self?.refresh() }
            timer!.resume()
            break
        default:
            timer = nil
            break
        }
        
    }
    public func use(_ block: @escaping (inout Wrapped) throws -> Void) -> Promise<Void> {
        return Promise<Void>(on: obj.queue) { [weak self] fulfill, reject throws in
            guard let self = self else {
                reject(AtomicMutablePointer<Wrapped>.Error.selfDeinit)
                return
            }
            if self.obj.value != nil {
                switch self.mode {
                case .needBased (let maxDelay):
                    if Date().timeIntervalSince(self.lastCacheDate) < maxDelay {
                        try block(&self.obj.value!)
                        fulfill(())
                        return
                    }
                    self.lastCacheDate = Date()
                    break
                case .periodic(_):
                    try block(&self.obj.value!)
                    fulfill(())
                    return
                }
            }
            self.obj.value = try await(self.cacheFunction())
            
            try block(&self.obj.value!)
            fulfill(())
        }
    }
    func refresh () -> Promise<Void> {
        return cacheFunction().then (on: self.obj.queue) { [weak self] obj -> Promise<Void> in
            guard let self = self else {
                return .init(())
            }
            return self.obj.use { $0 = obj }
        }
    }    
}
public enum CacheMode {
    case periodic (TimeInterval)
    case needBased (TimeInterval)
}
