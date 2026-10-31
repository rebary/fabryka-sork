# Instalacja gry na telefonie z Androidem (do testów)

Instrukcja dla **Godot 4.7.2** i komputera z Windows (na macOS/Linux kroki są takie same, inne są tylko instalatory).
Cel: plik `.apk`, który zainstalujesz na swoim telefonie i wyślesz testerom.

> **Ważne:** to wersja testowa (debug). Ma widoczny przycisk „Poziom” i sklep w trybie testowym. Do Google Play wysyła się inny plik (`.aab`) – patrz `02_PUBLIKACJA_GOOGLE_PLAY.md`.

Szacowany czas za pierwszym razem: 1–2 godziny (głównie pobieranie). Kolejne eksporty: 1–2 minuty.

## Najszybszy test: jeden plik HTML (bez instalacji)
Plik `FabrykaSort.html` zawiera całą grę. Otwórz go dwuklikiem w **Chrome lub Edge** na komputerze – gra działa bez internetu i bez instalowania czegokolwiek. Postęp zapisuje się w tej przeglądarce.

Jak zbudować go ponownie po zmianach w grze (z folderu projektu):
```bash
godot --headless --export-debug "Web" build/web/index.html
```
```bash
python3 tools/build_single_html.py build/web FabrykaSort.html
```
Do eksportu potrzebne są szablony eksportu Godota 4.7.2 (Editor → Manage Export Templates) i preset „Web” (Project → Export → Add… → Web, bez obsługi wątków – „Thread Support” wyłączone).

---

## Krok 1. Zainstaluj Javę (JDK 17)
Godot potrzebuje Javy do budowania aplikacji na Androida. Oficjalna instrukcja Godota 4.7 zaleca **JDK 17**.

1. Wejdź na https://adoptium.net → wybierz **Temurin 17 (LTS)** → Windows x64 → plik `.msi`.
2. Zainstaluj. W instalatorze zaznacz opcję **„Set JAVA_HOME variable”**.
3. Zapamiętaj folder instalacji, np. `C:\Program Files\Eclipse Adoptium\jdk-17...`.

Sprawdzenie: w Wierszu poleceń (`cmd`) wpisz:
```bash
java -version
```
Oczekiwany wynik: tekst z „17” w numerze wersji.

## Krok 2. Zainstaluj Android SDK
Najprościej przez **Android Studio** (darmowe), które pobiera SDK za Ciebie.

1. Pobierz Android Studio: https://developer.android.com/studio i zainstaluj (opcje domyślne).
2. Uruchom → **More Actions → SDK Manager**.
3. Zakładka **SDK Platforms**: zaznacz **Android 16 (API 36)** i **Android 15 (API 35)**.
4. Zakładka **SDK Tools**: zaznacz **Android SDK Build-Tools**, **Android SDK Command-line Tools (latest)**, **Android SDK Platform-Tools**, **NDK (Side by side)** i **CMake**.
   Dokładne wersje NDK i CMake podaje oficjalna instrukcja Godota (link na dole). Jeśli eksport zgłosi brak konkretnej wersji, doinstaluj dokładnie tę wersję.
5. Zapamiętaj ścieżkę **Android SDK Location** (u góry okna), zwykle `C:\Users\<Ty>\AppData\Local\Android\Sdk`.

## Krok 3. Ustaw ścieżki w Godocie
1. Godot → **Editor → Editor Settings → Export → Android**.
2. **Java SDK Path**: folder JDK z kroku 1.
3. **Android SDK Path**: folder z kroku 2.
4. **Debug Keystore**: Godot zwykle tworzy go sam przy pierwszym eksporcie. Jeśli pojawi się błąd o braku klucza debug, utwórz go poleceniem (w `cmd`, w dowolnym folderze):
   ```bash
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
   ```
   i wskaż powstały plik `debug.keystore` w polu Debug Keystore (użytkownik: `androiddebugkey`, hasło: `android`).

## Krok 4. Pobierz szablony eksportu
1. **Editor → Manage Export Templates → Download and Install**.
2. Wersja szablonów musi być **dokładnie taka jak edytora: 4.7.2**.

