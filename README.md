# LUB

LUB für **Chicken Farm** und **Sell Ores**, mit der Oberfläche von [WindUI](https://github.com/Footagesus/WindUI).

## Starten

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/leludwig/LUB/main/LUB.lua?t=" .. os.time()))()
```

Dieser Startbefehl bleibt bei zukünftigen Updates gleich. Er lädt LUB von `main`; der automatisch angehängte Zeitstempel verhindert, dass dieselbe Download-URL aus einem alten Cache verwendet wird. Eine Versionsnummer muss nicht von Hand geändert werden. Nach einem Update den gleichen Befehl erneut ausführen.

LUB lädt WindUI **1.6.66** aus dem [offiziellen Release](https://github.com/Footagesus/WindUI/releases/tag/1.6.66). Die Oberfläche hat genau drei Tabs: **Game**, **Games List** und **Settings**.

Die Ausführungsumgebung muss Roblox, `getgenv`, `loadstring` und `game:HttpGet` unterstützen. Ein normaler Studio-LocalScript stellt diese Ausführungsfunktionen nicht bereit.

## Chicken Farm · 137233438285284

Im Bereich **Auto Farm** befinden sich diese beiden Schalter direkt untereinander:

- **Autofarm:** vollständiges Farmen einschließlich Einlagern, Geldabholen, Upgrades, Hühnerkäufen und Mergen. Kaufe vorher dein erstes Huhn.
- **Collect Eggs Only:** sammelt ausschließlich vorhandene und neu erscheinende Eier. Kein Einlagern, Geldabholen, Upgraden, Kaufen oder Mergen.

Die Schalter deaktivieren sich gegenseitig. Das Ausschalten stoppt auch wartende Durchläufe. Beide Funktionen und ihre gesamte Logik stehen direkt in `src/games/137233438285284.lua`; es gibt kein separates Sammler-Modul.

Version 2.1 übernimmt den Sammelablauf aus dem [Originalskript](https://raw.githubusercontent.com/IcantAffordSynapse/BrainrotPolice/refs/heads/main/src/games/137233438285284.lua): Für vorhandene Eier `FireServer("Collect Egg", egg.Name)`, danach `task.wait()` und `egg:Destroy()`. Neue Eier werden über `workspace.Eggs.ChildAdded` nach einer Sekunde auf dieselbe Weise eingesammelt. Der Listener wird vor dem ersten Durchlauf verbunden, damit währenddessen erscheinende Eier ebenfalls erfasst werden. Einlagern und die weiteren Farm-Aktionen laufen ausschließlich im vollständigen Autofarm-Modus.

Die lokale Entfernung entspricht dem Original und ist keine Bestätigung des Spielservers. Die Annahme der Sammelanfragen kann hier nicht live geprüft werden. Bei einem Lua-Fehler stoppt der Schalter und `Collection Status` zeigt den Fehler an; nach vollständigem Laden des Spiels kann der Modus erneut eingeschaltet werden.

## Sell Ores · 122572082932179

Version 2.4 übernimmt das vom Nutzer bereitgestellte **Sell-Ores-Skript von seltonmt** direkt in `src/games/122572082932179.lua`. Die Spielabläufe, Preise, Kaufentscheidungen und Wartezeiten stammen aus dieser Vorlage. Ihre separate Oberfläche wurde durch Steuerelemente im LUB-Game-Tab ersetzt. Eine externe `ui-template.lua` wird nicht benötigt.

Die eigene Basis wird anhand von `OwnerUserId` automatisch erkannt. Unter **Game → Auto Farm → Autofarm** läuft der vollständige Ablauf: rollen, geeignete Erze kaufen und ausrüsten, Kisten abholen und verkaufen beziehungsweise durch den Ofen verarbeiten sowie Geld nach den Prioritäten der Vorlage ausgeben.

Die aufklappbaren Bereiche enthalten alle bisherigen Bedienelemente:

- **Ore:** Auto Roll, Buy rolled ore, Max payback, Equip best ores und Level up ores.
- **Crates:** Pick up crates, Sell ores und Furnace (+50%).
- **Rewards:** Claim rewards sowie Claim everything now für verfügbare Tages-, Spielzeit-, Offline- und Spin-Belohnungen.
- **Manual:** Roll once und Pick up + sell now.
- **Spending:** Drill- und Roller-Upgrades, Tunnel, Stockwerke, Boost-Podeste und Growth Gems.
- **Status / Log:** Einkommen, Stockwerke, Engpässe, letzte Aktionen, Geldreserven und Entscheidungen. Mit Dateizugriff wird das Entscheidungsprotokoll unter `LUB/sellores-log.txt` gespeichert.

**Die Voreinstellungen entsprechen der Vorlage:** Autofarm, Buy rolled ore, Buy growth gems und Claim rewards sind beim ersten Start eingeschaltet. Der Hauptschalter aktiviert die vollständige Routine; einzeln eingeschaltete Funktionen bleiben auch bei ausgeschaltetem Hauptschalter aktiv. Zum vollständigen Beenden **Unload LUB** verwenden. Bereits gespeicherte Schalterstellungen werden wiederhergestellt.

Für die Prompt-Aktionen benötigt die Ausführungsumgebung `fireproximityprompt`; für die übernommenen SurfaceGui-Helfer außerdem `getconnections`. Die Figur wird wie in der Vorlage kurz an der jeweiligen Interaktion gehalten. Unload beendet auch wartende Folgeaktionen, löst die Verbindungen und stellt die von dieser Instanz veränderten Kaufdialog-Hooks wieder her. Ein vorgezogener lokaler `FURNACE`-Verweis behebt einen Variablenfehler der Vorlage in der Upgrade-Reserveberechnung.

## Games List

Die Liste enthält **Chicken Farm / 137233438285284** und **Sell Ores / 122572082932179**. Jedes Spiel hat sein eigenes Skript im Ordner `src/games`. Die zugehörige Listendatei ist `src/gameslist.json`; sie bestimmt auch, welches Modul geladen wird und welche Spieleinstellungen erhalten bleiben.

Ein Klick auf einen Spieleintrag oder dessen Play-Symbol tritt dem Spiel bei, auch wenn du dich bereits darin befindest. Der Text steht linksbündig; das Play-Symbol ist um 18 Pixel vom bisherigen rechten Rand eingerückt. Dieselbe Ausrichtung gilt für Unload LUB.

Bei einem unbekannten Spiel zeigt der Game-Tab **Game not supported** mit der aktuellen Place-ID und dem Hinweis, dass dafür kein LUB-Skript verfügbar ist. Games List und Settings bleiben erreichbar.

## Settings

- **Disable 3D Rendering:** blendet die 3D-Welt aus.
- **Auto Rejoin (when kicked):** versucht nach einem Disconnect/Kick erneut zu verbinden.
- **Unload LUB:** stoppt das Farmen und schließt LUB.

WindUI lässt sich mit **Insert (Einfg)** aus- und einblenden. Die kleine **LUB**-Schaltfläche öffnet das Fenster ebenfalls.

Mit Dateizugriff werden die Einstellungen unter `LUB/Config.json` gespeichert. Die beiden unterstützten Spiele haben getrennte Einstellungen; alte Einträge für nicht unterstützte Spiele werden entfernt. Ohne Dateizugriff gelten die Einstellungen für die Sitzung. Das erneute Ausführen öffnet ein bereits laufendes LUB 2.4; eine noch laufende Oberfläche der vorherigen LUB-Version wird beim Upgrade beendet und ersetzt.

Optional kann die Startdatei lokal als `LUB/LUB.lua` im Workspace der Ausführungsumgebung abgelegt und so ausgeführt werden:

```lua
loadstring(readfile("LUB/LUB.lua"))()
```

Automatisches Neuladen nach einem Spielwechsel wird eingerichtet, wenn diese lokale Datei vorhanden ist und `queue_on_teleport` oder `queueonteleport` unterstützt wird.

## Quellcode und Build

```text
src/
  games/
    122572082932179.lua  # Sell Ores: seltonmt-Spielabläufe mit WindUI
    137233438285284.lua  # Alle Chicken-Farm-Funktionen inklusive Eiermodus
  gameslist.json        # Unterstützte Spiele und ihre Place-IDs
  init.lua              # Start, Konfiguration und Aufräumen
  ui.lua                # WindUI-Fenster mit drei Tabs
LUB.lua                 # Generierte Startdatei
```

Nach Änderungen am Quellcode neu bauen:

```powershell
python tools/build.py
python tools/test.py --luau-dir .tools/luau
```

Der Build braucht nur Python 3. Für die Tests werden `luau` und `luau-compile` aus den [offiziellen Luau-Releases](https://github.com/luau-lang/luau/releases) benötigt. Der Build prüft eindeutige Place-IDs und die Übereinstimmung zwischen Games List und den enthaltenen Spielskripten.

Geprüft werden fünf Luau-Dateien einschließlich Startdatei und 27 Verhaltenstests. Die Tests simulieren Roblox und die API von WindUI 1.6.66: Chicken-Farm-Ablauf, automatische Basiswahl, Sell-Ores-Prompt-Reihenfolge und Wartezeiten, Roll-Käufe, Verkauf, verfügbare Belohnungen, Upgrade-Käufe, Ofen-Durchsatz und Erzentscheidungen, Entladen sowie Spielbeitritt, Insert-Taste, getrennte Einstellungen, unbekannte Spiele und Versionswechsel. Die Darstellung im Roblox-Client und die Annahme der Aktionen auf aktuellen Spielservern wurden nicht live verifiziert.

## Herkunft

Das Chicken-Farm-Skript basiert auf [BrainrotPolice](https://github.com/IcantAffordSynapse/BrainrotPolice), Commit `1f12e4fc599b5c4f6939c813a4e6eb218555c959`, von esore/vaehz. Apache-2.0-Lizenz und Herkunftshinweise sind in `LICENSE` und `NOTICE` erhalten. Die ursprünglichen weiteren Spielskripte sind in LUB 2.0 entfernt.

Die Oberfläche verwendet [WindUI von Footages](https://github.com/Footagesus/WindUI), Version 1.6.66, unter der MIT-Lizenz. LUB lädt die unveränderte offizielle Bibliothek beim Start.

Das Sell-Ores-Modul stammt aus dem vom Nutzer bereitgestellten Skript von **seltonmt**. Die Autorenzeile und ursprünglichen Kommentare bleiben erhalten; Messangaben in diesen Kommentaren stammen aus der Vorlage und sind keine Live-Verifikation durch LUB.
