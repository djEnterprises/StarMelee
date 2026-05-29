import XCTest
@testable import Starfighter

final class StarfighterTests: XCTestCase {

    func testShipsJSONLoads() throws {
        let ships = ShipDefinition.loadAll(bundle: .main)
        XCTAssertFalse(ships.isEmpty, "Ships.json must be in the bundle and decode cleanly")
        XCTAssertEqual(ships.count, 12, "Plan Section 5 specifies 12 launch ships")
    }

    func testWeaponsJSONLoads() throws {
        let weapons = WeaponDefinition.loadAll(bundle: .main)
        XCTAssertFalse(weapons.isEmpty)
    }

    func testPowerUpsJSONLoads() throws {
        let powerUps = PowerUpDefinition.loadAll(bundle: .main)
        XCTAssertFalse(powerUps.isEmpty)
    }

    func testMatchStateSeriesWinner() {
        var state = MatchState.initial
        XCTAssertNil(state.seriesWinner)
        state.playerWins = 2
        XCTAssertEqual(state.seriesWinner, .player)
        state.playerWins = 1
        state.opponentWins = 2
        XCTAssertEqual(state.seriesWinner, .opponent)
    }
}
