const { test } = require("node:test");
const assert = require("node:assert/strict");
const api = require("../logic.js");
const fixtures = require("../fixtures.json");
test("dense viewport selects 30 closest stations to its center", () => {
  const scenario = fixtures.scenarios.find(s => s.id === "dense");
  const stations = api.stationsFor(fixtures, scenario);
  assert.equal(stations.length, 60);
  assert.deepEqual(api.visibleStations(stations, api.defaultViewport()).map(s => s.id),
    Array.from({ length: 30 }, (_, i) => `cluster-${String(i).padStart(2, "0")}`));
  const moved = { ...api.defaultViewport(), center: { latitude: 43.655, longitude: -79.3832 } };
  assert.notDeepEqual(api.visibleStations(stations, moved).map(s => s.id), api.visibleStations(stations, api.defaultViewport()).map(s => s.id));
});
test("panning culls offscreen markers and returning restores them", () => {
  const all = api.visibleStations(fixtures.stations, api.defaultViewport());
  assert.equal(all.length, 4);
  const panned = api.viewportFor(fixtures.scenarios.find(s => s.id === "panned"));
  assert.deepEqual(api.visibleStations(fixtures.stations, panned).map(s => s.id), ["demo-2"]);
  const empty = api.viewportFor(fixtures.scenarios.find(s => s.id === "panned-empty"));
  assert.equal(api.visibleStations(fixtures.stations, empty).length, 0);
  assert.deepEqual(api.visibleStations(fixtures.stations, api.defaultViewport()), all);
});
test("fresh zero, stale, closed and missing counts stay distinct", () => {
  const station = fixtures.stations[1];
  assert.equal(api.count(station, "docks", 0), 0);
  assert.equal(api.count(station, "docks", 121), null);
  assert.equal(api.count({ ...station, returning: false }, "docks", 0), null);
  assert.equal(api.count({ ...station, docks: null }, "docks", 0), null);
  assert.equal(api.count(station, "docks", -61), null);
});
test("offline scenario retains locations without usable inventory", () => {
  const scenario = fixtures.scenarios.find((s) => s.id === "offline");
  const stations = api.stationsFor(fixtures, scenario);
  assert.equal(stations.length, 4);
  assert.deepEqual(
    stations.map((s) => api.count(s, "docks", scenario.age)),
    [null, null, null, null],
  );
  assert.equal(api.nearby(stations, "docks", scenario.age).length, 0);
});
test("unavailable overrides and mode-specific operation", () => {
  const scenario = fixtures.scenarios.find((s) => s.id === "unavailable");
  const stations = api.stationsFor(fixtures, scenario);
  assert.deepEqual(
    stations.map((s) => api.count(s, "docks", 0)),
    [null, 0, null, 8],
  );
  assert.equal(api.count(stations[0], "bikes", 0), 4);
});
test("empty and failed loads cannot invent demo stations", () => {
  for (const id of ["empty", "error"])
    assert.equal(
      api.stationsFor(
        fixtures,
        fixtures.scenarios.find((s) => s.id === id),
      ).length,
      0,
    );
});
test("e-bike indicators distinguish available, zero, unknown and stale counts", () => {
  assert.deepEqual(
    fixtures.stations.map((s) => api.electricCount(s, 0)),
    [2, 0, 1, null],
  );
  assert.equal(api.electricCount(fixtures.stations[0], 121), null);
  assert.equal(
    api.electricCount({ ...fixtures.stations[0], renting: false }, 0),
    null,
  );
  assert.equal(api.count(fixtures.stations[0], "docks", 0), 12);
});
