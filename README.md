# LUB

Deine angepasste Version von [BrainrotPolice](https://github.com/IcantAffordSynapse/BrainrotPolice), mit eigener Oberfläche und den drei Tabs **Game**, **Games List** und **Settings**.

## Starten

Direkt von GitHub starten:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/leludwig/LUB/main/LUB.lua"))()
```

Oder die Datei lokal verwenden:

1. Öffne `LUB.lua` und führe den vollständigen Inhalt in deiner Roblox-Luau-Ausführungsumgebung aus.
2. Im Spiel **Chicken Farm**, Place-ID **137233438285284**, öffnet sich der Tab **Game**.
3. Unter **Auto Farm**, direkt unter **Autofarm**, aktiviere **Collect Eggs Only**.

Alternativ lege die Datei als `LUB/LUB.lua` im Workspace deiner Ausführungsumgebung ab und starte sie so:

```lua
loadstring(readfile("LUB/LUB.lua"))()
```

Die Datei enthält die Oberfläche, Spieleliste und alle Spielmodule. Ein eigenes GitHub-Repository oder ein Download der ursprünglichen BrainrotPolice-Skripte ist zum Starten nicht erforderlich. Nach Änderungen am Quellcode muss die Datei neu gebaut werden.

LUB benötigt Roblox sowie eine Umgebung mit `getgenv`, `loadstring` und Zugriff auf die Roblox-Dienste. Ein normaler Studio-LocalScript stellt die im Original verwendeten Ausführungsfunktionen nicht bereit. Mit `isfile`, `readfile`, `writefile`, `isfolder` und `makefolder` werden Einstellungen dauerhaft gespeichert; sonst gelten sie nur für die aktuelle Sitzung.

## Chicken Farm: Collect Eggs Only

- Sammelt vorhandene Eier und während des Betriebs neu erscheinende Eier.
- Sendet ausschließlich `Collect Egg` über das bereits im Original verwendete RemoteEvent.
- Lagert keine Eier ein, holt kein Geld ab, kauft keine Hühner und führt weder Upgrades noch Merges aus.
- Löscht keine Eier lokal; die Verarbeitung bleibt beim Spielserver.
- Schaltet das vollständige Autofarm automatisch aus. Das Aktivieren von Autofarm schaltet umgekehrt den Eiermodus aus.
- Stoppt bei Deaktivierung auch noch wartende Durchläufe. Ein bereits abgeschickter Serveraufruf lässt sich nicht zurückholen.

`Collection requests` zählt gesendete Sammelanfragen, keine vom Server bestätigten Sammelerfolge. Volles Inventar oder veränderte Spiel-Remotes können die Annahme der Anfragen verhindern. Eier werden bewusst nicht automatisch eingelagert.

Das vollständige **Autofarm** bleibt zusätzlich erhalten und übernimmt Sammeln, Einlagern, Geldabholen, Upgrades, Kaufen und Mergen. Kaufe vor seiner Verwendung wie im Original dein erstes Huhn.

## Bedienung und Einstellungen

- **Game:** Funktionen für die aktuelle Place-ID; für unbekannte Spiele wird ein Hinweis angezeigt.
- **Games List:** ursprüngliche Spieleliste mit Suchfeld und Schaltflächen zum Spielwechsel. Die Statusfarben stammen aus dem Original und sind keine neue Live-Prüfung.
- **Settings:** `Disable 3D Rendering` und `Auto Rejoin (when kicked)`.
- Einstellungen liegen unter `LUB/Config.json`, einschließlich des gewählten Farm-Modus.
- Mit **Right Shift** oder **-** wird das Fenster ausgeblendet, mit der kleinen **LUB**-Schaltfläche wieder geöffnet. Das Fenster lässt sich an der Titelleiste verschieben.
- Erneutes Ausführen öffnet die bereits laufende Oberfläche, statt eine zweite Instanz zu starten.
- Für automatisches Neuladen nach einem Spielwechsel muss `LUB/LUB.lua` vorhanden sein und die Umgebung `queue_on_teleport` oder `queueonteleport` unterstützen.

## Entwicklung

```powershell
python tools/build.py
python tools/test.py --luau-dir .tools/luau
```

Der Build benötigt nur Python 3 und dessen Standardbibliothek. Für die Tests werden `luau` und `luau-compile` aus den [offiziellen Luau-Releases](https://github.com/luau-lang/luau/releases) benötigt. Entpacke sie nach `.tools/luau` oder gib ihren Ordner über `--luau-dir` an.

Wichtige Dateien:

- `LUB.lua`: fertige, generierte Startdatei; Änderungen in `src/` vornehmen.
- `src/init.lua`: Start, Modul-Lader und Konfiguration.
- `src/ui.lua` und `src/elements.lua`: Oberfläche und Bedienelemente.
- `src/games/137233438285284.lua`: Chicken-Farm-Modul mit beiden Farm-Modi.
- `src/modules/egg_collector.lua`: isolierter Eier-Sammler.
- `tests/test_lub.luau`: Verhaltenstests mit simuliertem Roblox und kontrollierter Zeitsteuerung.

Eigene Spielskripte sind weiterhin möglich: Setze `getgenv().FileScripts = true` vor dem Start und lege `LUB/<PlaceId>.lua` an. Ein solches Skript hat Vorrang vor dem mitgelieferten Modul.

```lua
return function(section, data)
    local elements = getgenv().LUBRequire("src/elements.lua")
    elements:Label("Mein Spielmodul", section)
    elements:Toggle("Meine Funktion", section, false, function(enabled)
        getgenv().setconfig("meine_funktion", enabled)
    end)
end
```

## Prüfstand und Herkunft

36 Lua-Dateien (einschließlich Bundle) werden mit dem Luau-Compiler geprüft. Die Verhaltenstests prüfen unter anderem die tatsächlichen UI-Callbacks, Suche, Einstellungen, vorhandene/neue Eier, Stoppen, schnelle Moduswechsel, nachladende Spielobjekte, Fehler beim Sammeln und das Wiederherstellen gespeicherter Modi.

Die Tests laufen gegen eine Simulation. Darstellung im Roblox-Client und Annahme der Remote-Aufrufe durch einen aktuellen Chicken-Farm-Server wurden nicht live verifiziert. Die weiteren übernommenen Spielmodule wurden für den LUB-Lader und die Konfiguration angepasst und auf Syntax geprüft; ihr Spielverhalten wurde nicht neu getestet.

Basis: BrainrotPolice, Commit `1f12e4fc599b5c4f6939c813a4e6eb218555c959`, abgerufen am 06.09.2026. Original von esore/vaehz, Beiträge von __ven0x__ und wirlypirly12. Die ursprüngliche Apache-2.0-Lizenz und die Herkunftshinweise bleiben in `LICENSE` und `NOTICE` erhalten und sind zusätzlich in der Startdatei enthalten.
