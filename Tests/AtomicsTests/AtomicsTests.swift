import XCTest
import Promises
@testable import Atomics

final class AtomicsTests: XCTestCase {
    
    func testAtomicObject () {
		let obj = AtomicMutablePointer<[Int]>(.init())
        DispatchQueue.concurrentPerform(iterations: 10000) { i in
            _ = obj.use { arr in arr.append(i) }
        }
        XCTAssertEqual(obj.syncPointee.count, 10000)
    }
    
    func testCachedObject () {
        var numRequests = 0
        let function = {
            Promise<Date>.init(on: .global(), { fulfill, reject in
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2), execute: {
                    numRequests += 1
                    fulfill(Date())
                }
            )
                
            })
        }
        
        let obj = CachedObject<Date>(function: function, mode: .periodic(10))
        DispatchQueue.concurrentPerform(iterations: 100, execute: { i in
            _ = obj.use { (date) in
                print(date)
            }
        })
        usleep(3 * 1000 * 1000)
        XCTAssertEqual(numRequests, 1)
    }
    
}
