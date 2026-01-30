#if canImport(Network)
@testable import Alamofire
import Dispatch
import Testing

@Suite("OfflineRetrierTests")
struct OfflineRetrierTests {
    @Test
    func requestIsRetriedWhenConnectivityIsRestored() async {
        // Given
        let didStop = Protected(false)
        let monitor = PathMonitor { queue, onResult in
            queue.async {
                onResult(.pathAvailable)
            }
        } stop: {
            didStop.write(true)
        }

        // When: retrier considers error to be offline error.
        let retrier = OfflineRetrier(monitor: monitor, maximumWait: .milliseconds(100)) { _ in true }
        // When: request fails due to error (type doesn't matter).
        let request = AF.request(.endpoints(.status(404), .get), interceptor: retrier).validate()
        let result = await request.serializingData().result

        // Then: request is retried successfully.
        #expect(result.isSuccess == true)
        // Then: two tasks are created.
        #expect(request.tasks.count == 2)
        // Then: monitor is stopped.
        #expect(didStop.value == true)
    }

    @Test
    func requestIsNotRetriedWhenTheErrorIsNotOfflineError() async {
        // Given
        let didStop = Protected(false)
        let monitor = PathMonitor { queue, onResult in
            queue.async {
                onResult(.pathAvailable)
            }
        } stop: {
            didStop.write(true)
        }

        // When
        let retrier = OfflineRetrier(monitor: monitor, maximumWait: .milliseconds(100))
        // When: request fails due to validation.
        let request = AF.request(.endpoints(.status(404), .get), interceptor: retrier).validate()
        let result = await request.serializingData().result

        // Then: request fails since validation failures aren't retried.
        #expect(result.isSuccess == false)
        // Then: only one task is created.
        #expect(request.tasks.count == 1)
        // Then: stop not called, as retrier isn't immediately deinit'd.
        #expect(didStop.value == false)
    }

    @Test
    func requestIsNotRetriedWhenPathTimesOut() async {
        // Given
        let didStop = Protected(false)
        let pathAvailable: Protected<DispatchWorkItem?> = .init(nil)
        let monitor = PathMonitor { queue, onResult in
            let work = DispatchWorkItem { onResult(.pathAvailable) }
            pathAvailable.write(work)
            // Given: path available after one second.
            queue.asyncAfter(deadline: .now() + .seconds(1), execute: work)
        } stop: {
            pathAvailable.write { $0?.cancel() }
            didStop.write(true)
        }

        // When: retrier times out after one millisecond.
        let retrier = OfflineRetrier(monitor: monitor, maximumWait: .milliseconds(1)) { _ in true }
        // When: request fails due to validation but would succeed on retry.
        let request = AF.request(.endpoints(.status(404), .get), interceptor: retrier).validate()
        let result = await request.serializingData().result

        // Then: request fails since it's not retried.
        #expect(result.isSuccess == false)
        // Then: only one task is created.
        #expect(request.tasks.count == 1)
        // Then: stop is called since timeout resets retrier.
        #expect(didStop.value == true)
    }

    @Test
    func sessionWideRetrierCanRetryMultipleRequests() async {
        // Given
        let didStop = Protected(false)
        let pathAvailable: Protected<DispatchWorkItem?> = .init(nil)
        let monitor = PathMonitor { queue, onResult in
            let work = DispatchWorkItem { onResult(.pathAvailable) }
            pathAvailable.write(work)
            // Given: path available after ten milliseconds.
            queue.asyncAfter(deadline: .now() + .milliseconds(10), execute: work)
        } stop: {
            pathAvailable.write { $0?.cancel() }
            didStop.write(true)
        }

        // When
        let retrier = OfflineRetrier(monitor: monitor, maximumWait: .milliseconds(500)) { _ in true }
        let session = Session(interceptor: retrier)
        // When: multiple requests are started which initially fail due to validation.
        async let first = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let second = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let third = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let fourth = session.request(.endpoints(.status(404), .get)).validate().serializingData().result

        // Then: all requests succeed after retry.
        await #expect(first.isSuccess == true)
        await #expect(second.isSuccess == true)
        await #expect(third.isSuccess == true)
        await #expect(fourth.isSuccess == true)
        // Then: monitor has stopped due to `Session` deinit.
        #expect(didStop.value == true)
    }

