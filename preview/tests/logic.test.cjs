const {test} = require('node:test');
const assert = require('node:assert/strict');
const api = require('../logic.js');
const fixtures = require('../fixtures.json');
test('fresh zero, stale, closed and missing counts stay distinct', () => {
  const station = fixtures.stations[1];
  assert.equal(api.count(station,'docks',0),0);
  assert.equal(api.count(station,'docks',121),null);
  assert.equal(api.count({...station,returning:false},'docks',0),null);
  assert.equal(api.count({...station,docks:null},'docks',0),null);
  assert.equal(api.count(station,'docks',-61),null);
});
test('offline scenario retains locations without usable inventory', () => {
  const scenario = fixtures.scenarios.find(s=>s.id==='offline');
  const stations = api.stationsFor(fixtures,scenario);
  assert.equal(stations.length,4);
  assert.deepEqual(stations.map(s=>api.count(s,'docks',scenario.age)),[null,null,null,null]);
  assert.equal(api.nearby(stations,'docks',scenario.age).length,0);
});
test('unavailable overrides and mode-specific operation', () => {
  const scenario = fixtures.scenarios.find(s=>s.id==='unavailable');
  const stations = api.stationsFor(fixtures,scenario);
  assert.deepEqual(stations.map(s=>api.count(s,'docks',0)),[null,0,null,8]);
  assert.equal(api.count(stations[0],'bikes',0),4);
});
test('empty and failed loads cannot invent demo stations', () => {
  for(const id of ['empty','error']) assert.equal(api.stationsFor(fixtures,fixtures.scenarios.find(s=>s.id===id)).length,0);
});
test('nearby filter applies availability and distance sorting', () => {
  const stations=api.nearby(fixtures.stations,'docks',0,5);
  assert.deepEqual(stations.map(s=>s.id),['demo-0','demo-3']);
});
