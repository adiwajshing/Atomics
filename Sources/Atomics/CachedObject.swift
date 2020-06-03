//
//  CachedObject.swift
//  
//
//  Created by Adhiraj Singh on 1/7/20.
//

import Foundation
import NIO

public class CachedObject<Wrapped> {
    
	public let eventLoop: EventLoop
	
    private var lastCacheDate = Date(timeIntervalSince1970: 0)
    
    private let obj = AtomicMutablePointer<Wrapped?>(nil)
    private let cacheFunction: () -> EventLoopFuture<Wrapped>
    private let mode: CacheMode
    private let timer: DispatchSourceTimer?
    
	public init(mode: CacheMode, eventLoop: EventLoop, function: @escaping () -> EventLoopFuture<Wrapped>) {
		self.mode = mode
		self.eventLoop = eventLoop
        self.cacheFunction = function
       
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
	public func map <T>(_ block: @escaping (inout Wrapped) throws -> T) -> EventLoopFuture<T> {
		flatMap { try self.eventLoop.makeSucceededFuture(block(&$0)) }
	}
	public func flatMap <T>(_ block: @escaping (inout Wrapped) throws -> EventLoopFuture<T>) -> EventLoopFuture<T> {
		eventLoop.submit { [weak self] in
			guard let self = self else {
                throw AtomicMutablePointer<Wrapped>.Error.selfDeinit
            }
            if self.obj.value != nil {
                switch self.mode {
                case .needBased (let maxDelay):
                    if Date().timeIntervalSince(self.lastCacheDate) < maxDelay {
                        return try block(&self.obj.value!)
                    }
                    self.lastCacheDate = Date()
                    break
                case .periodic(_):
                    return try block(&self.obj.value!)
                }
            }
			return self.cacheFunction()
				.flatMap {
					var value = $0
					return self.obj.set(on: self.eventLoop, value: value)
					.flatMapThrowing { try block (&value) }
					.flatMap { $0 }
				}
		}
		.flatMap { $0 }
    }
    func refresh () -> EventLoopFuture<Void> {
		cacheFunction ().flatMap { self.obj.set(on: self.eventLoop, value: $0) }
    }
}
public enum CacheMode {
    case periodic (TimeInterval)
    case needBased (TimeInterval)
}