    @Test
    func sessionWideRetrierCanRetryMultipleRequestsTwice() async {
        // Given
        let didStop = Protected(false)
        let pathAvailable: Protected<DispatchWorkItem?> = .init(nil)
        let monitor = PathMonitor { queue, onResult in
            let work = DispatchWorkItem { onResult(.pathAvailable) }
            pathAvailable.write(work)
            // Given: path available after ten milliseconds.
            queue.asyncAfter(deadline: .now() + .milliseconds(10), execute: work)
        } stop: {
            pathAvailable.write { $0?.cancel() }
            didStop.write(true)
        }

        // When
        let retrier = OfflineRetrier(monitor: monitor, maximumWait: .milliseconds(500)) { _ in true }
        let session = Session(interceptor: retrier)
        // When: multiple requests are started which initially fail due to validation.
        async let first = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let second = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let third = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let fourth = session.request(.endpoints(.status(404), .get)).validate().serializingData().result

        // Then: all requests succeed after retry.
        await #expect(first.isSuccess == true)
        await #expect(second.isSuccess == true)
        await #expect(third.isSuccess == true)
        await #expect(fourth.isSuccess == true)

        // When: another set of requests are started which initially fail due to validation.
        async let fifth = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let sixth = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let seventh = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let eighth = session.request(.endpoints(.status(404), .get)).validate().serializingData().result

        // Then: second set of requests succeed after retry.
        await #expect(fifth.isSuccess == true)
        await #expect(sixth.isSuccess == true)
        await #expect(seventh.isSuccess == true)
        await #expect(eighth.isSuccess == true)
        // Then: monitor has stopped due to `Session` deinit.
        #expect(didStop.value == true)
    }

    @Test
    func sessionWideRetrierCanTimeOutMultipleRequests() async {
        // Given
        let didStop = Protected(false)
        let pathAvailable: Protected<DispatchWorkItem?> = .init(nil)
        let monitor = PathMonitor { queue, onResult in
            let work = DispatchWorkItem { onResult(.pathAvailable) }
            pathAvailable.write(work)
            // Given: path available after one second.
            queue.asyncAfter(deadline: .now() + .seconds(1), execute: work)
        } stop: {
            pathAvailable.write { $0?.cancel() }
            didStop.write(true)
        }

        // When
        let retrier = OfflineRetrier(monitor: monitor, maximumWait: .milliseconds(10)) { _ in true }
        let session = Session(interceptor: retrier)
        // When: multiple requests are started which initially fail due to validation.
        async let first = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let second = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let third = session.request(.endpoints(.status(404), .get)).validate().serializingData().result
        async let fourth = session.request(.endpoints(.status(404), .get)).validate().serializingData().result

        // Then: all requests succeed after retry.
        await #expect(first.isSuccess == false)
        await #expect(second.isSuccess == false)
        await #expect(third.isSuccess == false)
        await #expect(fourth.isSuccess == false)
        // Then: monitor has stopped due to `Session` deinit.
        #expect(didStop.value == true)
    }

    @Test
    func offlineRetrierNeverStartsOrStopsWhenImmediatelyDeinited() {
        // Given
        let didStart = Protected(false)
        let didStop = Protected(false)
        let monitor = PathMonitor { _, _ in
            didStart.write(true)
        } stop: {
            didStop.write(true)
        }

        // When: retrier created with no start and long timeout.
        let retrier = OfflineRetrier(monitor: monitor, maximumWait: .seconds(100))
        // When: retrier is deinit'd.
        _ = consume retrier

        // Then: didStart is false.
        #expect(didStart.value == false)
        // Then: didStop is false.
        #expect(didStop.value == false)
    }
}
#endif
