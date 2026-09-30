/* Shared fixture semantics for the interaction sketch. ParkCore remains authoritative. */
(function (root) {
  function stationsFor(fixtures, scenario) {
    if (!scenario.data || scenario.empty) return [];
    return fixtures.stations.map((s) => ({
      ...s,
      ...(scenario.overrides?.[s.id] || {}),
    }));
  }
  function count(station, mode, age) {
    if (
      age < -60 ||
      age > 120 ||
      !station.installed ||
      !station[mode === "docks" ? "returning" : "renting"]
    )
      return null;
    return station[mode] ?? null;
  }
  function electricCount(station, age) {
    if (age < -60 || age > 120 || !station.installed || !station.renting) return null;
    return station.electricBikes ?? null;
  }
  function distance(station) {
    const radians = Math.PI / 180;
    const a =
      Math.sin(((station.latitude - 43.6532) * radians) / 2) ** 2 +
      Math.cos(43.6532 * radians) *
        Math.cos(station.latitude * radians) *
        Math.sin(((station.longitude + 79.3832) * radians) / 2) ** 2;
    return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
  function nearby(
    stations,
    mode,
    age,
    minimum = 1,
    includeUnavailable = false,
  ) {
    return stations
      .filter(
        (s) =>
          distance(s) <= 5000 &&
          (includeUnavailable || (count(s, mode, age) ?? -1) >= minimum),
      )
      .sort((a, b) => distance(a) - distance(b) || a.id.localeCompare(b.id));
  }
  function defaultViewport() {
    return { center: { latitude: 43.6532, longitude: -79.3832 }, latitudeSpan: 0.012, longitudeSpan: 0.016 };
  }
  function viewportFor(scenario) {
    return scenario.viewport ? structuredClone(scenario.viewport) : defaultViewport();
  }
  function visibleStations(stations, viewport) {
    return stations.filter(s => {
      const longitude = Math.abs(((s.longitude - viewport.center.longitude + 540) % 360) - 180);
      return Math.abs(s.latitude - viewport.center.latitude) <= viewport.latitudeSpan * 0.6
        && longitude <= viewport.longitudeSpan * 0.6;
    });
  }
  function project(station, viewport) {
    return { x: 50 + (station.longitude - viewport.center.longitude) / viewport.longitudeSpan * 100,
      y: 50 - (station.latitude - viewport.center.latitude) / viewport.latitudeSpan * 100 };
  }
  const api = { stationsFor, count, electricCount, distance, nearby, defaultViewport, viewportFor, visibleStations, project };
  if (typeof module !== "undefined") module.exports = api;
  root.ParkPreview = api;
})(globalThis);
