# Plan wdrożenia – Fabryka Sort

Założenia: 1 osoba, ok. **5 h tygodniowo**, budżet bliski 0 zł, start na Androidzie w Polsce.
Czasy są **szacunkami z dużą niepewnością** (±50%). Progi decyzji to **propozycje do korekty** po pierwszych danych – nie są to uniwersalne benchmarki branżowe.

---

## Mapa etapów
| Etap | Tygodnie (szac.) | Cel | Warunek przejścia dalej |
|---|---|---|---|
| 0. Testy własne | 1 | Zagrać w oba tryby, spisać błędy | Brak błędów blokujących grę |
| 1. Testy z ludźmi (APK) | 2–3 | 3–5 osób gra bez instrukcji | Patrz „Decyzja po testach” |
| 2. Poprawki + przygotowanie sklepu | 4–6 | Poprawki z testów, konto Play, polityka prywatności, grafiki | AAB instaluje się z testu wewnętrznego |
| 3. Test zamknięty Google Play | 7–9 | ≥12 testerów przez 14 dni | Dostęp do produkcji przyznany |
| 4. Premiera w Polsce (bez płatności) | 10–11 | Pierwsi prawdziwi gracze, opinie | Zebrane dane z 2–4 tygodni |
| 5. Zarabianie (aktualizacja) | 12–16 | Reklama za nagrodą + pakiety podpowiedzi | Działa na urządzeniach testowych, formularze zaktualizowane |
| 6. Ekspansja i rozwój | 16+ | Wersja angielska, kolejne kraje, aktualizacje co 2–4 tyg. | Retencja stabilna lub rosnąca |

## Etap 0–1: testy (zaczynamy tutaj)
**Zadania:**
1. Zbuduj APK wg `01_INSTALACJA_NA_TELEFONIE.md`, zainstaluj na swoim telefonie.
2. Zagraj 30 min w kampanię i 15 min w programowanie. Notuj: błędy, nudne momenty, niejasne komunikaty.
3. Wyślij APK 3–5 osobom (najlepiej różnym: ktoś grający w gry mobilne, ktoś „nie-gracz”, ktoś z branży).
4. Obserwuj, jeśli możesz, pierwsze 5 minut gry testera – bez podpowiadania.

**Ankieta dla testera (5 minut):**
1. Czy po pierwszej minucie wiedziałeś, co trzeba zrobić? (tak / trochę / nie)
2. Do którego zlecenia doszedłeś? Ile programów ukończyłeś?
3. Ile minut grałeś przy pierwszym podejściu?
4. Czy wróciłeś do gry następnego dnia sam z siebie? (tak/nie)
5. Co było najfajniejsze? Co najbardziej irytowało?
6. Który tryb wolisz: kampania czy programowanie? Dlaczego?
7. Czy kupiłbyś pakiet podpowiedzi albo obejrzał reklamę za podpowiedź? (tak / może / nie)
8. Model telefonu i czy gra działała płynnie.

**Decyzja po testach (propozycja progów dla 5 osób):**
- **Kontynuować**, jeśli co najmniej 3 z 5 osób: zrozumiały zasady same, grały ≥10 minut i chcą grać dalej.
- **Poprawić**, jeśli zasady są niejasne lub frustracja pojawia się w konkretnym miejscu (np. skok trudności) – poprawka i powtórka testu z 2–3 nowymi osobami.
- **Zmienić kierunek**, jeśli większość nudzi się w kilka minut mimo zrozumienia zasad – wtedy rozważamy, który tryb lub mechanika budziła największe zainteresowanie (np. programowanie jako główna gra).

