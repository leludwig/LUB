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

Unter **Game → Auto Farm → Autofarm** wird der in den bereitgestellten Logs aufgezeichnete Ablauf wiederholt:

1. `BaseBuildTunnelAction:InvokeServer(base, floor, tunnel, "GetDrillState")` fragt die Bereitschaft ab.
2. Bei `result.ready == true` folgt nach einer Sekunde `DrillTunnel` mit denselben Zielargumenten.
3. Nach 1,5 Sekunden werden die **frisch vom Server zurückgegebenen** `PendingRewardIds` mit `BaseCrateAction:InvokeServer(base, "CollectDroneOres", ids)` eingesammelt. Ein einzelnes `PendingRewardId` wird ebenfalls unterstützt.
4. `remainingSeconds` und `GrowTime` bestimmen, wann ein Tunnel erneut abgefragt wird. Abgelehnte Sammelanfragen werden höchstens dreimal mit denselben IDs versucht; Fehler erscheinen unter **Farm Status**.

**Farm Targets** lässt sich aufklappen. Die Vorgaben stammen aus den Logs: **Base1**, **Floor 1**, **Tunnel3, Tunnel4**. Wenn deine aktuelle Basis oder deine Tunnel anders heißen, trage dort die passenden Werte ein. Weitere eigene Tunnel lassen sich durch Kommas getrennt ergänzen. Die Basis wird nicht automatisch erkannt. Änderungen an den Zielen stoppen den laufenden Durchlauf; anschließend Autofarm erneut einschalten.

Das Modul automatisiert Bohren und Erze einsammeln. Verkauf, Upgrades, Käufe und Rollen sind nicht enthalten, da dazu keine ausgehenden Aufrufe in den bereitgestellten Logs vorliegen. Aufgezeichnete Reward-IDs und eingehende Ereignisse werden nicht wieder abgespielt. Die Rohlogs werden nicht veröffentlicht.

## Games List

Die Liste enthält **Chicken Farm / 137233438285284** und **Sell Ores / 122572082932179**. Jedes Spiel hat sein eigenes Skript im Ordner `src/games`. Die zugehörige Listendatei ist `src/gameslist.json`; sie bestimmt auch, welches Modul geladen wird und welche Spieleinstellungen erhalten bleiben.

Ein Klick auf einen Spieleintrag oder dessen Play-Symbol tritt dem Spiel bei, auch wenn du dich bereits darin befindest. Der Text steht linksbündig; das Play-Symbol ist um 18 Pixel vom bisherigen rechten Rand eingerückt. Dieselbe Ausrichtung gilt für Unload LUB.

Bei einem unbekannten Spiel zeigt der Game-Tab **Game not supported** mit der aktuellen Place-ID und dem Hinweis, dass dafür kein LUB-Skript verfügbar ist. Games List und Settings bleiben erreichbar.

## Settings

- **Disable 3D Rendering:** blendet die 3D-Welt aus.
- **Auto Rejoin (when kicked):** versucht nach einem Disconnect/Kick erneut zu verbinden.
- **Unload LUB:** stoppt das Farmen und schließt LUB.

WindUI lässt sich mit **Insert (Einfg)** aus- und einblenden. Die kleine **LUB**-Schaltfläche öffnet das Fenster ebenfalls.

Mit Dateizugriff werden die Einstellungen unter `LUB/Config.json` gespeichert. Die beiden unterstützten Spiele haben getrennte Einstellungen; alte Einträge für nicht unterstützte Spiele werden entfernt. Ohne Dateizugriff gelten die Einstellungen für die Sitzung. Das erneute Ausführen öffnet ein bereits laufendes LUB 2.3; eine noch laufende Oberfläche der vorherigen LUB-Version wird beim Upgrade beendet und ersetzt.

Optional kann die Startdatei lokal als `LUB/LUB.lua` im Workspace der Ausführungsumgebung abgelegt und so ausgeführt werden:

```lua
loadstring(readfile("LUB/LUB.lua"))()
```

Automatisches Neuladen nach einem Spielwechsel wird eingerichtet, wenn diese lokale Datei vorhanden ist und `queue_on_teleport` oder `queueonteleport` unterstützt wird.

## Quellcode und Build

```text
src/
  games/
    122572082932179.lua  # Sell Ores: Bohren und Erze einsammeln
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

Geprüft werden fünf Luau-Dateien einschließlich Startdatei und 26 Verhaltenstests. Die Tests simulieren Roblox und die API von WindUI 1.6.66: Chicken-Farm-Ablauf, Sell-Ores-Aufrufe mit frischen IDs und Serverwartezeiten, Fehlerantworten, begrenzte Wiederholungen, konfigurierbare Ziele, Stoppen und Entladen sowie Spielbeitritt, Insert-Taste, getrennte Einstellungen, unbekannte Spiele und Versionswechsel. Die offizielle WindUI-Release-Datei wurde separat kompiliert. Die Darstellung im Roblox-Client und die Annahme der Anfragen auf aktuellen Spielservern wurden nicht live verifiziert.

## Herkunft

Das Chicken-Farm-Skript basiert auf [BrainrotPolice](https://github.com/IcantAffordSynapse/BrainrotPolice), Commit `1f12e4fc599b5c4f6939c813a4e6eb218555c959`, von esore/vaehz. Apache-2.0-Lizenz und Herkunftshinweise sind in `LICENSE` und `NOTICE` erhalten. Die ursprünglichen weiteren Spielskripte sind in LUB 2.0 entfernt.

Die Oberfläche verwendet [WindUI von Footages](https://github.com/Footagesus/WindUI), Version 1.6.66, unter der MIT-Lizenz. LUB lädt die unveränderte offizielle Bibliothek beim Start.
