import XCTest
import NIO
@testable import Atomics

final class AtomicsTests: XCTestCase {
    
	let ev = MultiThreadedEventLoopGroup(numberOfThreads: 4)
	
    func testAtomicObject () {
		let obj = AtomicMutablePointer<[Int]>([])
		let tasks = (0..<10000).map { i in obj.map(on: ev.next()) { $0.append(i) } }
		
		XCTAssertNoThrow(try EventLoopFuture.whenAllSucceed(tasks, on: ev.next()).wait())
        XCTAssertEqual(obj.syncPointee.count, 10000)
    }
    
    func testCachedObject () {
        var numRequests = 0
		let function: () -> EventLoopFuture<Date> = {
			self.ev.next()
			.scheduleTask(in: .seconds(2)) {
				numRequests += 1
				return Date()
			}
			.futureResult
        }
		let obj = CachedObject<Date>(mode: .periodic(10), eventLoop: ev.next(), function: function)
		let tasks = (0..<500).map { _ in obj.map { $0.description } }
		XCTAssertNoThrow(try EventLoopFuture.whenAllSucceed(tasks, on: ev.next()).wait())
        XCTAssertEqual(numRequests, 1)
    }
    
}
