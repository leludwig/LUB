# LUB

LUB für **Chicken Farm**, Place-ID **137233438285284**, mit der Oberfläche von [WindUI](https://github.com/Footagesus/WindUI).

## Starten

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/leludwig/LUB/main/LUB.lua?t=" .. os.time()))()
```

Dieser Startbefehl bleibt bei zukünftigen Updates gleich. Er lädt LUB von `main`; der automatisch angehängte Zeitstempel verhindert, dass dieselbe Download-URL aus einem alten Cache verwendet wird. Eine Versionsnummer muss nicht von Hand geändert werden. Nach einem Update den gleichen Befehl erneut ausführen.

LUB lädt WindUI **1.6.66** aus dem [offiziellen Release](https://github.com/Footagesus/WindUI/releases/tag/1.6.66). Die Oberfläche hat genau drei Tabs: **Game**, **Games List** und **Settings**.

Die Ausführungsumgebung muss Roblox, `getgenv`, `loadstring` und `game:HttpGet` unterstützen. Ein normaler Studio-LocalScript stellt diese Ausführungsfunktionen nicht bereit.

## Game

Im Bereich **Auto Farm** befinden sich diese beiden Schalter direkt untereinander:

- **Autofarm:** vollständiges Farmen einschließlich Einlagern, Geldabholen, Upgrades, Hühnerkäufen und Mergen. Kaufe vorher dein erstes Huhn.
- **Collect Eggs Only:** sammelt ausschließlich vorhandene und neu erscheinende Eier. Kein Einlagern, Geldabholen, Upgraden, Kaufen oder Mergen.

Die Schalter deaktivieren sich gegenseitig. Das Ausschalten stoppt auch wartende Durchläufe. Beide Funktionen und ihre gesamte Logik stehen direkt in `src/games/137233438285284.lua`; es gibt kein separates Sammler-Modul.

Version 2.1 übernimmt den Sammelablauf aus dem [Originalskript](https://raw.githubusercontent.com/IcantAffordSynapse/BrainrotPolice/refs/heads/main/src/games/137233438285284.lua): Für vorhandene Eier `FireServer("Collect Egg", egg.Name)`, danach `task.wait()` und `egg:Destroy()`. Neue Eier werden über `workspace.Eggs.ChildAdded` nach einer Sekunde auf dieselbe Weise eingesammelt. Der Listener wird vor dem ersten Durchlauf verbunden, damit währenddessen erscheinende Eier ebenfalls erfasst werden. Einlagern und die weiteren Farm-Aktionen laufen ausschließlich im vollständigen Autofarm-Modus.

Die lokale Entfernung entspricht dem Original und ist keine Bestätigung des Spielservers. Die Annahme der Sammelanfragen kann hier nicht live geprüft werden. Bei einem Lua-Fehler stoppt der Schalter und `Collection Status` zeigt den Fehler an; nach vollständigem Laden des Spiels kann der Modus erneut eingeschaltet werden.

## Games List

Die Liste enthält ausschließlich **Chicken Farm / 137233438285284**. Im Ordner `src/games` liegt ebenfalls nur dieses Spielskript. Die zugehörige Listendatei ist `src/gameslist.json`.

Ein Klick auf Chicken Farm oder das Play-Symbol tritt dem Spiel bei, auch wenn du dich bereits in diesem Spiel befindest. Der Text steht linksbündig; das Play-Symbol ist um 18 Pixel vom bisherigen rechten Rand eingerückt. Dieselbe Ausrichtung gilt für Unload LUB.

## Settings

- **Disable 3D Rendering:** blendet die 3D-Welt aus.
- **Auto Rejoin (when kicked):** versucht nach einem Disconnect/Kick erneut zu verbinden.
- **Unload LUB:** stoppt das Farmen und schließt LUB.

WindUI lässt sich mit **Insert (Einfg)** aus- und einblenden. Die kleine **LUB**-Schaltfläche öffnet das Fenster ebenfalls.

Mit Dateizugriff werden die Einstellungen unter `LUB/Config.json` gespeichert. Alte Einträge für andere Spiele werden beim Laden entfernt. Ohne Dateizugriff gelten die Einstellungen für die Sitzung. Das erneute Ausführen öffnet ein bereits laufendes LUB 2.2.1; eine noch laufende Oberfläche der vorherigen LUB-Version wird beim Upgrade beendet und ersetzt.

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

Geprüft werden vier Luau-Dateien einschließlich Startdatei und 18 Verhaltenstests. Die Tests simulieren Roblox und die API von WindUI 1.6.66: Sammelaufrufe, Wartezeiten und lokale Entfernung wie im Original, Eier während des Startdurchlaufs, Stoppen wartender Ereignisse, Fehleranzeige, Moduswechsel, ursprüngliche Reihenfolge der vollständigen Farm-Aktionen sowie Spielbeitritt, Insert-Taste, Tabs, Einstellungen und Versionswechsel. Die offizielle WindUI-Release-Datei wurde separat kompiliert. Die Darstellung im Roblox-Client und die Annahme von Sammelanfragen auf einem aktuellen Spielserver wurden nicht live verifiziert.

## Herkunft

Das Chicken-Farm-Skript basiert auf [BrainrotPolice](https://github.com/IcantAffordSynapse/BrainrotPolice), Commit `1f12e4fc599b5c4f6939c813a4e6eb218555c959`, von esore/vaehz. Apache-2.0-Lizenz und Herkunftshinweise sind in `LICENSE` und `NOTICE` erhalten. Die ursprünglichen weiteren Spielskripte sind in LUB 2.0 entfernt.

Die Oberfläche verwendet [WindUI von Footages](https://github.com/Footagesus/WindUI), Version 1.6.66, unter der MIT-Lizenz. LUB lädt die unveränderte offizielle Bibliothek beim Start.
