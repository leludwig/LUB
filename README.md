# LUB

LUB für **Chicken Farm**, Place-ID **137233438285284**, mit der Oberfläche von [WindUI](https://github.com/Footagesus/WindUI).

## Starten

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/leludwig/LUB/main/LUB.lua?v=2"))()
```

LUB lädt WindUI **1.6.66** aus dem [offiziellen Release](https://github.com/Footagesus/WindUI/releases/tag/1.6.66). Die Oberfläche hat genau drei Tabs: **Game**, **Games List** und **Settings**.

Die Ausführungsumgebung muss Roblox, `getgenv`, `loadstring` und `game:HttpGet` unterstützen. Ein normaler Studio-LocalScript stellt diese Ausführungsfunktionen nicht bereit.

## Game

Im Bereich **Auto Farm** befinden sich diese beiden Schalter direkt untereinander:

- **Autofarm:** vollständiges Farmen einschließlich Einlagern, Geldabholen, Upgrades, Hühnerkäufen und Mergen. Kaufe vorher dein erstes Huhn.
- **Collect Eggs Only:** sammelt ausschließlich vorhandene und neu erscheinende Eier. Kein Einlagern, Geldabholen, Upgraden, Kaufen oder Mergen.

Die Schalter deaktivieren sich gegenseitig. Das Ausschalten stoppt auch wartende Durchläufe. Beide Funktionen und ihre gesamte Logik stehen direkt in `src/games/137233438285284.lua`; es gibt kein separates Sammler-Modul.

`Collection requests` zählt gesendete Sammelanfragen. Ob der Spielserver sie annimmt, hängt unter anderem vom Inventar und den aktuellen Spiel-Remotes ab. LUB löscht keine Eier lokal und lagert sie im Eiermodus nicht automatisch ein.

## Games List

Die Liste enthält ausschließlich **Chicken Farm / 137233438285284**. Im Ordner `src/games` liegt ebenfalls nur dieses Spielskript. Die zugehörige Listendatei ist `src/gameslist.json`.

Ein Klick auf Chicken Farm öffnet im laufenden Spiel den Game-Tab; aus einem anderen Spiel startet er den Spielwechsel.

## Settings

- **Disable 3D Rendering:** blendet die 3D-Welt aus.
- **Auto Rejoin (when kicked):** versucht nach einem Disconnect/Kick erneut zu verbinden.
- **Unload LUB:** stoppt das Farmen und schließt LUB.

WindUI lässt sich mit **Right Shift** aus- und einblenden. Die kleine **LUB**-Schaltfläche öffnet das Fenster ebenfalls.

Mit Dateizugriff werden die Einstellungen unter `LUB/Config.json` gespeichert. Alte Einträge für andere Spiele werden beim Laden entfernt. Ohne Dateizugriff gelten die Einstellungen für die Sitzung. Das erneute Ausführen öffnet ein bereits laufendes LUB 2.0; eine noch laufende Oberfläche der vorherigen LUB-Version wird beim Upgrade beendet und ersetzt.

Optional kann die Startdatei lokal als `LUB/LUB.lua` im Workspace der Ausführungsumgebung abgelegt und so ausgeführt werden:

```lua
loadstring(readfile("LUB/LUB.lua"))()
```

Automatisches Neuladen nach einem Spielwechsel wird eingerichtet, wenn diese lokale Datei vorhanden ist und `queue_on_teleport` oder `queueonteleport` unterstützt wird.

## Quellcode und Build

```text
src/
  games/
    137233438285284.lua  # Alle Chicken-Farm-Funktionen inklusive Eiermodus
  gameslist.json        # Genau ein Spiel
  init.lua              # Start, Konfiguration und Aufräumen
  ui.lua                # WindUI-Fenster mit drei Tabs
LUB.lua                 # Generierte Startdatei
```

Nach Änderungen am Quellcode neu bauen:

```powershell
python tools/build.py
python tools/test.py --luau-dir .tools/luau
```

Der Build braucht nur Python 3. Für die Tests werden `luau` und `luau-compile` aus den [offiziellen Luau-Releases](https://github.com/luau-lang/luau/releases) benötigt. Der Build prüft, dass nur das vorgesehene Spielskript und der einzelne Listeneintrag enthalten sind.

Geprüft werden vier Luau-Dateien einschließlich Startdatei und 13 Verhaltenstests. Die Tests simulieren Roblox und die API von WindUI 1.6.66: Tabs, einzelner Spieleintrag, Eiersammeln, Stoppen, Moduswechsel, gespeicherte Einstellungen, Upgrade der alten Oberfläche und Schließen des Fensters. Die offizielle WindUI-Release-Datei wurde separat kompiliert. Die Darstellung im Roblox-Client und die Annahme von Sammelanfragen auf einem aktuellen Spielserver wurden nicht live verifiziert.

## Herkunft

Das Chicken-Farm-Skript basiert auf [BrainrotPolice](https://github.com/IcantAffordSynapse/BrainrotPolice), Commit `1f12e4fc599b5c4f6939c813a4e6eb218555c959`, von esore/vaehz. Apache-2.0-Lizenz und Herkunftshinweise sind in `LICENSE` und `NOTICE` erhalten. Die ursprünglichen weiteren Spielskripte sind in LUB 2.0 entfernt.

Die Oberfläche verwendet [WindUI von Footages](https://github.com/Footagesus/WindUI), Version 1.6.66, unter der MIT-Lizenz. LUB lädt die unveränderte offizielle Bibliothek beim Start.