## Etap 2: przygotowanie sklepu
| Zadanie | Szac. czas | Zależność |
|---|---|---|
| Poprawki z testów | 3–10 h | Etap 1 |
| Ostateczna nazwa + sprawdzenie zajętości (Google Play, znaki towarowe EUIPO) | 1 h | – |
| Nazwa pakietu (np. `pl.nazwisko.fabrykasort`) – nie do zmiany po publikacji | 0,5 h | nazwa |
| Konto Google Play (25 USD, weryfikacja do kilku dni) | 1 h + czekanie | – |
| Strona gry + polityka prywatności (GitHub Pages) | 2–3 h | – |
| Ikona 512×512, grafika 1024×500, 6–8 zrzutów z podpisami | 3–5 h | stabilna wersja |
| Film 15–30 s z rozgrywki (Godot potrafi nagrać film: opcja `--write-movie`) | 2 h | stabilna wersja |
| Eksport AAB z kluczem release + kopie zapasowe klucza | 1–2 h | konto |

## Etap 3: test zamknięty (≥12 osób, 14 dni)
- Źródła testerów (bez kupowania): rodzina, znajomi, współpracownicy (prywatnie, poza godzinami pracy), grupy hobbystyczne, testerzy z etapu 1.
- Zbierz **15–20 osób** – część zawsze odpada.
- W trakcie: 1–2 aktualizacje z poprawkami (to pokazuje Google aktywny test).
- Pod koniec: krótka ankieta (ta sama co wyżej) – odpowiedzi przydadzą się we wniosku o produkcję.

## Etap 4: premiera w Polsce
- Wersja **bez płatności i reklam** (prostsze formularze, brak publicznego adresu sprzedawcy).
- Kampania startowa wg `04_KAMPANIA_MARKETINGOWA.md` (budżet 0 zł).
- **Dane do zbierania** (Play Console pokazuje je bez dodatkowych narzędzi): odwiedziny karty sklepu → instalacje (konwersja), odinstalowania, oceny i opinie, awarie (ANR/crash).
- **Do rozważenia przed premierą:** prosta analityka w grze (np. ukończenie samouczka, retencja D1/D7). Wymaga to aktualizacji polityki prywatności i formularza danych oraz zgody gracza w UE – decyzja i wdrożenie jako osobne zadanie.

## Etap 5: zarabianie
- Podłączenie **Google Play Billing** (pakiety podpowiedzi) i **reklam za nagrodą** (np. AdMob) – wtyczki do Godota, testy na urządzeniu, okno zgody na reklamy w UE.
- Aktualizacja: polityka prywatności, „Bezpieczeństwo danych”, deklaracja reklam, profil płatności (publiczny adres!), księgowość (patrz `02_PUBLIKACJA_GOOGLE_PLAY.md` pkt 4–5).
- Pierwszy pomiar: jaki odsetek graczy ogląda reklamę lub kupuje – dopiero na tej podstawie prognoza przychodu (wariant ostrożny/bazowy/optymistyczny).

## Ryzyka
| Ryzyko | Wpływ | Co robimy |
|---|---|---|
| Za mało testerów do testu zamkniętego | Opóźnienie premiery | Zbieranie listy już w etapie 1, zapas 15–20 osób |
| Gra nie wciąga | Strata czasu na publikację | Decyzja po etapie 1, zanim zapłacisz za konto |
| Słaba wydajność na tanich telefonach | Złe opinie | Testy na różnych telefonach, przełącznik efektów |
| Utrata klucza podpisu | Brak możliwości aktualizacji | Play App Signing + 2 kopie klucza |
| Zmiany zasad Google (API, weryfikacja) | Odrzucenie wersji | Sprawdzanie wymagań przed każdym wydaniem |
| Konflikt z umową o pracę | Problemy prawne | Sprawdzenie umowy przed publikacją |
| Rozrastanie się projektu (nowe tryby) | Gra nigdy nie wychodzi | Zamrożenie funkcji do premiery; pomysły do osobnej listy |

## Lista pomysłów „po premierze” (nie teraz)
- Trzeci tryb / osobna gra: kilka ramion manipulatorów podających sobie paczki.
- Wersja angielska i kolejne języki.
- Profesjonalna grafika (robot, kartony, ikona, zrzuty).
- Wersja na iOS (wymaga Maca lub usługi budowania w chmurze i konta Apple Developer).
