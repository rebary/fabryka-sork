# Publikacja w Google Play – tanio i wiarygodnie

Stan wiedzy na **31.10.2026**. Zasady Google zmieniają się często – przed każdym krokiem sprawdź aktualną stronę pomocy Play Console (linki na dole).
To nie jest porada prawna ani podatkowa – w sprawach podatków i działalności skonsultuj się z księgowym.

---

## 1. Ile to kosztuje (wariant minimalny)
| Pozycja | Koszt | Uwagi |
|---|---|---|
| Konto Google Play Developer | jednorazowo ok. 25 USD | jedyny obowiązkowy wydatek; kwotę sprawdź przy rejestracji |
| Polityka prywatności (strona WWW) | 0 zł | np. GitHub Pages albo Google Sites |
| Grafiki do sklepu | 0 zł | zrzuty z gry + ikona/grafika robione samodzielnie |
| Własna domena (opcjonalnie) | ok. kilkudziesięciu zł/rok | e-mail i strona w domenie dodają wiarygodności |
| Prawdziwe płatności i reklamy | 0 zł na start | prowizja Google od sprzedaży i udział sieci reklamowej są potrącane z przychodu |

## 2. Rekomendowana kolejność (najtaniej i najbezpieczniej)
1. **Pierwsza publiczna wersja bez płatności i bez reklam** (gra darmowa, podpowiedzi tylko darmowe).
   - Prostszy formularz „Bezpieczeństwo danych” (gra nie zbiera danych – zapis jest tylko na telefonie).
   - Konto bez sprzedaży nie musi mieć profilu sprzedawcy (patrz pkt 4 – adres).
   - Zbierasz opinie i oceny, zanim zaczniesz zarabiać.
2. **Aktualizacja z zarabianiem** (reklama za nagrodą + pakiety podpowiedzi), gdy testy pokażą, że gracze wracają.

## 3. Krok po kroku
### 3.1. Konto dewelopera
1. https://play.google.com/console → załóż konto **osobiste** (Personal).
2. Weryfikacja: dokument tożsamości, telefon, e-mail. Może potrwać kilka dni.
3. **Konto osobiste założone po 13.11.2023 musi przejść test zamknięty**, zanim dostanie dostęp do publikacji produkcyjnej.
   - Według poradników (stan 2026): **co najmniej 12 testerów zapisanych nieprzerwanie przez 14 dni**. Dokładne warunki sprawdź na oficjalnej stronie Google w chwili zakładania konta.
   - Każda nowa aplikacja na koncie osobistym przechodzi to osobno. Aktualizacje już opublikowanej – nie.
   - Testy wewnętrzne (internal testing) **nie liczą się** do tego wymogu.

### 3.2. Przygotowanie pliku do sklepu (AAB)
1. Godot: **Project → Install Android Build Template…**.
2. W presecie Android: **Gradle Build → Use Gradle Build: włączone**, format eksportu **AAB**.
3. **Docelowe API: od 31.08.2026 nowe aplikacje i aktualizacje muszą celować w Android 16 (API 36).** Według zgłoszeń użytkowników Godot 4.7 ustawia 36 domyślnie – sprawdź pole **Target SDK** w presecie przed wysłaniem.
4. **Klucz wysyłania (upload key):** utwórz własny keystore (`keytool`, jak w instrukcji instalacji, ale z własnym hasłem i aliasem). Wpisz go w **Keystore → Release**.
   - **Zrób 2 kopie zapasowe klucza i haseł** (np. pendrive + menedżer haseł).
   - Włącz **Play App Signing** (Google przechowuje klucz podpisu aplikacji; utratę klucza wysyłania da się wtedy naprawić przez pomoc Google).
5. Odznacz **Export With Debug** → eksportuj `.aab`.
6. Przed wersją produkcyjną w `scripts/store.gd` zostanie podłączony prawdziwy sklep (osobny etap). Przycisk „Poziom” zniknie sam w wersji release.

### 3.3. Karta aplikacji w sklepie
| Element | Wymagania (sprawdź aktualne w Play Console) |
|---|---|
| Nazwa | do 30 znaków; sprawdź, czy nie jest zajęta i nie narusza znaków towarowych |
| Krótki opis | do 80 znaków |
| Pełny opis | do 4000 znaków (szkic w `04_KAMPANIA_MARKETINGOWA.md`) |
| Ikona | 512×512 PNG |
| Grafika promocyjna | 1024×500 |
| Zrzuty ekranu telefonu | co najmniej 2 (zalecane 6–8, pionowe 9:16, z krótkimi podpisami) |
| Film (opcjonalnie) | link do YouTube, 15–30 s prawdziwej rozgrywki |

