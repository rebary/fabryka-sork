/**
 * Fabryka Sort – odbiór i analiza ankiet graczy (Google Apps Script).
 * Instrukcja: docs/05_ANKIETA_I_ANALIZA.md
 *
 * 1. Wklej ten plik do edytora skryptów arkusza (Rozszerzenia -> Apps Script).
 * 2. Zmień SHARED_KEY na własny ciąg znaków (ten sam wpisz w scripts/feedback.gd).
 * 3. Uruchom raz funkcję setup() – utworzy zakładki "Odpowiedzi" i "Analiza".
 * 4. Wdróż jako aplikację internetową (Wdróż -> Nowe wdrożenie -> Aplikacja internetowa,
 *    "Wykonaj jako: ja", "Kto ma dostęp: każdy") i skopiuj adres kończący się na /exec.
 */

const SHARED_KEY = 'ZMIEN_MNIE';
const SHEET_ANSWERS = 'Odpowiedzi';
const SHEET_ANALYSIS = 'Analiza';
const HEADERS = [
  'Czas odbioru', 'ID instalacji', 'Wersja gry', 'Ocena (1-5)', 'Trudność', 'Ulubiony tryb',
  'Poleciłby', 'Co się podoba', 'Co poprawić', 'Gdzie w grze', 'Zlecenie', 'Program',
  'Gwiazdki', 'Podpowiedzi', 'Ukończone zadania', 'Czas gry (min)', 'Urządzenie', 'System',
  'Język', 'Czas w grze (UTC)', 'ID ankiety'
];
const ALLOWED = {
  difficulty: ['za łatwa', 'w sam raz', 'za trudna'],
  favorite_mode: ['kampania', 'programowanie', 'oba', 'żaden'],
  recommend: ['tak', 'może', 'nie']
};

function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);
    if (d.key !== SHARED_KEY) return json_({ ok: false, error: 'key' });
    const rating = Number(d.rating);
    if (!(rating >= 1 && rating <= 5)) return json_({ ok: false, error: 'rating' });
    // Ochrona przed duplikatami (gra ponawia wysyłkę, gdy nie dostanie potwierdzenia).
    const uid = text_(d.uid, 80);
    const cache = CacheService.getScriptCache();
    if (uid && cache.get(uid)) return json_({ ok: true, duplicate: true });
    const lock = LockService.getScriptLock();
    lock.waitLock(10000);
    try {
      sheet_(SHEET_ANSWERS).appendRow([
        new Date(), text_(d.install_id, 40), text_(d.version, 20), Math.round(rating),
        pick_(d.difficulty, 'difficulty'), pick_(d.favorite_mode, 'favorite_mode'), pick_(d.recommend, 'recommend'),
        safe_(text_(d.liked, 1000)), safe_(text_(d.improve, 1000)), text_(d.mode_at_survey, 20),
        num_(d.campaign_level), num_(d.program_number), num_(d.stars), num_(d.hints), num_(d.tasks_completed),
        num_(d.playtime_min), text_(d.device, 60), text_(d.os, 60), text_(d.locale, 20),
        text_(d.client_time, 30), uid
      ]);
    } finally {
      lock.releaseLock();
    }
    if (uid) cache.put(uid, '1', 21600);
    return json_({ ok: true });
  } catch (err) {
    return json_({ ok: false, error: String(err) });
  }
}

