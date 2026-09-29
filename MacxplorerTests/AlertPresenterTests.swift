import XCTest
@testable import Macxplorer

final class AlertPresenterTests: XCTestCase {
    @MainActor
    func testQueuedAsksResumeInOrderWithTheirOwnChoices() async throws {
        let alerts = AlertPresenter()
        let first = Task { await alerts.ask(collision("a")) }
        await settle()
        let second = Task { await alerts.ask(collision("b")) }
        await settle()
        XCTAssertEqual(alerts.current?.title, "a")

        alerts.finish(try XCTUnwrap(alerts.current?.id), choice: .replace)
        let firstChoice = await first.value
        XCTAssertEqual(firstChoice, .replace)
        await settle()
        XCTAssertEqual(alerts.current?.title, "b")

        alerts.finish(try XCTUnwrap(alerts.current?.id), choice: .keepBoth)
        let secondChoice = await second.value
        XCTAssertEqual(secondChoice, .keepBoth)
        await settle()
        XCTAssertNil(alerts.current)
    }

    @MainActor
    func testFinishWithoutAChoiceStops() async throws {
        let alerts = AlertPresenter()
        let asked = Task { await alerts.ask(collision("a")) }
        await settle()

        alerts.finish(try XCTUnwrap(alerts.current?.id))

        let choice = await asked.value
        XCTAssertEqual(choice, .stop)
    }

    @MainActor
    func testFinishingAnAlertThatIsNoLongerShownChangesNothing() async throws {
        let alerts = AlertPresenter()
        alerts.show(ActionAlert(title: "a", message: ""))
        let staleID = try XCTUnwrap(alerts.current?.id)
        alerts.show(ActionAlert(title: "b", message: ""))
        alerts.finish(staleID)
        await settle()

        alerts.finish(staleID)

        XCTAssertEqual(alerts.current?.title, "b")
    }

    @MainActor
    func testShowWaitsBehindAnOpenAsk() async throws {
        let alerts = AlertPresenter()
        let asked = Task { await alerts.ask(collision("a")) }
        await settle()
        alerts.show(ActionAlert(title: "b", message: ""))
        XCTAssertEqual(alerts.current?.title, "a")

        alerts.finish(try XCTUnwrap(alerts.current?.id), choice: .keepBoth)
        _ = await asked.value
        await settle()

        XCTAssertEqual(alerts.current?.title, "b")
    }

    private func collision(_ title: String) -> ActionAlert {
        ActionAlert(title: title, message: "", kind: .collision)
    }

    @MainActor
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }
}