## Krok 5. Utwórz ustawienia eksportu (raz na projekt)
1. **Project → Export… → Add… → Android**.
2. Najważniejsze pola:
   - **Package → Unique Name**: np. `pl.twojenazwisko.fabrykasort`. **Po publikacji w Google Play tej nazwy nie da się zmienić**, więc wybierz ją świadomie. Tylko małe litery, cyfry i kropki.
   - **Version → Code**: `1` (przy każdej nowej wersji wysyłanej do Google Play zwiększasz o 1).
   - **Version → Name**: `0.1.0`.
   - **Architectures**: zaznacz **arm64-v8a** (nowe telefony). Opcjonalnie **armeabi-v7a** (bardzo stare telefony).
   - **Permissions**: zaznacz tylko **Internet** – potrzebne do wysyłania ankiet (`05_ANKIETA_I_ANALIZA.md`). Inne uprawnienia nie są potrzebne.
3. Zamknij okno (ustawienia zapiszą się w pliku `export_presets.cfg`; jest on w `.gitignore`, bo zawiera ścieżki do kluczy).

## Krok 6. Zbuduj plik APK
1. **Project → Export… →** wybierz preset Android → **Export Project…**.
2. Zostaw zaznaczone **Export With Debug**.
3. Nazwa pliku: `fabryka_sort_test.apk` → **Save**.

Oczekiwany wynik: plik `.apk` (kilkadziesiąt MB) w wybranym folderze.

## Krok 7. Zainstaluj na swoim telefonie
**Sposób A – kablem jednym kliknięciem (wygodny przy częstych testach):**
1. Na telefonie: **Ustawienia → Informacje o telefonie →** stuknij 7 razy w **Numer kompilacji** (włączysz Opcje programisty).
2. **Ustawienia → Opcje programisty →** włącz **Debugowanie USB**.
3. Podłącz telefon kablem i zaakceptuj na telefonie pytanie o zaufanie do komputera.
4. W Godocie, w prawym górnym rogu pojawi się ikona Androida → kliknij. Gra zbuduje się i uruchomi na telefonie.

**Sposób B – przez plik:**
1. Skopiuj `.apk` na telefon (kabel, Google Drive, e-mail).
2. Otwórz plik na telefonie. Android zapyta o zgodę na instalację z tego źródła („Instaluj nieznane aplikacje”) – zezwól dla aplikacji, z której otwierasz plik.
3. Zainstaluj.

## Krok 8. Wysłanie testerom (przed Google Play)
- Wrzuć `.apk` na Google Drive i wyślij link 3–5 zaufanym osobom z krótką instrukcją z kroku 7B.
- Poproś ich o szczerą opinię wg ankiety z `03_PLAN_WDROZENIA.md`.
- **Uwaga na przyszłość:** Google wprowadza obowiązkową weryfikację twórców także dla aplikacji instalowanych spoza sklepu. Od 30.09.2026 obowiązuje w Brazylii, Indonezji, Singapurze i Tajlandii, globalnie zapowiedziano ją na 2027 r. W Polsce na dziś (31.10.2026) instalacja z pliku działa po staremu, ale docelowo testy warto prowadzić przez Google Play (zamknięte testy).

---

## Typowe problemy
| Problem | Rozwiązanie |
|---|---|
| „Export templates not found” | Krok 4 – szablony muszą mieć wersję 4.7.2 |
| Błąd o Java / JDK | Sprawdź ścieżkę z kroku 3; musi wskazywać folder JDK, nie JRE |
| Błąd o brakującej wersji NDK/Build-Tools | Doinstaluj dokładnie tę wersję w SDK Manager (krok 2) |
| „App not installed” na telefonie | Odinstaluj starszą wersję gry (inny klucz podpisu) albo zwolnij miejsce |
| Telefon nie widoczny w Godocie | Inny kabel (do danych, nie tylko ładowania), włącz Debugowanie USB, zaakceptuj komunikat na telefonie |
| Gra działa wolno | Menu → „Efekty graficzne: wył.” i zanotuj model telefonu – to ważna informacja z testu |

## Źródła (sprawdzone 31.10.2026)
- Oficjalna instrukcja Godot 4.7 – eksport na Androida (wersje JDK/SDK/NDK): https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html
- Weryfikacja twórców Androida – harmonogram: https://www.androidauthority.com/android-sideloading-changes-timeline-3679204/ oraz https://www.gsmarena.com/google_android_developer_verification_app_sideloading_changes_timeline-news-73354.php
