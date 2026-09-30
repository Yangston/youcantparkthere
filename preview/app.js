(() => {
  "use strict";
  const { fixtures, report } = window.PARK_DATA;
  const api = window.ParkPreview;
  const $ = (id) => document.getElementById(id);
  const esc = (value) =>
    String(value ?? "").replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  const distance = (s) =>
    api.distance(s) < 1000
      ? `${Math.round(api.distance(s))} m`
      : `${(api.distance(s) / 1000).toFixed(1)} km`;
  let scenario,
    state,
    view = "sandbox",
    baseline = null,
    urls = [];
  const selectedID = new URLSearchParams(location.search).get("scenario");
  const groups = [...new Set(fixtures.scenarios.map((s) => s.group))];
  for (const group of groups) {
    const heading = document.createElement("p");
    heading.className = "group";
    heading.textContent = group;
    $("scenarios").append(heading);
    for (const item of fixtures.scenarios.filter((s) => s.group === group)) {
      const button = document.createElement("button");
      button.dataset.scenario = item.id;
      button.innerHTML = `${esc(item.title)}<span>${report.entries.some((e) => e.id === item.id && e.status === "captured") ? "↗" : "·"}</span>`;
      button.addEventListener("click", () => select(item.id));
      $("scenarios").append(button);
    }
  }
  function select(id) {
    scenario =
      fixtures.scenarios.find((s) => s.id === id) || fixtures.scenarios[0];
    state = {
      mode: scenario.mode,
      page: scenario.page,
      riding: scenario.riding,
      target: scenario.target,
      selected: "demo-0",
      favorites: new Set(),
      suggest: true,
      detect: false,
    };
    $("scenario-title").textContent = scenario.title;
    $("scenario-group").textContent = scenario.group.toUpperCase();
    $("scenario-description").textContent = scenario.description;
    for (const button of $("scenarios").querySelectorAll("button")) {
      button.classList.toggle(
        "active",
        button.dataset.scenario === scenario.id,
      );
      button.setAttribute(
        "aria-current",
        button.dataset.scenario === scenario.id ? "true" : "false",
      );
    }
    $("interaction-note").textContent = "";
    render();
    renderNative();
  }
  const stations = () => api.stationsFor(fixtures, scenario);
  const count = (s, mode = state.mode) => api.count(s, mode, scenario.age);
  const electricCount = (s) => api.electricCount(s, scenario.age);
  function setMode(mode) {
    view = mode;
    $("sandbox-panel").hidden = mode !== "sandbox";
    $("native-panel").hidden = mode !== "native";
    $("sandbox-mode").setAttribute("aria-pressed", mode === "sandbox");
    $("native-mode").setAttribute("aria-pressed", mode === "native");
    renderNative();
  }
  $("sandbox-mode").onclick = () => setMode("sandbox");
  $("native-mode").onclick = () => setMode("native");
  $("reset").onclick = () => select(scenario.id);
  $("watch-size").onchange = () => {
    $("watch").classList.toggle("large", $("watch-size").value === "large");
  };
  function note(message) {
    $("interaction-note").textContent = message;
  }
  function render() {
    const screen = $("watch-screen");
    screen.classList.toggle("large-text", !!scenario.largeText);
    screen.classList.toggle("sheet-screen", state.page !== "map");
    const data = stations();
    $("state").innerHTML = [
      [
        "Mode",
        state.mode === "docks" ? "Parking" : "Bikes",
      ],
      [
        "Data",
        !scenario.data
          ? "Missing"
          : scenario.empty
            ? "Empty feed"
            : scenario.age > 120
              ? "Stale"
              : "Fresh sample",
      ],
      ["Ride", state.riding ? "Active (simulated)" : "Stopped"],
      [
        "Clock shortcut",
        state.riding && state.suggest
          ? "Suggested; OS decides"
          : "Not requested",
      ],
      ["Location", scenario.gps ? "Sample coordinate" : "No GPS"],
      ["Destination", state.target ? "Selected" : "None"],
    ]
      .map(([k, v]) => `<div><dt>${k}</dt><dd>${v}</dd></div>`)
      .join("");
    if (state.page === "map") {
      screen.innerHTML = `<div class="map-screen">
        <div class="sample-map"><svg viewBox="0 0 200 240" preserveAspectRatio="none" aria-hidden="true"><path fill="#344138" d="M0 0h200v240H0z"/><path stroke="#536057" stroke-width="9" d="M-20 100L210 55M-20 170L230 120M50 -20L120 280M145 -20L210 270"/><path stroke="#2b342e" stroke-width="3" d="M-20 100L210 55M-20 170L230 120M50 -20L120 280M145 -20L210 270"/><path fill="#3e5544" d="M15 45h40v30H15zM105 133h35v45h-35z"/><text x="8" y="209" fill="#a6b6ab" font-size="6">SAMPLE MAP</text></svg>
        ${data
          .map((s) => {
            const c = count(s),
              e = electricCount(s);
            return `<button class="pin ${c === null ? "unknown" : c === 0 ? "zero" : c < 3 ? "low" : ""} ${state.target === s.id ? "target" : ""}" data-station="${esc(s.id)}" style="left:${15 + (s.longitude + 79.389) * 6500}%;top:${28 + (43.656 - s.latitude) * 7200}%" aria-label="${esc(s.name)}, ${c === null ? "unknown" : c} ${state.mode}">${c ?? "–"}${state.mode === "bikes" && e > 0 ? "<small>ϟ</small>" : ""}</button>`;
          })
          .join("")}
        ${!scenario.data ? '<div class="map-overlay">Stations unavailable<button id="retry">Retry sample</button></div>' : scenario.empty ? '<div class="map-overlay">No stations in this snapshot</div>' : ""}</div>
        <div class="watch-header"><button id="toggle-mode">${state.mode === "docks" ? "Ⓟ Park" : "♧ Bikes"}</button></div><div class="map-utilities"><button id="gps" aria-label="Recenter">↗</button><button id="settings" aria-label="Ride and settings">⚙</button></div>
        <div class="map-footer">${state.target ? `<button id="target" class="target-label">⚑ ${esc(data.find((s) => s.id === state.target)?.name || "Destination")}</button>` : ""}<div class="map-bottom"><div><div class="watch-demo">DEMO</div><span>${scenario.error ? "Connection issue" : "Sample data · not live"}</span></div><button class="plain" id="ride">${state.riding ? "■ End" : "♧ Ride"}</button></div></div></div>`;
      $("toggle-mode").onclick = () => {
        state.mode = state.mode === "docks" ? "bikes" : "docks";
        render();
      };
      $("gps").onclick = () =>
        note("Sample coordinate only; no browser GPS request.");
      $("settings").onclick = () => {
        state.page = "settings";
        render();
      };
      $("ride").onclick = toggleRide;
      if ($("target")) $("target").onclick = () => openStation(state.target);
      if ($("retry"))
        $("retry").onclick = () => {
          select("docks");
          note("An explicit sample scenario was loaded; no live fallback.");
        };
    } else if (state.page === "detail") {
      const s = data.find((s) => s.id === state.selected) || data[0];
      if (!s) {
        screen.innerHTML =
          '<p class="watch-copy">Station no longer in the feed.</p>';
        return;
      }
      const docks = count(s, "docks"),
        bikes = count(s, "bikes"),
        electric = electricCount(s);
      screen.innerHTML = `<button id="back" class="plain">× Close</button><div class="watch-title">${esc(s.name)}</div><p class="watch-copy">${distance(s)} · straight line</p><div class="detail-counts"><span><b>${docks ?? "–"}</b>Docks</span><span><b>${bikes ?? "–"}</b>Bikes</span><span><b>${electric ?? "–"}</b>E-bikes</span></div><p class="watch-copy">E-bikes are included in total bikes.</p><button class="primary" id="destination" ${state.target !== s.id && (docks ?? 0) === 0 ? "disabled" : ""}>${state.target === s.id ? "Clear destination" : "Make destination"}</button><button class="wide" id="favorite">${state.favorites.has(s.id) ? "Unfavorite" : "Favorite"}</button><button class="wide" id="maps">Open in Apple Maps</button><p class="watch-copy">DEMO · not live. Counts are not reservations.</p>`;
      $("back").onclick = () => {
        state.page = "map";
        render();
      };
      $("destination").onclick = () => {
        state.target = state.target === s.id ? null : s.id;
        state.page = "map";
        render();
      };
      $("favorite").onclick = () => {
        state.favorites.has(s.id)
          ? state.favorites.delete(s.id)
          : state.favorites.add(s.id);
        render();
      };
      $("maps").onclick = () => note("Apple Maps handoff needs a Watch test.");
    } else if (state.page === "onboarding") {
      screen.innerHTML =
        '<div class="watch-title">Ⓟ<br>You Can’t<br>Park There</div><p class="watch-copy">Find a bike. Find an empty dock. Leave your phone in your pocket.</p><p class="watch-copy">Auto-detection works while the app is running, not from a closed app.</p><button class="primary" id="enable">Enable location</button><button class="wide" id="browse">Browse downtown</button>';
      $("enable").onclick = () => {
        state.page = "map";
        render();
        note("Permission simulated; no browser GPS.");
      };
      $("browse").onclick = () => {
        state.page = "map";
        render();
      };
    } else {
      screen.innerHTML = `<button id="back" class="plain">× Close</button><div class="watch-title">Ride & settings</div><button class="wide" id="ride">${state.riding ? "End ride" : "Start ride"}</button><label class="watch-toggle">Detect cycling<input id="detect" type="checkbox" ${state.detect ? "checked" : ""}></label><p class="watch-copy">Only while the app is open. Cannot launch a closed app.</p><label class="watch-toggle">Ride shortcut<input id="suggest" type="checkbox" ${state.suggest ? "checked" : ""}></label><p class="watch-copy">Smart Stack suggestion while Ride is active. watchOS decides whether a clock-screen hint appears.</p><button class="wide" id="refresh">Refresh stations</button>${scenario.error ? `<p class="watch-copy">${esc(scenario.error)}</p>` : ""}<p class="watch-copy">In Bikes mode, lightning means e-bikes are available. Tap a station for the breakdown.</p><p class="watch-copy">Ride uses background location and stops after 90 minutes.</p>`;
      $("back").onclick = () => {
        state.page = "map";
        render();
      };
      $("ride").onclick = toggleRide;
      $("detect").onchange = (e) => {
        state.detect = e.target.checked;
        note("No motion sensing occurs in this preview.");
      };
      $("suggest").onchange = (e) => {
        state.suggest = e.target.checked;
        render();
        note("Preview only. watchOS controls actual Smart Stack placement.");
      };
      $("refresh").onclick = () =>
        note("Fixtures stay fixed. Select another scenario to change data.");
    }
    for (const button of screen.querySelectorAll("[data-station]"))
      button.onclick = () => openStation(button.dataset.station);
    screen.scrollTop = 0;
  }
  function openStation(id) {
    state.selected = id;
    state.page = "detail";
    render();
  }
  function toggleRide() {
    state.riding = !state.riding;
    if (state.riding) {
      state.mode = "docks";
      state.page = "map";
    }
    render();
    note(
      "Ride is simulated. Automatic clock hints must be checked on your Watch.",
    );
  }

  const captured = fixtures.scenarios.filter((s) =>
    report.entries.some((e) => e.id === s.id && e.status === "captured"),
  ).length;
  $("capture-count").textContent =
    `${captured} / ${fixtures.scenarios.length} native states captured`;
  $("native-provenance").textContent =
    report.capturedAt || report.runURL
      ? [
          report.device,
          report.runtime,
          `commit ${report.sha.slice(0, 7)}`,
          report.branch,
          report.capturedAt || "No screenshots produced",
        ]
          .filter(Boolean)
          .join(" · ")
      : "No native build imported. The sandbox is available immediately.";
  if (
    report.runURL &&
    /^https:\/\/github\.com\/Yangston\/youcantparkthere\/actions\/runs\/\d+$/.test(
      report.runURL,
    )
  ) {
    $("run-link").href = report.runURL;
    $("run-link").hidden = false;
  }
  for (const [name, status] of Object.entries(report.checks)) {
    const chip = document.createElement("span");
    chip.className = `check ${status === "success" ? "success" : status === "failure" ? "failure" : ""}`;
    chip.textContent = `${name}: ${status}`;
    $("checks").append(chip);
  }
  function figure(label, source) {
    const el = document.createElement("figure");
    const caption = document.createElement("figcaption");
    caption.textContent = label;
    const image = document.createElement("img");
    image.src = source;
    image.alt = `${scenario.title} — ${label}`;
    el.append(caption, image);
    return el;
  }
  function renderNative() {
    const entry = report.entries.find((e) => e.id === scenario.id);
    const available =
      entry?.status === "captured" &&
      /^screenshots\/[a-z0-9-]+\.png$/.test(entry.file || "");
    $("native-stage").replaceChildren();
    $("native-stage").hidden = !available;
    $("native-empty").hidden = available;
    const old = baseline?.images.get(scenario.id);
    const overlay = !!old && $("compare").value === "wipe";
    $("wipe-control").hidden = !overlay;
    if (!available) return;
    if (overlay) {
      const fig = figure(`Baseline → current · ${scenario.title}`, old);
      const bottom = fig.querySelector("img");
      const stack = document.createElement("div");
      stack.className = "wipe-stack";
      bottom.replaceWith(stack);
      stack.append(bottom);
      const top = document.createElement("img");
      top.src = entry.file;
      top.alt = `Current ${scenario.title}`;
      top.style.clipPath = `inset(0 ${100 - Number($("wipe").value)}% 0 0)`;
      stack.append(top);
      $("native-stage").append(fig);
      top.onload = () => {
        if (
          bottom.complete &&
          (top.naturalWidth !== bottom.naturalWidth ||
            top.naturalHeight !== bottom.naturalHeight)
        ) {
          noteBaseline("Image dimensions differ; use side-by-side comparison.");
          $("compare").value = "side";
          renderNative();
        }
      };
    } else {
      if (old)
        $("native-stage").append(
          figure(`Baseline · ${baseline.sha.slice(0, 7)}`, old),
        );
      $("native-stage").append(
        figure(`Current · ${report.sha.slice(0, 7)}`, entry.file),
      );
    }
    if (baseline && !old)
      noteBaseline("The baseline has no capture for this scenario.");
  }
  function noteBaseline(text) {
    $("baseline-note").textContent = text;
  }
  function clearBaseline() {
    for (const url of urls) URL.revokeObjectURL(url);
    urls = [];
    baseline = null;
    $("baseline").value = "";
    $("clear-baseline").hidden = true;
    noteBaseline(
      "Optional: select an extracted older preview folder for a visual comparison.",
    );
    renderNative();
  }
  $("clear-baseline").onclick = clearBaseline;
  $("compare").onchange = renderNative;
  $("wipe").oninput = renderNative;
  $("saved-baseline").hidden = !window.PARK_DATA.baseline;
  $("saved-baseline").onclick = () => {
    const old = window.PARK_DATA.baseline;
    if (old.device !== report.device || old.runtime !== report.runtime) {
      noteBaseline(
        "Saved baseline uses a different Watch model/runtime. Import a matching baseline ZIP.",
      );
      return;
    }
    clearBaseline();
    const images = new Map(
      old.entries
        .filter(
          (e) =>
            e.status === "captured" &&
            /^screenshots\/[a-z0-9-]+\.png$/.test(e.file || ""),
        )
        .map((e) => [e.id, `baseline/${e.file}`]),
    );
    baseline = { sha: old.sha, images };
    $("clear-baseline").hidden = false;
    noteBaseline(
      `Saved baseline ${old.sha.slice(0, 7)} · ${old.device}. Map tiles and clock can vary.`,
    );
    renderNative();
  };
  $("baseline").onchange = async (event) => {
    try {
      const files = [...event.target.files],
        manifestFile = files.find((f) => f.name === "manifest.json");
      if (!manifestFile || manifestFile.size > 1000000)
        throw Error(
          "Choose an extracted preview folder containing manifest.json.",
        );
      const old = JSON.parse(await manifestFile.text());
      if (
        old.schema !== 1 ||
        !Array.isArray(old.entries) ||
        !/^[a-f0-9]{40}$/.test(old.sha)
      )
        throw Error("Unsupported baseline manifest.");
      if (old.device !== report.device || old.runtime !== report.runtime)
        throw Error(
          "Choose a baseline from the same Watch model and runtime for a meaningful comparison.",
        );
      for (const url of urls) URL.revokeObjectURL(url);
      urls = [];
      const images = new Map();
      for (const entry of old.entries) {
        if (entry.status !== "captured") continue;
        const file = files.find((f) => f.name === `${entry.id}.png`);
        if (file && file.size < 15000000) {
          const url = URL.createObjectURL(file);
          urls.push(url);
          images.set(entry.id, url);
        }
      }
      baseline = { sha: old.sha, images };
      $("clear-baseline").hidden = false;
      noteBaseline(
        `Baseline ${old.sha.slice(0, 7)} · ${old.device}. Map tiles and system clock can vary; compare deliberately.`,
      );
      renderNative();
    } catch (error) {
      noteBaseline(error.message);
    }
  };
  select(selectedID);
  if (location.hash === "#native") setMode("native");
})();
