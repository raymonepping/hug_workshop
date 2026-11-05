/* Public viewer: every value is rendered as text, and health.unlocked is authoritative. */
const $ = id => document.getElementById(id);
let apiBase = 'http://127.0.0.1:13004';
let limit = 32;
let generation = 0;
const labels = {
  ready: ['Vault unlocked', 'The application authenticated through AppRole and read its database credentials from Vault.'],
  baseline: ['Baseline connected', 'Environment credentials work. This does not complete the Vault checkpoint.'],
  exercise_incomplete: ['Exercise incomplete', 'Complete the tracked Vault reader, rebuild, and refresh.'],
  vault_denied: ['Vault access denied', 'The application could not authenticate or read its approved secret.'],
  vault_unavailable: ['Vault unavailable', 'Restore Vault connectivity, then reconfigure if its dev server restarted.'],
  db_unavailable: ['Database unavailable', 'Check service readiness and the database configuration.'],
  configuration_error: ['Configuration needed', 'Run the configuration stage and check your selected instance.'],
};
function validBase(value) {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) throw Error('Invalid API URL');
  return url.href.replace(/\/+$/, '');
}
function clearData() { $('items').replaceChildren(); $('reveal').hidden = true; $('reveal').textContent = ''; $('count').textContent = '0 records'; }
async function get(path) {
  const res = await fetch(apiBase + path, { cache: 'no-store', signal: AbortSignal.timeout(8000) });
  if (!res.ok) throw Error('API request failed');
  return res.json();
}
async function refresh() {
  const ticket = ++generation; clearData(); $('error').textContent = ''; $('refresh').disabled = true;
  $('state').textContent = 'Checking'; $('empty').textContent = 'Checking readiness…';
  try {
    const health = await get('/health'); if (ticket !== generation) return;
    const baseline = health.mode === 'baseline' && health.dbReady === true;
    const authorized = health.unlocked === true && health.dbReady === true;
    const state = authorized ? 'ready' : baseline ? 'baseline' : (health.state === 'ready' ? 'vault_denied' : health.state);
    const [label, explanation] = labels[state] || ['Locked', 'Check the lab configuration.'];
    $('state').textContent = label; $('state').className = 'badge ' + (authorized ? 'ready' : baseline ? 'baseline' : 'locked');
    $('explanation').textContent = explanation;
    $('database').textContent = health.dbReady ? 'Ready' : 'Not ready';
    $('source').textContent = health.channel || 'None'; $('authorization').textContent = authorized ? 'Unlocked' : 'Locked';
    $('health').textContent = JSON.stringify(Object.fromEntries(['ok', 'dbReady', 'mode', 'channel', 'unlocked', 'state'].map(k => [k, health[k]])), null, 2);
    if (!authorized && !baseline) { $('empty').textContent = 'No authorized data to display.'; return; }
    const data = await get('/api/items?limit=' + limit); if (ticket !== generation) return;
    const rows = Array.isArray(data.items) ? data.items : [];
    for (const row of rows) {
      const tr = document.createElement('tr');
      for (const key of ['id', 'idx', 'title']) { const td = document.createElement('td'); td.textContent = String(row[key] ?? ''); tr.append(td); }
      $('items').append(tr);
    }
    $('count').textContent = rows.length + ' records'; $('empty').textContent = rows.length ? '' : 'No records found; run the seed stage.';
    if (authorized && rows.length) { $('reveal').textContent = rows.map(r => String(r.title || '').slice(0, 1)).join(''); $('reveal').hidden = false; }
  } catch {
    if (ticket !== generation) return;
    clearData(); $('state').textContent = 'API unavailable'; $('state').className = 'badge locked';
    $('database').textContent = 'Unknown'; $('source').textContent = 'None'; $('authorization').textContent = 'Locked';
    $('empty').textContent = 'No data available.'; $('health').textContent = 'Unavailable';
    $('error').textContent = 'Could not complete the API check. Verify the backend URL and services.';
  } finally { if (ticket === generation) $('refresh').disabled = false; }
}
$('api-form').addEventListener('submit', e => {
  e.preventDefault();
  try { apiBase = validBase($('api').value.trim()); localStorage.setItem('workshopApi', apiBase); refresh(); }
  catch { $('error').textContent = 'Enter an HTTP or HTTPS URL without credentials, query parameters, or fragments.'; }
});
$('refresh').addEventListener('click', refresh);
window.addEventListener('keydown', e => { if (e.key.toLowerCase() === 'r' && !e.target.closest('input,textarea,select,[contenteditable]')) { e.preventDefault(); refresh(); } });
(async () => {
  try { const c = await (await fetch('/config.json')).json(); apiBase = c.apiBase || apiBase; limit = c.itemsLimit || 32; } catch { /* Defaults remain visible. */ }
  try { apiBase = validBase(new URLSearchParams(location.search).get('api') || localStorage.getItem('workshopApi') || apiBase); } catch { /* Ignore invalid persisted input. */ }
  $('api').value = apiBase; refresh();
})();
