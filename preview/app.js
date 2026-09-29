(() => {
  'use strict';
  const {fixtures, report} = window.PARK_DATA;
  const api = window.ParkPreview;
  const $ = id => document.getElementById(id);
  const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const distance = s => api.distance(s) < 1000 ? `${Math.round(api.distance(s))} m` : `${(api.distance(s)/1000).toFixed(1)} km`;
  let scenario, state, view = 'sandbox', baseline = null, urls = [];
  const selectedID = new URLSearchParams(location.search).get('scenario');
  const groups = [...new Set(fixtures.scenarios.map(s=>s.group))];
  for(const group of groups){
    const heading=document.createElement('p'); heading.className='group'; heading.textContent=group; $('scenarios').append(heading);
    for(const item of fixtures.scenarios.filter(s=>s.group===group)){
      const button=document.createElement('button'); button.dataset.scenario=item.id;
      button.innerHTML=`${esc(item.title)}<span>${report.entries.some(e=>e.id===item.id&&e.status==='captured')?'↗':'·'}</span>`;
      button.addEventListener('click',()=>select(item.id)); $('scenarios').append(button);
    }
  }
  function select(id){
    scenario=fixtures.scenarios.find(s=>s.id===id)||fixtures.scenarios[0];
    state={mode:scenario.mode,page:scenario.page,riding:scenario.riding,target:scenario.target,selected:'demo-0',favorites:new Set(),onlyFavorites:false,showUnavailable:false,minimum:1,detect:false};
    $('scenario-title').textContent=scenario.title; $('scenario-group').textContent=scenario.group.toUpperCase(); $('scenario-description').textContent=scenario.description;
    for(const button of $('scenarios').querySelectorAll('button')){button.classList.toggle('active',button.dataset.scenario===scenario.id);button.setAttribute('aria-current',button.dataset.scenario===scenario.id?'true':'false');}
    $('interaction-note').textContent=''; render(); renderNative();
  }
  const stations = () => api.stationsFor(fixtures,scenario);
  const count = (s,mode=state.mode) => api.count(s,mode,scenario.age);
  function setMode(mode){view=mode; $('sandbox-panel').hidden=mode!=='sandbox';$('native-panel').hidden=mode!=='native';$('sandbox-mode').setAttribute('aria-pressed',mode==='sandbox');$('native-mode').setAttribute('aria-pressed',mode==='native');renderNative();}
  $('sandbox-mode').onclick=()=>setMode('sandbox'); $('native-mode').onclick=()=>setMode('native'); $('reset').onclick=()=>select(scenario.id);
  $('watch-size').onchange=()=>{$('watch').classList.toggle('large',$('watch-size').value==='large');};
  for(const button of document.querySelectorAll('[data-page]')) button.onclick=()=>{state.page=button.dataset.page;render();};
  function note(message){$('interaction-note').textContent=message;}
  function render(){
    const screen=$('watch-screen'); screen.classList.toggle('large-text',!!scenario.largeText);
    const data=stations();
    $('state').innerHTML=[['Mode',state.mode==='docks'?'Parking':'Bikes'],['Data',!scenario.data?'Missing':scenario.empty?'Empty feed':scenario.age>120?'Stale':'Fresh sample'],['Ride',state.riding?'Active (simulated)':'Stopped'],['Location',scenario.gps?'Sample coordinate':'No GPS'],['Destination',state.target?'Selected':'None']].map(([k,v])=>`<div><dt>${k}</dt><dd>${v}</dd></div>`).join('');
    for(const button of document.querySelectorAll('[data-page]')) button.classList.toggle('selected',button.dataset.page===state.page);
    if(state.page==='map'){
      screen.innerHTML=`<div class="map-screen"><div class="watch-header"><button class="plain" id="toggle-mode">${state.mode==='docks'?'Ⓟ Park':'♧ Bikes'}</button><button class="plain" id="gps" aria-label="Recenter">↗</button></div><div class="watch-demo">DEMO · sample stations</div><div class="sample-map"><svg viewBox="0 0 200 160" preserveAspectRatio="none" aria-hidden="true"><path fill="#344138" d="M0 0h200v160H0z"/><path stroke="#536057" stroke-width="9" d="M-20 70L210 25M-20 130L230 80M50 -20L100 200M145 -20L190 190"/><path stroke="#2b342e" stroke-width="3" d="M-20 70L210 25M-20 130L230 80M50 -20L100 200M145 -20L190 190"/><path fill="#3e5544" d="M15 7h40v25H15zM110 93h33v40h-33z"/><text x="5" y="154" fill="#85958a" font-size="7">SAMPLE MAP</text></svg>${data.map(s=>{const c=count(s);return `<button class="pin ${c===null?'unknown':c===0?'zero':c<3?'low':''} ${state.target===s.id?'target':''}" data-station="${esc(s.id)}" style="left:${15+(s.longitude+79.389)*6500}%;top:${15+(43.656-s.latitude)*11000}%" aria-label="${esc(s.name)}, ${c===null?'unknown':c} ${state.mode}">${c??'–'}</button>`;}).join('')}${!scenario.data?'<div class="map-overlay">Stations unavailable<button id="retry">Retry sample</button></div>':''}</div>${state.target?`<button id="target" class="plain target-label">⚑ ${esc(data.find(s=>s.id===state.target)?.name||'Destination')}</button>`:''}<div class="map-bottom"><span>DEMO · not live</span><button class="plain" id="ride">${state.riding?'■ End':'♧ Ride'}</button></div>${scenario.error?'<p class="map-error">Connection issue · see settings</p>':''}</div>`;
      $('toggle-mode').onclick=()=>{state.mode=state.mode==='docks'?'bikes':'docks';render();}; $('gps').onclick=()=>note('Sample coordinate only. The browser does not request your location.');
      $('ride').onclick=toggleRide;
      if($('target')) $('target').onclick=()=>openStation(state.target);
      if($('retry')) $('retry').onclick=()=>{select('docks');note('Loaded an explicit sample scenario. No live request was made.');};
    }else if(state.page==='nearby'){
      const nearby=api.nearby(data,state.mode,scenario.age,state.mode==='docks'?state.minimum:1,state.showUnavailable).filter(s=>!state.onlyFavorites||state.favorites.has(s.id));
      screen.innerHTML=`<div class="watch-list"><div class="watch-title">Nearby ${state.mode==='docks'?'parking':'bikes'}</div><p class="watch-copy">DEMO · straight-line distances</p><label class="watch-toggle">Favorites<input id="favorites-only" type="checkbox" ${state.onlyFavorites?'checked':''}></label>${nearby.map(s=>`<button class="row" data-station="${esc(s.id)}"><span>${esc(s.name)}<small>${distance(s)}</small></span><b>${count(s)??'–'}</b></button>`).join('')||`<p class="watch-copy">${scenario.age>120||!scenario.data?'No fresh availability. Check connection or show unavailable stations.':'No matches within 5 km. Try showing unavailable stations.'}</p>`}<label class="watch-toggle">Show unavailable<input id="unavailable" type="checkbox" ${state.showUnavailable?'checked':''}></label></div>`;
      $('favorites-only').onchange=e=>{state.onlyFavorites=e.target.checked;render();}; $('unavailable').onchange=e=>{state.showUnavailable=e.target.checked;render();};
    }else if(state.page==='detail'){
      const s=data.find(s=>s.id===state.selected)||data[0];
      if(!s){screen.innerHTML='<p class="watch-copy">Station no longer in the feed.</p>';return;}
      const docks=count(s,'docks'),bikes=count(s,'bikes');
      screen.innerHTML=`<button id="back" class="plain">‹ Back</button><div class="watch-title">${esc(s.name)}</div><p class="watch-copy">${distance(s)} · straight line</p><div class="detail-counts"><span><b>${docks??'–'}</b>Docks</span><span><b>${bikes??'–'}</b>Bikes</span></div>${docks===null?'<p class="watch-copy">Availability unknown or station unavailable.</p>':''}<button class="primary" id="destination" ${state.target!==s.id&&(docks??0)===0?'disabled':''}>${state.target===s.id?'Clear destination':'Make destination'}</button><button class="wide" id="favorite">${state.favorites.has(s.id)?'Unfavorite':'Favorite'}</button><button class="wide" id="maps">Open in Apple Maps</button><p class="watch-copy">DEMO · not live</p><p class="watch-copy">Counts are not reservations. Verify the dock’s return signal.</p>`;
      $('back').onclick=()=>{state.page='map';render();};$('destination').onclick=()=>{state.target=state.target===s.id?null:s.id;state.page='map';render();};$('favorite').onclick=()=>{state.favorites.has(s.id)?state.favorites.delete(s.id):state.favorites.add(s.id);render();};$('maps').onclick=()=>note('Apple Maps handoff must be checked on the Watch; this sandbox stays local.');
    }else if(state.page==='onboarding'){
      screen.innerHTML='<div class="watch-title">Ⓟ<br>You Can’t<br>Park There</div><p class="watch-copy">Find a bike. Find an empty dock. Leave your phone in your pocket.</p><p class="watch-copy">Auto-detection works only while this app is running—not from a closed app.</p><button class="primary" id="enable">Enable location</button><button class="wide" id="browse">Browse downtown</button><p class="watch-copy">Not affiliated with Bike Share Toronto. Availability can change.</p>';
      $('enable').onclick=()=>{state.page='map';render();note('Permission prompt simulated. No browser GPS access.');};$('browse').onclick=()=>{state.page='map';render();};
    }else{
      screen.innerHTML=`<div class="watch-title">Ride & settings</div><button class="wide" id="ride">${state.riding?'End ride':'Start ride'}</button><label class="watch-toggle">Detect cycling<input id="detect" type="checkbox" ${state.detect?'checked':''}></label><p class="watch-copy">${state.detect?'Enabled in sketch only':'Off'}. Works while the app is open. Cannot launch a closed app.</p><label class="watch-toggle">Minimum docks<select id="minimum">${[1,3,5].map(n=>`<option ${n===state.minimum?'selected':''}>${n}</option>`).join('')}</select></label><p class="watch-copy">Filters the list, not the map.</p><button class="wide" id="refresh">Refresh stations</button>${scenario.error?`<p class="watch-copy">${esc(scenario.error)}</p>`:''}<div class="watch-title">Keep the map handy</div><p class="watch-copy">Watch Settings → General → Return to Clock → this app → After 1 hour.</p><p class="watch-copy">Ride uses background location and stops after 90 minutes.</p>`;
      $('ride').onclick=toggleRide;$('detect').onchange=e=>{state.detect=e.target.checked;note('No motion sensing occurs in this preview.');};$('minimum').onchange=e=>{state.minimum=Number(e.target.value);};$('refresh').onclick=()=>note('Sample fixtures stay fixed for repeatable comparisons. Choose another scenario to change data.');
    }
    for(const button of screen.querySelectorAll('[data-station]'))button.onclick=()=>openStation(button.dataset.station);
    screen.scrollTop=0;
  }
  function openStation(id){state.selected=id;state.page='detail';render();}
  function toggleRide(){state.riding=!state.riding;if(state.riding){state.mode='docks';state.page='map';}render();note('Ride state is simulated. Background execution and haptics require a device test.');}

  const captured=report.entries.filter(e=>e.status==='captured').length;
  $('capture-count').textContent=`${captured} / ${fixtures.scenarios.length} native states captured`;
  $('native-provenance').textContent=report.capturedAt?`${report.device} · ${report.runtime} · commit ${report.sha.slice(0,7)} · ${report.branch} · ${report.capturedAt}`:'No native build imported. The sandbox is available immediately.';
  if(report.runURL&&/^https:\/\/github\.com\/Yangston\/youcantparkthere\/actions\/runs\/\d+$/.test(report.runURL)){$('run-link').href=report.runURL;$('run-link').hidden=false;}
  for(const [name,status]of Object.entries(report.checks)){const chip=document.createElement('span');chip.className=`check ${status==='success'?'success':status==='failure'?'failure':''}`;chip.textContent=`${name}: ${status}`;$('checks').append(chip);}
  function figure(label,source){const el=document.createElement('figure');const caption=document.createElement('figcaption');caption.textContent=label;const image=document.createElement('img');image.src=source;image.alt=`${scenario.title} — ${label}`;el.append(caption,image);return el;}
  function renderNative(){
    const entry=report.entries.find(e=>e.id===scenario.id);const available=entry?.status==='captured'&&/^screenshots\/[a-z0-9-]+\.png$/.test(entry.file||'');
    $('native-stage').replaceChildren();$('native-stage').hidden=!available;$('native-empty').hidden=available;
    const old=baseline?.images.get(scenario.id);const overlay=!!old&&$('compare').value==='wipe';$('wipe-control').hidden=!overlay;
    if(!available)return;
    if(overlay){
      const fig=figure(`Baseline → current · ${scenario.title}`,old);const bottom=fig.querySelector('img');const stack=document.createElement('div');stack.className='wipe-stack';bottom.replaceWith(stack);stack.append(bottom);const top=document.createElement('img');top.src=entry.file;top.alt=`Current ${scenario.title}`;top.style.clipPath=`inset(0 ${100-Number($('wipe').value)}% 0 0)`;stack.append(top);$('native-stage').append(fig);
      top.onload=()=>{if(bottom.complete&&(top.naturalWidth!==bottom.naturalWidth||top.naturalHeight!==bottom.naturalHeight)){noteBaseline('Image dimensions differ; use side-by-side comparison.');$('compare').value='side';renderNative();}};
    }else{
      if(old)$('native-stage').append(figure(`Baseline · ${baseline.sha.slice(0,7)}`,old));
      $('native-stage').append(figure(`Current · ${report.sha.slice(0,7)}`,entry.file));
    }
    if(baseline&&!old)noteBaseline('The baseline has no capture for this scenario.');
  }
  function noteBaseline(text){$('baseline-note').textContent=text;}
  function clearBaseline(){for(const url of urls)URL.revokeObjectURL(url);urls=[];baseline=null;$('baseline').value='';$('clear-baseline').hidden=true;noteBaseline('Optional: select an extracted older preview folder for a visual comparison.');renderNative();}
  $('clear-baseline').onclick=clearBaseline;$('compare').onchange=renderNative;$('wipe').oninput=renderNative;
  $('baseline').onchange=async event=>{
    try{
      const files=[...event.target.files],manifestFile=files.find(f=>f.name==='manifest.json');
      if(!manifestFile||manifestFile.size>1000000)throw Error('Choose an extracted preview folder containing manifest.json.');
      const old=JSON.parse(await manifestFile.text());
      if(old.schema!==1||!Array.isArray(old.entries)||!/^[a-f0-9]{40}$/.test(old.sha))throw Error('Unsupported baseline manifest.');
      if(old.device!==report.device||old.runtime!==report.runtime)throw Error('Choose a baseline from the same Watch model and runtime for a meaningful comparison.');
      for(const url of urls)URL.revokeObjectURL(url);urls=[];
      const images=new Map();for(const entry of old.entries){if(entry.status!=='captured')continue;const file=files.find(f=>f.name===`${entry.id}.png`);if(file&&file.size<15000000){const url=URL.createObjectURL(file);urls.push(url);images.set(entry.id,url);}}
      baseline={sha:old.sha,images};$('clear-baseline').hidden=false;noteBaseline(`Baseline ${old.sha.slice(0,7)} · ${old.device}. Map tiles and system clock can vary; compare deliberately.`);renderNative();
    }catch(error){noteBaseline(error.message);}
  };
  select(selectedID);if(location.hash==='#native')setMode('native');
})();