/** Uruchom raz: tworzy zakładki, nagłówki, wzory analizy i wykresy. */
function setup() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const a = sheet_(SHEET_ANSWERS);
  a.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]).setFontWeight('bold');
  a.setFrozenRows(1);
  a.setColumnWidth(8, 300);
  a.setColumnWidth(9, 300);

  let s = ss.getSheetByName(SHEET_ANALYSIS);
  if (s) ss.deleteSheet(s);
  s = ss.insertSheet(SHEET_ANALYSIS, 0);
  const R = SHEET_ANSWERS + '!';
  const rows = [
    ['Fabryka Sort – analiza ankiet', ''],
    ['Liczba ankiet', '=COUNTA(' + R + 'B2:B)'],
    ['Liczba graczy (unikalne instalacje)', '=IFERROR(COUNTA(UNIQUE(FILTER(' + R + 'B2:B,' + R + 'B2:B<>""))),0)'],
    ['Średnia ocena (1-5)', '=IFERROR(ROUND(AVERAGE(' + R + 'D2:D),2),"-")'],
    ['Średni czas gry (min)', '=IFERROR(ROUND(AVERAGE(' + R + 'P2:P),1),"-")'],
    ['Średnio ukończonych zadań', '=IFERROR(ROUND(AVERAGE(' + R + 'O2:O),1),"-")'],
    ['Wskaźnik polecenia (% tak − % nie)', '=IFERROR(ROUND(100*(COUNTIF(' + R + 'G2:G,"tak")-COUNTIF(' + R + 'G2:G,"nie"))/COUNTA(' + R + 'G2:G)),"-")'],
    ['', ''],
    ['Ocena', 'Liczba'],
    ['1', '=COUNTIF(' + R + 'D2:D,1)'],
    ['2', '=COUNTIF(' + R + 'D2:D,2)'],
    ['3', '=COUNTIF(' + R + 'D2:D,3)'],
    ['4', '=COUNTIF(' + R + 'D2:D,4)'],
    ['5', '=COUNTIF(' + R + 'D2:D,5)'],
    ['', ''],
    ['Trudność', 'Liczba'],
    ['za łatwa', '=COUNTIF(' + R + 'E2:E,"za łatwa")'],
    ['w sam raz', '=COUNTIF(' + R + 'E2:E,"w sam raz")'],
    ['za trudna', '=COUNTIF(' + R + 'E2:E,"za trudna")'],
    ['', ''],
    ['Ulubiony tryb', 'Liczba'],
    ['kampania', '=COUNTIF(' + R + 'F2:F,"kampania")'],
    ['programowanie', '=COUNTIF(' + R + 'F2:F,"programowanie")'],
    ['oba', '=COUNTIF(' + R + 'F2:F,"oba")'],
    ['żaden', '=COUNTIF(' + R + 'F2:F,"żaden")'],
    ['', ''],
    ['Poleciłby', 'Liczba'],
    ['tak', '=COUNTIF(' + R + 'G2:G,"tak")'],
    ['może', '=COUNTIF(' + R + 'G2:G,"może")'],
    ['nie', '=COUNTIF(' + R + 'G2:G,"nie")']
  ];
  s.getRange(1, 1, rows.length, 2).setValues(rows);
  s.getRange('A1').setFontSize(16).setFontWeight('bold');
  [9, 16, 21, 27].forEach(function (r) { s.getRange(r, 1, 1, 2).setFontWeight('bold').setBackground('#fff2cc'); });
  s.setColumnWidth(1, 300);

  // Wyniki według wersji gry (czy poprawki pomagają).
  s.getRange('D1').setValue('Według wersji gry').setFontWeight('bold');
  s.getRange('D2').setFormula('=IFERROR(QUERY(' + SHEET_ANSWERS + '!A1:U,"select C, count(D), avg(D), avg(P) where C is not null group by C label count(D) \'Ankiety\', avg(D) \'Średnia ocena\', avg(P) \'Śr. czas gry\'",1),"brak danych")');
  // Najnowsze komentarze.
  s.getRange('D12').setValue('Najnowsze komentarze (30)').setFontWeight('bold');
  s.getRange('D13').setFormula('=IFERROR(QUERY(' + SHEET_ANSWERS + '!A1:I,"select A, D, H, I where H is not null or I is not null order by A desc limit 30",1),"brak komentarzy")');
  s.setColumnWidth(6, 320);
  s.setColumnWidth(7, 320);

  // Wykresy.
  s.insertChart(s.newChart().setChartType(Charts.ChartType.COLUMN).addRange(s.getRange('A9:B14'))
    .setOption('title', 'Rozkład ocen').setOption('legend', { position: 'none' }).setPosition(32, 1, 0, 0).build());
  s.insertChart(s.newChart().setChartType(Charts.ChartType.PIE).addRange(s.getRange('A16:B19'))
    .setOption('title', 'Trudność').setPosition(32, 4, 0, 0).build());
  s.insertChart(s.newChart().setChartType(Charts.ChartType.PIE).addRange(s.getRange('A21:B25'))
    .setOption('title', 'Ulubiony tryb').setPosition(52, 1, 0, 0).build());
}

/** Test bez gry: Uruchom -> testPost, potem zajrzyj do zakładki "Odpowiedzi". */
function testPost() {
  const body = {
    key: SHARED_KEY, uid: 'test-' + Date.now(), install_id: 'test', version: '0.0.0', rating: 4,
    difficulty: 'w sam raz', favorite_mode: 'programowanie', recommend: 'tak',
    liked: 'Test z edytora', improve: '', mode_at_survey: 'menu', campaign_level: 1, program_number: 1,
    stars: 0, hints: 3, tasks_completed: 0, playtime_min: 0, device: 'edytor', os: '-', locale: 'pl', client_time: ''
  };
  Logger.log(doPost({ postData: { contents: JSON.stringify(body) } }).getContent());
}

function sheet_(name) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  return ss.getSheetByName(name) || ss.insertSheet(name);
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function text_(v, max) {
  return v === undefined || v === null ? '' : String(v).slice(0, max);
}

function num_(v) {
  const n = Number(v);
  return isFinite(n) ? n : '';
}

function pick_(v, field) {
  return ALLOWED[field].indexOf(v) >= 0 ? v : '';
}

/** Tekst zaczynający się od =, +, - lub @ arkusz potraktowałby jak wzór – zabezpieczenie. */
function safe_(s) {
  return /^[=+\-@]/.test(s) ? "'" + s : s;
}