### 3.4. Obowiązkowe formularze (bezpłatne)
- **Polityka prywatności** – adres strony WWW. Na start: „gra nie zbiera danych osobowych; postęp jest zapisany wyłącznie na urządzeniu”. Po dodaniu reklam/płatności – zaktualizować.
- **Bezpieczeństwo danych (Data safety)** – zgodnie z prawdą: obecnie brak zbierania danych.
- **Klasyfikacja treści (IARC)** – kwestionariusz; gra logiczna bez przemocy.
- **Grupa docelowa** – nie kieruj gry do dzieci poniżej 13 lat (wtedy obowiązują znacznie ostrzejsze zasady programu „Rodzina”, m.in. dotyczące reklam).
- **Reklamy** – zaznacz „nie” w wersji bez reklam; zmień przy aktualizacji z reklamami.
- **Dostęp do aplikacji** – „wszystkie funkcje dostępne bez logowania”.

### 3.5. Ścieżka testów → produkcja
1. **Test wewnętrzny** (do 100 osób, bez przeglądu) – szybkie sprawdzenie, czy AAB się instaluje.
2. **Test zamknięty** – lista e-mail testerów (min. 12, przez 14 dni). Testerzy dołączają linkiem i instalują grę ze sklepu.
3. Po 14 dniach: **wniosek o dostęp do produkcji** (pytania o przebieg testu – odpowiadaj konkretnie: ile osób, jakie poprawki wprowadzone).
4. **Produkcja**: na początek tylko **Polska** (soft launch), potem kolejne kraje.

## 4. Adres i dane widoczne publicznie – przeczytaj przed rejestracją
- Na koncie osobistym Google pokazuje w sklepie m.in. **imię i nazwisko oraz adres**.
- Konta, które **zarabiają przez sprzedaż** (płatne aplikacje / zakupy w aplikacji), muszą mieć widoczny **pełny adres** (pochodzi z profilu płatności Google).
- Jeśli nie chcesz pokazywać adresu domowego: rozważ adres firmy/biura. Czy wirtualne biuro jest akceptowane – sprawdź w aktualnej pomocy Google przed wydaniem pieniędzy.

## 5. Podatki i formalności (orientacyjnie)
- Przychód z gry to przychód z działalności. Na start może wystarczyć **działalność nierejestrowana**: w 2026 r. limit to **10 813,50 zł przychodu na kwartał** (225% płacy minimalnej). Limit nie przechodzi na kolejny kwartał; po przekroczeniu masz 7 dni na wpis do CEIDG. Warunek: brak działalności gospodarczej w ostatnich 60 miesiącach.
- Wypłaty z Google, waluty, VAT i rozliczenie PIT – **ustal z księgowym przed włączeniem sprzedaży**.
- **Umowa o pracę:** sprawdź, czy umowa z pracodawcą nie zawiera zapisów o prawach do utworów lub zakazie konkurencji, i nie używaj sprzętu ani czasu pracy firmy.

## 6. Wiarygodność gry – tanie sposoby (bez łamania zasad)
1. **Dopracowana karta sklepu**: zrzuty z podpisami („Steruj robotem”, „Zaprogramuj ruchy”, „Rozbuduj halę”), krótki film z prawdziwej rozgrywki.
2. **Prosta strona gry** (GitHub Pages, 0 zł): opis, zrzuty, polityka prywatności, kontakt. Najlepiej z e-mailem we własnej domenie.
3. **Twoja historia**: twórca jest inżynierem robotyki – to autentyczny wyróżnik (sekcja „O twórcy” na stronie i w opisie).
4. **Szybkie odpowiedzi na opinie** w Play Console i widoczne aktualizacje (lista zmian w każdej wersji).
5. **Testerzy z testu zamkniętego**: poproś o szczere uwagi przez prywatną opinię (funkcja testów). Po premierze mogą wystawić prawdziwą ocenę, jeśli chcą.
6. **Czego nie robić:** kupowanie opinii, instalacji lub „pakietów testerów”, proszenie wyłącznie o 5 gwiazdek, reklamy pokazujące nieistniejącą rozgrywkę. Grozi to usunięciem aplikacji lub konta i naraża na zarzut wprowadzania w błąd.

## Źródła (sprawdzone 31.10.2026)
- Wymagane docelowe API (Google): https://developer.android.com/google/play/requirements/target-sdk oraz https://support.google.com/googleplay/android-developer/answer/11926878
- Godot 4.7 – eksport Android, AAB/Gradle: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html ; wątek o Target SDK 36: https://forum.godotengine.org/t/how-to-target-latest-android-sdk/142631
- Test zamknięty 12 testerów/14 dni (poradniki, nie Google): https://ontest.app/blog/google-play-12-testers-14-days-requirement-explained ; https://www.testerscommunity.com/blog/google-play-closed-testing-requirements-2026
- Konto osobiste i dane widoczne publicznie (Google): https://support.google.com/googleplay/android-developer/answer/13628312 ; adres przy kontach sprzedających: https://support.google.com/googleplay/android-developer/answer/13634081
- Działalność nierejestrowana 2026: https://direct.money.pl/artykuly/porady/dzialalnosc-nierejestrowana-2026-limit-10-813,50-zl,-po-przekroczeniu-7-dni-na-ceidg ; https://poradnikprzedsiebiorcy.pl/-limit-przychodu-dla-dzialalnosci-nierejestrowanej
