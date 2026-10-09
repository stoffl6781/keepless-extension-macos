// Texts of the container app window (German for German system languages, English otherwise).
// App Store guideline 3.1.3(f): no purchase or upgrade hints here.
const TEXTS = {
    en: {
        title: 'Keepless for Safari',
        unknown: 'Turn on Keepless in Safari Settings under “Extensions”.',
        on: 'Keepless is turned on in Safari.',
        off: 'Keepless is not turned on in Safari yet.',
        step1: 'In Safari Settings → Extensions, select Keepless.',
        step2: 'Allow access to websites. Keepless needs it to fill in licenses.',
        step3: 'Click the lock icon in the Safari toolbar to create your vault or pair this Mac. No icon? View → Customize Toolbar.',
        button: 'Quit and Open Safari Settings…'
    },
    de: {
        title: 'Keepless für Safari',
        unknown: 'Aktivieren Sie Keepless in den Safari-Einstellungen unter „Erweiterungen“.',
        on: 'Keepless ist in Safari aktiviert.',
        off: 'Keepless ist in Safari noch nicht aktiviert.',
        step1: 'Safari-Einstellungen → Erweiterungen: Keepless anhaken.',
        step2: 'Zugriff auf Websites erlauben. Keepless braucht ihn, um Lizenzen einzufügen.',
        step3: 'Auf das Schloss in der Safari-Symbolleiste klicken und den Tresor anlegen oder diesen Mac koppeln. Kein Symbol zu sehen? Darstellung → Symbolleiste anpassen.',
        button: 'Beenden und Safari-Einstellungen öffnen …'
    }
};

const lang = (navigator.languages || [navigator.language]).some((l) => /^de\b/i.test(l)) ? 'de' : 'en';
document.documentElement.lang = lang;
for (const el of document.querySelectorAll('[data-text]')) {
    el.textContent = TEXTS[lang][el.dataset.text];
}

// Called by ViewController once Safari reports the extension state.
function show(enabled) {
    document.body.classList.toggle('state-on', enabled === true);
    document.body.classList.toggle('state-off', enabled === false);
}

document.querySelector('button.open-preferences').addEventListener('click', () => {
    webkit.messageHandlers.controller.postMessage('open-preferences');
});
