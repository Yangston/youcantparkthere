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
  function loadFavorites() {
    if (scenario.favorites) return new Set(scenario.favorites);
    try { return new Set(JSON.parse(localStorage.getItem("park-preview-favorites") || "[]")); }
    catch { return new Set(); }
  }
  function select(id) {
    scenario =
      fixtures.scenarios.find((s) => s.id === id) || fixtures.scenarios[0];
    state = {
      mode: scenario.mode,
      page: scenario.page,
      viewport: api.viewportFor(scenario),
      cycling: scenario.cycling,
      selected: "demo-0",
      favorites: loadFavorites(),
      suggest: true,
      detect: !!scenario.cycling,
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
    // Settings uses the persistent screen as its swipe surface. Clear those
    // handlers before rendering Map so a later map drag cannot change pages.
    screen.onpointerdown = screen.onpointerup = screen.onpointercancel = null;
    screen.classList.toggle("large-text", !!scenario.largeText);
    screen.classList.toggle("sheet-screen", !["map", "settings"].includes(state.page));
    screen.classList.toggle("settings-page", state.page === "settings");
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
      ["Cycling", state.cycling ? "Detected (sample)" : "Not detected"],
      [
        "Clock shortcut",
        state.cycling && state.suggest
          ? "Suggested; OS decides"
          : "Not requested",
      ],
      ["Location", scenario.gps ? "Sample coordinate" : "No GPS"],
      ["Favourites", state.favorites.size],
    ]
      .map(([k, v]) => `<div><dt>${k}</dt><dd>${v}</dd></div>`)
      .join("");
    if (state.page === "map") {
      screen.innerHTML = `<div class="map-screen"><div class="map-canvas">
        <div class="sample-map"><svg viewBox="0 0 200 240" preserveAspectRatio="none" aria-hidden="true"><path fill="#344138" d="M0 0h200v240H0z"/><path stroke="#536057" stroke-width="9" d="M-20 100L210 55M-20 170L230 120M50 -20L120 280M145 -20L210 270"/><path stroke="#2b342e" stroke-width="3" d="M-20 100L210 55M-20 170L230 120M50 -20L120 280M145 -20L210 270"/><path fill="#3e5544" d="M15 45h40v30H15zM105 133h35v45h-35z"/><text x="8" y="209" fill="#a6b6ab" font-size="6">SAMPLE MAP</text></svg>
        <div class="sample-pins"></div>
        ${scenario.empty ? '<div class="map-overlay">No stations in this snapshot</div>' : ""}</div>
        ${!scenario.data ? '<div class="map-overlay"><button id="retry">Retry stations</button></div>' : ""}
        </div>
        <div class="bottom-navigation"><div class="map-bottom"><div><span>${scenario.data ? "DEMO \u00b7 not live" : "No station data"}</span></div><button id="gps" aria-label="Recenter"><span>\u2197</span></button><button id="toggle-mode"><span>${state.mode === "docks" ? "Park" : "Bikes"}</span></button></div></div></div>`;
      if ($("toggle-mode")) $("toggle-mode").onclick = () => {
        state.mode = state.mode === "docks" ? "bikes" : "docks";
        render();
      };
      if ($("gps")) $("gps").onclick = () => {
        state.viewport = api.defaultViewport();
        renderPins();
        note("Recentered on the sample location; no browser GPS request.");
      };
      renderPins();
      bindMapPan(screen.querySelector(".sample-map"));
      bindPageSwipe(screen.querySelector(".bottom-navigation"));
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
        bikes = api.standardCount(s, scenario.age),
        electric = electricCount(s);
      screen.innerHTML = `<button id="back" class="plain">\u00d7 Close</button><div class="watch-title">${esc(s.name)}</div><p class="watch-copy">${distance(s)}</p><div class="detail-counts"><span><b>${docks ?? "\u2013"}</b>Docks</span><span><b>${bikes ?? "\u2013"}</b>Bikes</span><span><b>${electric ?? "\u2013"}</b>E-bikes</span></div><button class="primary" id="favorite">${state.favorites.has(s.id) ? "Unfavourite" : "Favourite"}</button><p class="watch-copy">DEMO \u00b7 not live</p>`;
      $("back").onclick = () => {
        state.page = "map";
        render();
      };
      $("favorite").onclick = () => {
        state.favorites.has(s.id)
          ? state.favorites.delete(s.id)
          : state.favorites.add(s.id);
        try { localStorage.setItem("park-preview-favorites", JSON.stringify([...state.favorites])); } catch {}
        render();
      };
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
      screen.innerHTML = `<div class="settings-content"><div class="watch-title">Settings</div><label class="watch-toggle">Automatic cycling<input id="detect" type="checkbox" ${state.detect ? "checked" : ""}></label><p class="watch-copy">${state.cycling ? "Cycling detected (sample)." : "Not cycling (sample)."} Detection starts while the app can run. It cannot wake a closed app.</p><p class="watch-copy">Stops after sustained non-cycling activity. Turn detection off to stop immediately.</p><label class="watch-toggle">Cycling shortcut<input id="suggest" type="checkbox" ${state.suggest ? "checked" : ""}></label><p class="watch-copy">Requests a Smart Stack suggestion after cycling is detected. watchOS controls placement and clock hints.</p><button class="wide" id="refresh">Refresh stations</button>${scenario.error ? `<p class="watch-copy">${esc(scenario.error)}</p>` : ""}<p class="watch-copy">Lightning means e-bikes are available.</p><p class="watch-copy">Automatic navigation stops after 90 minutes. No workout is recorded.</p><div class="watch-title">Legal &amp; data</div><p class="watch-copy">Apple Maps terms. Data: Bike Share Toronto / Toronto Parking Authority (GBFS). Unofficial app; no account, analytics, or location upload to our own server.</p></div><div class="bottom-navigation"><div class="settings-swipe-hint">Swipe right for map</div></div>`;
      bindPageSwipe(screen.querySelector(".settings-content"));
      bindPageSwipe(screen.querySelector(".bottom-navigation"));
      $("detect").onchange = (e) => {
        state.detect = e.target.checked;
        if (!state.detect) state.cycling = false;
        render();
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
    if (["map", "settings"].includes(state.page)) {
      screen.querySelector(".bottom-navigation").insertAdjacentHTML("beforeend", `<div class="watch-pages"><button aria-label="Map page" aria-current="${state.page === "map"}"><span></span></button><button aria-label="Settings page" aria-current="${state.page === "settings"}"><span></span></button></div>`);
      screen.querySelectorAll(".watch-pages button").forEach((button, index) => {
        button.onclick = () => { state.page = index ? "settings" : "map"; render(); };
      });
    }
    screen.scrollTop = 0;
  }
  function renderPins() {
    const layer = $("watch-screen").querySelector(".sample-pins");
    if (!layer) return;
    const visible = api.visibleStations(stations(), state.viewport);
    layer.innerHTML = visible.map(s => {
      const c = count(s), e = electricCount(s), point = api.project(s, state.viewport);
      return `<button class="pin ${c === null ? "unknown" : c === 0 ? "zero" : c < 3 ? "low" : ""} ${state.favorites.has(s.id) ? "favorite" : ""}" data-station="${esc(s.id)}" style="left:${point.x}%;top:${point.y}%" aria-label="${esc(s.name)}, ${c ?? "unknown"} ${state.mode}${state.favorites.has(s.id) ? ", favourite" : ""}">${c ?? "\u2013"}${state.mode === "bikes" && e > 0 ? "<small>\u03df</small>" : ""}</button>`;
    }).join("");
    layer.querySelectorAll("button").forEach(button => { button.onclick = () => openStation(button.dataset.station); });
    $("interaction-note").textContent = `${visible.length} sample markers rendered. Drag the map to browse; swipe the bottom strip for Settings.`;
  }
  function bindMapPan(map) {
    let drag = null;
    map.onpointerdown = event => {
      drag = { x: event.clientX, y: event.clientY, viewport: structuredClone(state.viewport), moved: false };
    };
    map.onpointermove = event => {
      if (!drag) return;
      const dx = event.clientX - drag.x, dy = event.clientY - drag.y;
      if (!drag.moved && Math.hypot(dx, dy) < 5) return;
      if (!drag.moved) map.setPointerCapture(event.pointerId);
      drag.moved = true;
      const rect = map.getBoundingClientRect();
      state.viewport = { ...drag.viewport, center: {
        latitude: Math.max(-85, Math.min(85, drag.viewport.center.latitude + dy / rect.height * drag.viewport.latitudeSpan)),
        longitude: ((drag.viewport.center.longitude - dx / rect.width * drag.viewport.longitudeSpan + 540) % 360) - 180
      }};
      renderPins();
    };
    map.onpointerup = event => {
      if (drag?.moved) {
        if (map.hasPointerCapture(event.pointerId)) map.releasePointerCapture(event.pointerId);
      }
      drag = null;
    };
    map.onpointercancel = () => { drag = null; };
  }
  function bindPageSwipe(surface) {
    let start;
    surface.onpointerdown = e => { start = { x: e.clientX, y: e.clientY }; };
    surface.onpointermove = e => {
      if (!start) return;
      const dx = e.clientX - start.x, dy = e.clientY - start.y;
      if (Math.abs(dx) >= 12 && Math.abs(dx) > Math.abs(dy) * 1.5) {
        surface.setPointerCapture(e.pointerId);
      }
    };
    surface.onpointerup = e => {
      if (!start) return;
      const dx = e.clientX - start.x, dy = e.clientY - start.y;
      start = null;
      if (surface.hasPointerCapture(e.pointerId)) surface.releasePointerCapture(e.pointerId);
      if (Math.abs(dx) < 35 || Math.abs(dx) < Math.abs(dy) * 1.5) return;
      if (state.page === "map" && dx < 0) state.page = "settings";
      else if (state.page === "settings" && dx > 0) state.page = "map";
      else return;
      e.preventDefault();
      render();
    };
    surface.onpointercancel = () => { start = null; };
  }
  function openStation(id) {
    state.selected = id;
    state.page = "detail";
    render();
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
