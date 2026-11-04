# Karta gry w Google Play – teksty i materiały

Materiały graficzne są w `build/store/` (tworzą je skrypty z `tools/`, opis na dole).

## Teksty – polski (język główny)
**Nazwa (max 30 znaków):** `Fabryka Sort – robot i palety` (29)

**Krótki opis (max 80 znaków):**
> Steruj robotem, sortuj paczki i zaprogramuj ruchy jak prawdziwy automatyk! (74)

**Pełny opis (max 4000 znaków):**
> Witaj na hali! Twój robot-suwnica czeka na zlecenia. Ułóż paczki tak, by na każdej palecie został jeden produkt – brzmi prosto, dopóki nie pojawią się palety na 5 paczek, wymiana chwytaków, śliskie paczki, limit ruchów i folia stretch.
>
> TRZY TRYBY GRY
> • Kampania – 150+ zleceń z rosnącą trudnością i zleceniami na odpoczynek.
> • Programowanie robota – ułóż program, naciśnij START i sprawdź, czy robot wykona zadanie bez „błędu programu”. Pobij najkrótsze rozwiązanie.
> • Pojedynki – ścigaj się z robotami-rywalami na identycznej hali i obserwuj ich postęp na żywo. Awansuj w lidze od Brązu do Diamentu. Wyzwij znajomego kodem.
>
> ROZWIJAJ SIĘ
> • Gwiazdki za sprytne rozwiązania i rangi od Praktykanta do Głównego automatyka.
> • Rozbuduj swoją halę: kolory robota, skrzynie i pojemniki, okna, oświetlenie, roboty w tle.
>
> UCZCIWIE
> • Cofanie bez limitu, bez presji czasu (poza pojedynkami), bez „żyć”.
> • Podpowiedzi zdobywasz grając; możesz też je kupić. Pakiety wyglądu zmieniają tylko wygląd – nie dają przewagi.
>
> Grę stworzył inżynier robotyki – z sympatii do automatyki przemysłowej. Działa bez internetu.

*(Przed publikacją: sprawdzić, czy „działa bez internetu” nadal prawdziwe po dodaniu reklam; zaktualizować liczby.)*

## Teksty – angielski
**Name:** `Factory Sort – Robot Puzzle` (27)

**Short description:**
> Control the robot, sort the boxes and program its moves like a real engineer! (77)

**Full description:**
> Welcome to the factory floor! Your gantry robot is waiting for orders. Stack the boxes so each pallet holds a single product – easy, until 5-box pallets, gripper changes, slippery boxes, move limits and stretch wrap show up.
>
> THREE GAME MODES
> • Campaign – 150+ orders with a smooth difficulty curve and relaxing breaks.
> • Robot programming – write a program, press START and see if the robot finishes without a "program error". Beat the shortest solution.
> • Duels – race rival robots on an identical floor and watch their progress live. Climb the league from Bronze to Diamond. Challenge a friend with a code.
>
> GROW
> • Stars for clever solutions and ranks from Trainee to Chief Automation Engineer.
> • Build your factory: robot colours, crates and containers, windows, lighting, background robots.
>
> FAIR PLAY
> • Unlimited undo, no timers (except duels), no lives.
> • Earn hints by playing or buy them. Style packs change only the look – no advantage.
>
> Made by a robotics engineer who loves industrial automation. Works offline.

## Materiały graficzne (gotowe)
| Plik | Wymaganie Google Play | Uwagi |
|---|---|---|
| `build/store/icon_512.png` | ikona 512×512 PNG, bez przezroczystości | Google sam zaokrągla rogi |
| `build/store/feature_pl.png`, `feature_en.png` | grafika promocyjna 1024×500 | |
| `build/store/pl/screen_1..6.png`, `en/...` | zrzuty telefonu (min. 2), 9:16 | 1080×1920 z podpisami |
| `build/store/trailer.mp4` | film: link do YouTube | 27 s, 1080×1920 – wgraj na YouTube (np. jako „niepubliczny”) i wklej link |

Wymagania sprawdź w Play Console przy wgrywaniu – mogą się zmieniać.

## Odpowiedzi do formularzy (propozycje – zweryfikuj w Play Console)
- **Kategoria:** Gry → Logiczne. **Tagi:** łamigłówki, sortowanie, offline.
- **Grupa docelowa:** 13+ (nie kierujemy do dzieci).
- **Klasyfikacja treści (IARC):** brak przemocy, brak treści seksualnych, brak hazardu; zakupy w aplikacji – tak (po włączeniu płatności); interakcja użytkowników – nie (kody wyzwań przekazuje sam gracz).
- **Bezpieczeństwo danych:** zbierane opcjonalnie: *Opinie w aplikacji*, *Informacje o urządzeniu / identyfikatory* (losowy ID instalacji); cel: analityka/ulepszanie aplikacji; szyfrowane w transmisji (HTTPS); nieudostępniane; możliwość prośby o usunięcie.
- **Polityka prywatności:** `docs/privacy/index.html` – uzupełnij pola oznaczone [ ] i opublikuj (np. GitHub Pages: repozytorium → Settings → Pages → folder `/docs`, adres `https://rebary.github.io/fabryka-sork/privacy/`).

## Jak odtworzyć materiały po zmianach w grze
```bash
xvfb-run godot --path . --resolution 512x512 --script res://tools/store_icon.gd
```
```bash
xvfb-run godot --path . --resolution 1080x1920 --script res://tools/store_capture.gd
```
```bash
python3 tools/store_compose.py
```
Film: patrz komentarz na początku `tools/store_trailer.gd` (na komputerze z ekranem `xvfb-run` nie jest potrzebny).
