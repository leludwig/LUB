# LUB

LUB für **Chicken Farm**, **Sell Ores** und **Fishing Chef**, mit der Oberfläche von [WindUI](https://github.com/Footagesus/WindUI).

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

## Fishing Chef · 88599461076137

Version 2.9.0 bietet unter **Game → Auto Farm** unabhängig zuschaltbares Auto Fish. Es läuft parallel zu Auto Cook oder Autofarm. Nur Auto Cook und Autofarm schließen sich gegenseitig aus. Alle Schalter starten ausgeschaltet; das Abschalten eines Bereichs lässt den anderen weiterlaufen. Unload LUB beendet beide Abläufe.

- **Autofarm:** prüft zuerst eigene wartende Kunden und deren Bestellung. Passende fertige Gerichte werden serviert; andernfalls wird das bestellte Gericht zubereitet und bei fehlendem Fisch geangelt. Ohne Kundenbestellung wird nichts auf Vorrat gekocht. Das Restaurant muss geöffnet sein.
- **Auto Fish:** angelt ausschließlich, auch bei geschlossenem Restaurant. Ein gültiger aktueller Angelplatz wird direkt genutzt; eine Angel muss im Rucksack oder ausgerüstet sein.
- **Cook recipe + Auto Cook:** bereitet wiederholt das ausgewählte Gericht aus vorhandenen Filets oder nicht favorisierten Inventarfischen zu. Dieser Modus angelt und bedient keine Kunden, funktioniert auch bei geschlossenem Restaurant und wartet bei fehlenden Zutaten. Ein Rezeptwechsel bricht ausstehende Schritte des vorherigen Rezepts ab.

Ab Version 2.8.1 geht Auto Fish beim Einschalten einmal zur gespeicherten Angelposition und übernimmt deren Blickrichtung. Nach 0,5 Sekunden beginnt das Angeln. Weitere Würfe verändern die Position nicht erneut. Ohne gespeicherten Spot wird der aktuelle Standort genutzt. Autofarm und Auto Cook bewegen die Figur weiterhin nicht automatisch; Go to fishing spot erlaubt zusätzlich einen manuellen Ortswechsel. Schneiden, Kochen und Bedienen werden direkt über Remotes angefordert; die Schneidebrett-Animationsaufrufe entfallen ebenfalls. Ob der Server diese Interaktionen aus beliebiger Entfernung akzeptiert, ist noch nicht live bestätigt. Bei fehlender Bestätigung stoppt die Routine mit einem Hinweis, ohne automatisch näher heranzugehen.

Version 2.7.1 verwendet für Auto Fish und den Autofarm direkt `CastRequest(Wurfstärke)`, wartet auf `CastResponse` und sendet `MinigameResolved(true)`. Der native Autofish-Modus bleibt ausgeschaltet. Ein Fang zählt erst nach Erhöhung des replizierten Fangzählers. Ohne Cast-Bestätigung stoppt der Ablauf nach höchstens fünf Sekunden Wartezeit. Wird ein Fang nach fünf Sekunden nicht bestätigt, beendet LUB die Sitzung und wirft nach einer Sekunde erneut aus; Auto Fish und Autofarm bleiben eingeschaltet. Das gilt auch für Fische, die die Angel nicht bewältigt. Ausschalten und Entladen unterbrechen weiterhin die Wiederholung; eine noch offene Sitzung wird beim Stoppen mit `MinigameResolved(false)` abgebrochen. **Resolve delay** legt die Wartezeit zwischen Cast-Bestätigung und Auflösung fest (Standard 5 Sekunden, einstellbar von 0,1 bis 12). Der direkte Ablauf und die minimale vom Server akzeptierte Dauer sind noch nicht live geprüft.

**Set fishing spot** speichert bei gestopptem Modus die aktuelle Position und Blickrichtung für diese Sitzung, sofern Wasser voraus liegt. **Go to fishing spot** bewegt die Figur auf Klick dorthin; Auto Fish übernimmt diesen Weg beim Einschalten auch automatisch. Entfernt man sich mehr als drei Studs vom gespeicherten Standort, stoppt das Angeln mit einem Hinweis. CastRequest besitzt in den Logs kein Positionsargument; eine gespeicherte Stelle ermöglicht daher kein Angeln von beliebigen anderen Orten aus. **Check fishing spot** prüft die aktuelle Blickrichtung. Die zusätzlichen Erklärungstexte unten im Menü wurden entfernt.

Ab Version 2.8.0 berücksichtigt der Autofarm auch fischspezifische Bestellungen aus OrderText, etwa Tuna Sushi oder Bluefin Tuna Sushi. Die Fischbezeichnung wird über FishIndex dem internen Fischschlüssel zugeordnet; Rohfisch, Perfect-Filet und fertige Platte müssen zu dieser Art passen. Ein Teller mit anderem Fisch wird nicht als passende Bestellung gewertet. Unbekannte Fischbezeichnungen werden übersprungen, Änderungen der Fischbestellung vor dem Verbrauch erneut geprüft. Fehlt die passende Art, angelt der Autofarm am aktuellen Standort weiter; er wechselt dafür nicht automatisch das Fanggebiet. Der neue Ablauf wurde mit simulierten Bestellungen getestet, noch nicht live bestätigt.

Bei eingeschaltetem Auto Fish wartet der Autofarm bei fehlenden Zutaten auf dessen Fänge. Für bedarfsabhängiges Angeln und Auto Fish wird dieselbe einzelne Angelsitzung verwendet; parallele CastRequest-Aufrufe werden verhindert. Kochen läuft während der Wartezeit eines Fangs weiter. Ein Fehler eines Bereichs beendet den anderen nicht. Der Parallelbetrieb wurde mit simulierten Serverantworten geprüft, noch nicht live bestätigt.

Die Gerichtsauswahl kommt aus der aktuellen `CookingConfig`, einschließlich Nigiri, Sashimi, Sushi und Herdgerichten. Spielerlevel, Standlevel, erforderliche abgeschlossene Rezeptquests und benötigte Fischarten werden berücksichtigt. Alle Gerichte werden über `Cook(Rezeptname, aktuelle Zutat)` angefordert; nur eine bestätigte neue Platte zählt als Erfolg. Die zusätzlichen Rezeptpfade sind bisher mit simulierten Serverantworten geprüft, ihre Annahme im Live-Spiel noch nicht bestätigt.

Fische, Zutaten und fertige Gerichte werden aus den aktuellen Spieldaten gewählt. Teichfische und Favoriten werden nicht verwendet. Da der Server beim Bedienen das Gericht auswählt, pausiert der Autofarm diese Rezeptart, sobald ein entsprechendes favorisiertes Gericht vorhanden ist. Vor dem Verbrauch eines Fisches und vor dem Kochen wird die Kundenbestellung erneut geprüft; verschwundene oder geänderte Bestellungen werden verworfen. Fremde Kunden werden nicht bedient. Automatische Käufe und Upgrades gehören nicht zu dieser Erweiterung.

Ab Version 2.6.2 werden nur Filets mit bestätigter Perfect-Qualität (fünf Sterne) gekocht. Schlechtere oder unbekannte Qualitäten bleiben im Inventar. Erreicht der gemessene Schnittscore nicht mindestens 1,3, wird der Fisch nicht verbraucht. Nach Schneiden und Kochen wird die Serverqualität geprüft; bei fehlender Perfect-Bestätigung stoppt der Modus. Das garantiert keine serverseitige Bewertung und maximiert nicht automatisch zusätzliche Messer-, Mutations- oder Sashimi-Boni.

Die pauschale Kochwartezeit von 7–20 Sekunden entfällt. Mit vorhandenem Perfect-Filet wird Cook direkt angefordert; auf Ergebnisse wird nur bis zur Bestätigung gewartet. Die gemessenen Schnittzeiten bleiben bestehen. Falls der Server einen Mindestabstand zwischen Aufrufen verlangt, wird ein nicht bestätigtes Ergebnis weiterhin als Fehler angezeigt. Der Fenstertitel zeigt jetzt die geladene LUB-Version.

Version 2.7.1 stellt die Inventarleiste nach einem Cast, bei Fangende und beim Stoppen wieder her; auch eine von einer vorherigen Sitzung ausgeblendete Leiste wird beim Laden repariert. Fehlgeschlagene Fänge führen zu einem neuen Versuch statt zum Abschalten.

Version 2.7.4 nimmt die Beschleunigung des Schneidens zurück: LUB wartet wieder auf den absteigenden Zeigerdurchlauf und nach jedem Schnitt 0,25 Sekunden. Bei den aufgezeichneten Zielen 0,8 und 0,4 sind das rund 3,42 Sekunden. Anlass war ein Live-Bericht über nicht bestätigte Perfect-Filets; ob die längeren Zeiten diesen Fehler beheben, ist noch nicht live bestätigt. Die Perfect-Prüfung anhand des gemessenen Scores bleibt bestehen. Sie verwenden die Ziele der aktuellen `StartCutSession` und die Cursorbewegung des normalen Schneideminispiels. `CutFish` verwendet die aktuelle Fisch-ID; `Cook` erhält eine erneut gelesene Zutat. Erst ein neuer Eintrag in `Plates` zählt als gekochtes Gericht; die Zahl bedienter Kunden kommt aus dem replizierten Spielzähler. Ausschalten, Entladen und Charakterwechsel stoppen Folgeschritte sowie das von LUB gestartete automatische Angeln. Bereits beim Server laufende Aufrufe können nicht zurückgenommen werden.

Grundlage sind die bereitgestellten Cobalt-Logs und die zuvor ausgelesene Clientstruktur. Der native Angelablauf wurde am eigenen Steg live bestätigt (Fangzähler 12 → 13). **Der neue vollständige Restaurantablauf wurde nur lokal mit simulierten Serverantworten getestet, noch nicht live bestätigt.** Der permanente GitHub-Startbefehl lädt diese Erweiterung aus `main`; denselben Befehl nach dem Update erneut ausführen.

## Games List

Die Liste enthält **Chicken Farm / 137233438285284**, **Sell Ores / 122572082932179** und **Fishing Chef / 88599461076137**. Jedes Spiel hat sein eigenes Skript im Ordner `src/games`. Die zugehörige Listendatei ist `src/gameslist.json`; sie bestimmt auch, welches Modul geladen wird und welche Spieleinstellungen erhalten bleiben.

Ein Klick auf einen Spieleintrag oder dessen Play-Symbol fragt die aktuelle öffentliche Serverliste bei Roblox ab und wählt einen laufenden Server mit freien Plätzen. Volle Server, leere Einträge und der aktuelle `game.JobId` werden übersprungen. Server-IDs werden nicht gespeichert. Pro Suche werden höchstens drei Seiten geprüft; bei einem fehlgeschlagenen Beitritt wird die Liste erneut abgefragt und insgesamt höchstens drei verschiedene Server versucht.

Bei fehlender Serverliste oder einer Zugriffsablehnung öffnet LUB den offiziellen Roblox-Spieldialog. Dort **Play / Join** drücken, damit Roblox die Serverzuordnung übernimmt. Die Universe-IDs dafür stehen getrennt von den Place-IDs in der Games List. Falls Roblox auch diesen Beitritt ablehnt, zeigt der Spieleintrag die offizielle Spielseite an, auf der du das Spiel normal starten kannst. Einschränkungen des Spiels oder des Kontos werden dadurch nicht aufgehoben. Siehe [Roblox-Spieldialog](https://create.roblox.com/docs/reference/engine/classes/TeleportService#PromptExperienceDetailsAsync) und [Teleport-Zugriffseinstellungen](https://create.roblox.com/docs/projects/teleport#configure-secure-teleportation).

Der Spieleintrag zeigt Such-, Beitritts- und Fehlerstatus an. Mehrfachklicks starten keine parallelen Beitritte. **Auto Rejoin** reagiert während eines Spielwechsels und kurz nach dessen Fehlschlag nicht auf Teleport-Fehlermeldungen. **Unload LUB** beendet auch wartende Serversuchen und Wiederholungen.

Der Text steht weiterhin linksbündig; das Play-Symbol ist um 18 Pixel vom bisherigen rechten Rand eingerückt. Dieselbe Ausrichtung gilt für Unload LUB.

Bei einem unbekannten Spiel zeigt der Game-Tab **Game not supported** mit der aktuellen Place-ID und dem Hinweis, dass dafür kein LUB-Skript verfügbar ist. Games List und Settings bleiben erreichbar.

## Settings

- **Disable 3D Rendering:** blendet die 3D-Welt aus.
- **Auto Rejoin (when kicked):** versucht nach einem Disconnect/Kick erneut zu verbinden.
- **Unload LUB:** stoppt das Farmen und schließt LUB.

WindUI lässt sich mit **Insert (Einfg)** aus- und einblenden. Die kleine **LUB**-Schaltfläche öffnet das Fenster ebenfalls.

Mit Dateizugriff werden die Einstellungen unter `LUB/Config.json` gespeichert. Chicken Farm und Sell Ores haben getrennte gespeicherte Einstellungen; Fishing Chef wird pro Sitzung gestartet; alte Einträge für nicht unterstützte Spiele werden entfernt. Ohne Dateizugriff gelten die Einstellungen für die Sitzung. Das erneute Ausführen öffnet ein bereits laufendes LUB 2.9.0; eine noch laufende Oberfläche der vorherigen LUB-Version wird beim Upgrade beendet und ersetzt.

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
    88599461076137.lua   # Fishing Chef: Angeln und Nigiri-Restaurantablauf
  gameslist.json        # Unterstützte Spiele und ihre Place-IDs
  init.lua              # Start, Konfiguration und Aufräumen
  join.lua              # Öffentliche Serverwahl und Roblox-Spieldialog
  ui.lua                # WindUI-Fenster mit drei Tabs
LUB.lua                 # Generierte Startdatei
```

Nach Änderungen am Quellcode neu bauen:

```powershell
python tools/build.py
python tools/test.py --luau-dir .tools/luau
```

Der Build braucht nur Python 3. Für die Tests werden `luau` und `luau-compile` aus den [offiziellen Luau-Releases](https://github.com/luau-lang/luau/releases) benötigt. Der Build prüft eindeutige Place-IDs und die Übereinstimmung zwischen Games List und den enthaltenen Spielskripten.

Geprüft werden sieben Luau-Dateien einschließlich Startdatei und 76 Verhaltenstests. Die Tests simulieren Roblox und die API von WindUI 1.6.66: Chicken-Farm-Ablauf, automatische Basiswahl, Sell-Ores-Prompt-Reihenfolge und Wartezeiten, Roll-Käufe, Verkauf, verfügbare Belohnungen, Upgrade-Käufe, Ofen-Durchsatz und Erzentscheidungen, Entladen sowie Spielbeitritt, Insert-Taste, getrennte Einstellungen, unbekannte Spiele und Versionswechsel. Die Beitrittstests decken aktuelle/volle Server, Pagination, HTTP-Fehler, begrenzte Wiederholungen, Zugriffsablehnungen, Roblox-Dialog, Mehrfachklicks, Timeouts und Abbruch beim Entladen ab. Die öffentlichen Serverlisten und die Zuordnung der Startplätze wurden über die Roblox-API geprüft. Die Fishing-Chef-Tests prüfen zusätzlich die Kundenbestellungen, Rezeptauswahl, getrennte Modi, Rezeptfreischaltungen, benötigten Fischarten, Favoriten und Eigentümer, abgeschaltete Restaurants, Abbrüche, Versionsschutz durch Laufkennungen, verzögerte Antworten, Fehler und Zeitlimits. Die Darstellung und der vollständige Restaurantablauf wurden nicht live verifiziert; der oben beschriebene einzelne Angeltest ist davon ausgenommen.

## Herkunft

Das Chicken-Farm-Skript basiert auf [BrainrotPolice](https://github.com/IcantAffordSynapse/BrainrotPolice), Commit `1f12e4fc599b5c4f6939c813a4e6eb218555c959`, von esore/vaehz. Apache-2.0-Lizenz und Herkunftshinweise sind in `LICENSE` und `NOTICE` erhalten. Die ursprünglichen weiteren Spielskripte sind in LUB 2.0 entfernt.

Die Oberfläche verwendet [WindUI von Footages](https://github.com/Footagesus/WindUI), Version 1.6.66, unter der MIT-Lizenz. LUB lädt die unveränderte offizielle Bibliothek beim Start.

Das Sell-Ores-Modul stammt aus dem vom Nutzer bereitgestellten Skript von **seltonmt**. Die Autorenzeile und ursprünglichen Kommentare bleiben erhalten; Messangaben in diesen Kommentaren stammen aus der Vorlage und sind keine Live-Verifikation durch LUB.

WindUI-Cleanup ab 2.7.2: Fehler der Schließanimation unter eingeschränkten Executor-Callbacks unterbrechen das Aufräumen nicht mehr. LUB versucht dann, nur die GUI-Wurzeln seiner eigenen WindUI-Instanz direkt zu entfernen und ihre Verbindungen zu lösen. Falls auch das nicht erlaubt ist, wird der Fehler gemeldet. Ein ursprünglicher Startfehler bleibt als LUB startup error sichtbar. Das Verhalten wurde mit simulierten Capability-Fehlern getestet; die konkrete Executor-Sitzung ist noch nicht live geprüft.

Version 2.7.3 setzt die WindUI-GUI-Wurzeln über SetParent vor dem Fensteraufbau in PlayerGui. Damit verwendet LUB für seine Oberfläche keinen geschützten Executor-UI-Container mehr. Die Tests prüfen die Zuordnung vor CreateWindow; die betroffene Live-Sitzung konnte hier nicht geprüft werden.
