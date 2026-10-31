"""Składa eksport webowy Godota w JEDEN plik HTML, który działa po dwukliku z dysku (file://).

Przeglądarki blokują wczytywanie plików gry (.wasm, .pck) ze stron otwartych z dysku,
dlatego wszystko jest wbudowane w HTML: silnik (.wasm, skompresowany gzip + base64),
dane gry (.pck, base64), skrypt silnika, moduły dźwięku i obrazek startowy.

Użycie (z folderu projektu):
  1. Godot: Project -> Export -> preset "Web" -> eksport do folderu, np. build/web/index.html
     (albo w terminalu: godot --headless --export-debug "Web" build/web/index.html)
  2. python3 tools/build_single_html.py build/web FabrykaSort.html
"""
import base64, gzip, os, re, sys

src = sys.argv[1] if len(sys.argv) > 1 else "build/web"
out = sys.argv[2] if len(sys.argv) > 2 else "FabrykaSort.html"
name = "index"

def read(fn, mode="r"):
    with open(os.path.join(src, fn), mode) as f:
        return f.read()

html = read(f"{name}.html")
engine_js = read(f"{name}.js").replace("</script", "<\\/script")
wasm_b64 = base64.b64encode(gzip.compress(read(f"{name}.wasm", "rb"), 9)).decode()
pck_b64 = base64.b64encode(read(f"{name}.pck", "rb")).decode()
worklets = {}
for fn in os.listdir(src):
    if fn.endswith(".worklet.js"):
        worklets[fn] = read(fn)
splash = "data:image/png;base64," + base64.b64encode(read(f"{name}.png", "rb")).decode()
icon = "data:image/png;base64," + base64.b64encode(read(f"{name}.icon.png", "rb")).decode()

worklet_js = "{" + ",".join(
    '%s: %s' % (repr(k), repr(v).replace("</script", "<\\/script")) for k, v in worklets.items()
) + "}"

shim = """<script>
// Fabryka Sort - wersja w jednym pliku. Pliki gry są wbudowane poniżej, więc strona
// nie pobiera niczego z dysku ani z internetu (działa po dwukliku).
(function () {
	function decode(id) {
		const bin = atob(document.getElementById(id).textContent.trim());
		const out = new Uint8Array(bin.length);
		for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
		return out;
	}
	const origFetch = window.fetch ? window.fetch.bind(window) : null;
	window.fetch = function (input, init) {
		const url = typeof input === 'string' ? input : (input && input.url) || '';
		if (/\\.wasm(\\?|$)/.test(url)) {
			const body = new Blob([decode('gd-wasm')]).stream().pipeThrough(new DecompressionStream('gzip'));
			return Promise.resolve(new Response(body, { status: 200, headers: { 'Content-Type': 'application/wasm' } }));
		}
		if (/\\.pck(\\?|$)/.test(url)) {
			return Promise.resolve(new Response(decode('gd-pck'), { status: 200, headers: { 'Content-Type': 'application/octet-stream' } }));
		}
		return origFetch(input, init);
	};
	// Moduły dźwięku (AudioWorklet) z wbudowanego tekstu. Adres data: (a nie blob:),
	// bo przeglądarki odrzucają moduły blob: na stronach otwartych z dysku.
	const WORKLETS = %s;
	if (window.AudioWorklet && AudioWorklet.prototype.addModule) {
		const origAdd = AudioWorklet.prototype.addModule;
		AudioWorklet.prototype.addModule = function (url, opts) {
			const fn = String(url).split('/').pop().split('?')[0];
			if (WORKLETS[fn]) url = 'data:application/javascript;base64,' + btoa(unescape(encodeURIComponent(WORKLETS[fn])));
			return origAdd.call(this, url, opts);
		};
	}
	// Na stronie z dysku przeglądarka nie obsługuje service workerów - wyciszamy zbędne błędy.
	if (location.protocol === 'file:' && navigator.serviceWorker) {
		try {
			navigator.serviceWorker.getRegistration = function () { return Promise.resolve(undefined); };
			navigator.serviceWorker.register = function () { return Promise.reject(new Error('brak service workera')); };
		} catch (e) {}
	}
})();
</script>
<script type="application/octet-stream" id="gd-wasm">%s</script>
<script type="application/octet-stream" id="gd-pck">%s</script>
<script>
%s
</script>""" % (worklet_js, wasm_b64, pck_b64, engine_js)

tag = f'<script src="{name}.js"></script>'
assert html.count(tag) == 1, "Nie znaleziono znacznika skryptu silnika w HTML"
html = html.replace(tag, shim)
html = html.replace(f'src="{name}.png"', f'src="{splash}"')
html = re.sub(r'<link[^>]*rel="(icon|apple-touch-icon)"[^>]*>', f'<link rel="icon" type="image/png" href="{icon}">', html)
html = html.replace('<html lang="en">', '<html lang="pl">')
with open(out, "w") as f:
    f.write(html)
print(f"Zapisano {out} ({os.path.getsize(out) / 1e6:.1f} MB)")
