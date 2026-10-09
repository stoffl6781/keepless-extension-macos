# Keepless für Safari (macOS)

Container-App und Xcode-Projekt für die Safari-Version der Keepless-Extension.
Der Extension-Code liegt im Repo `keepless-extension`; dieses Repo enthält nur den
Mac-/Safari-Teil.

## Aufbau

- `Keepless/` – Xcode-Projekt (Mac-App + Safari Web Extension), committet
- `scripts/stage-extension.sh` – Build-Phase „Stage extension“: kopiert bei jedem Build die
  ausgelieferten Extension-Dateien ins `.appex` (ohne `docs/`, `tests/`, `*.md`, `package.json`,
  `offscreen.*`) und entfernt im Manifest die Berechtigungen, die Safari nicht kennt
  (`idle`, `offscreen`, `downloads`, `clipboardWrite`)
- `EXTENSION_VERSION` – Tag der Extension, aus dem ein **Release**-Build gebaut werden muss.
  Debug-Builds warnen nur, Release-Builds brechen ab, wenn der Checkout nicht exakt auf diesem
  Tag steht oder uncommittete Änderungen hat
- `setup.sh` + `scripts/patch-project.py` – erzeugen das Xcode-Projekt neu (nur nötig, wenn es
  verloren geht)

## Einrichten

1. Xcode installieren. `sudo xcode-select` ist nicht nötig, die Skripte nutzen `DEVELOPER_DIR`.
2. Extension daneben auschecken: `../keepless-extension`. Ein anderer Ort geht über
   `KEEPLESS_EXTENSION_DIR` oder eine Datei `.extension-dir` (git-ignoriert) mit dem Pfad.
3. `Keepless/Keepless.xcodeproj` in Xcode öffnen und bauen, dann die App einmal starten.
4. Safari → Einstellungen → Erweiterungen → Keepless aktivieren.

## Safari-Besonderheiten

- Kein `idle`, `offscreen`, `downloads`: Die Extension erkennt das und weicht aus
  (Auto-Lock per Inaktivitäts-Alarm, Speichern über `save.html`, kein Leeren der Zwischenablage).
- Die Extension-Adresse (`safari-web-extension://<UUID>`) wechselt bei jedem Safari-Start.
  Passkey-basiertes Touch ID überlebt das nicht; geplant ist Touch ID über die Mac-App
  (Schlüsselbund, Native Messaging).

## App Store

Guideline 3.1.3(f): kostenlose Begleit-App zum Webdienst, daher **kein Kauf-
oder Upgrade-Hinweis** in App oder Extension.
