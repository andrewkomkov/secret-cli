// Localize the page: data-i18n sets the text, data-i18n-title sets document.title.
// Strings are in _locales/<lang>/messages.json; Safari picks the language of the system.
const t = (key, subs) => browser.i18n.getMessage(key, subs) || key;
for (const el of document.querySelectorAll('[data-i18n]')) el.textContent = t(el.dataset.i18n);
const titleKey = document.documentElement.dataset.i18nTitle;
if (titleKey) document.title = t(titleKey);
