const $ = (id) => document.getElementById(id);

browser.storage.local.get(['token', 'name', 'port']).then((cfg) => {
  $('token').value = cfg.token || '';
  $('name').value = cfg.name || '';
  $('port').value = cfg.port || 17659;
});

$('save').addEventListener('click', async () => {
  const name = $('name').value.trim();
  const port = parseInt($('port').value, 10);
  if (!/^[A-Za-z_][A-Za-z0-9_.-]*$/.test(name)) {
    $('status').textContent = 'The name must match [A-Za-z_][A-Za-z0-9_.-]*.';
    return;
  }
  if (!(port > 0 && port < 65536)) {
    $('status').textContent = 'The port must be 1-65535.';
    return;
  }
  await browser.storage.local.set({ token: $('token').value.trim(), name, port });
  $('status').textContent = 'Saved.';
});
