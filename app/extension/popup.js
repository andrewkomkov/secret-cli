// Build a Netscape cookie jar from the cookies of the active tab and POST it to the local
// secret-bridge daemon (127.0.0.1). The cookie values go only into the request body.
const statusEl = document.getElementById('status');

function show(text, ok) {
  statusEl.textContent = text;
  statusEl.className = ok ? 'ok' : 'err';
}

// One line per cookie: domain, include-subdomains, path, secure, expiry, name, value.
// HttpOnly cookies get the #HttpOnly_ prefix. A session cookie has expiry 0.
function buildJar(cookies) {
  const lines = ['# Netscape HTTP Cookie File'];
  for (const c of cookies) {
    const domain = (c.httpOnly ? '#HttpOnly_' : '') + c.domain;
    const sub = c.domain.startsWith('.') ? 'TRUE' : 'FALSE';
    const secure = c.secure ? 'TRUE' : 'FALSE';
    const expiry = c.session || !c.expirationDate ? 0 : Math.floor(c.expirationDate);
    lines.push([domain, sub, c.path || '/', secure, expiry, c.name, c.value].join('\t'));
  }
  return lines.join('\n') + '\n';
}

async function send() {
  const btn = document.getElementById('send');
  btn.disabled = true;
  try {
    const cfg = await browser.storage.local.get(['token', 'name', 'port']);
    if (!cfg.token || !cfg.name) {
      show(t('errNoConfig'), false);
      return;
    }
    const port = cfg.port || 17659;
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    const tab = tabs[0];
    if (!tab || !tab.url || !/^https?:/.test(tab.url)) {
      show(t('errNoPage'), false);
      return;
    }
    const host = new URL(tab.url).hostname;
    // A domain match includes the subdomains and the parent-domain cookies of the host.
    const cookies = await browser.cookies.getAll({ domain: host });
    if (!cookies.length) {
      show(t('errNoCookies', [host]), false);
      return;
    }
    const res = await fetch('http://127.0.0.1:' + port + '/jar?as=' + encodeURIComponent(cfg.name), {
      method: 'POST',
      headers: { 'X-Secret-Token': cfg.token, 'Content-Type': 'text/plain' },
      body: buildJar(cookies)
    });
    if (res.ok) {
      show(t('stored', [String(cookies.length), host, cfg.name]), true);
    } else {
      show(t('errRefused', [String(res.status), (await res.text()).trim()]), false);
    }
  } catch (e) {
    show(t('errFailed', [e.message]), false);
  } finally {
    btn.disabled = false;
  }
}

document.getElementById('send').addEventListener('click', send);
document.getElementById('opts').addEventListener('click', (e) => {
  e.preventDefault();
  browser.runtime.openOptionsPage();
});
browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
  try { document.getElementById('site').textContent = new URL(tabs[0].url).hostname; } catch (e) {}
});
