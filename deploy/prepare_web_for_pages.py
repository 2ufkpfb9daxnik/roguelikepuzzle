import gzip
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "build", "web")
CHUNK_SIZE = 20 * 1024 * 1024

START_BLOCK = """\t\tsetStatusMode('progress');
\t\tengine.startGame({
\t\t\t'onProgress': function (current, total) {
\t\t\t\tif (current > 0 && total > 0) {
\t\t\t\t\tstatusProgress.value = current;
\t\t\t\t\tstatusProgress.max = total;
\t\t\t\t} else {
\t\t\t\t\tstatusProgress.removeAttribute('value');
\t\t\t\t\tstatusProgress.removeAttribute('max');
\t\t\t\t}
\t\t\t},
\t\t}).then(() => {
\t\t\tsetStatusMode('hidden');
\t\t}, displayFailureNotice);"""

REPLACEMENT = """\t\tsetStatusMode('progress');
\t\tstartChunkedGame(engine, statusProgress, setStatusMode, displayFailureNotice);"""

LOADER = """
async function startChunkedGame(engine, statusProgress, setStatusMode, displayFailureNotice) {
\tconst CHUNK_COUNT = __CHUNK_COUNT__;
\tconst PCK_SIZE = __PCK_SIZE__;
\tconst WASM_CHUNK_COUNT = __WASM_CHUNK_COUNT__;
\tconst WASM_SIZE = __WASM_SIZE__;
\ttry {
\t\tconst pck = new Uint8Array(PCK_SIZE);
\t\tlet loaded = 0;
\t\tfor (let i = 0; i < CHUNK_COUNT; i++) {
\t\t\tconst url = `index.pck.part${String(i).padStart(3, '0')}`;
\t\t\tconst response = await fetch(url);
\t\t\tif (!response.ok) throw new Error(`Failed to load ${url}: ${response.status}`);
\t\t\tconst data = new Uint8Array(await response.arrayBuffer());
\t\t\tpck.set(data, loaded);
\t\t\tloaded += data.length;
\t\t\tstatusProgress.value = loaded;
\t\t\tstatusProgress.max = PCK_SIZE;
\t\t}
\t\tconst wasm = new Uint8Array(WASM_SIZE);
\t\tlet wasmLoaded = 0;
\t\tfor (let i = 0; i < WASM_CHUNK_COUNT; i++) {
\t\t\tconst url = `index.wasm.part${String(i).padStart(3, '0')}`;
\t\t\tconst response = await fetch(url);
\t\t\tif (!response.ok) throw new Error(`Failed to load ${url}: ${response.status}`);
\t\t\tconst data = new Uint8Array(await response.arrayBuffer());
\t\t\twasm.set(data, wasmLoaded);
\t\t\twasmLoaded += data.length;
\t\t\tstatusProgress.value = wasmLoaded;
\t\t\tstatusProgress.max = WASM_SIZE;
\t\t}
\t\tglobalThis.__GODOT_WASM_URL = URL.createObjectURL(new Blob([wasm.buffer], { type: 'application/wasm' }));
\t\tawait engine.init('index');
\t\tawait engine.preloadFile(pck.buffer, 'index.pck');
\t\tengine.config.args = ['--main-pack', 'index.pck'].concat(engine.config.args || []);
\t\tawait engine.start();
\t\tsetStatusMode('hidden');
\t} catch (err) {
\t\tdisplayFailureNotice(err);
\t}
}
"""


def main() -> int:
    html_path = os.path.join(WEB, "index.html")
    pck_path = os.path.join(WEB, "index.pck")
    wasm_path = os.path.join(WEB, "index.wasm")
    if not (os.path.isfile(html_path) and os.path.isfile(pck_path) and os.path.isfile(wasm_path)):
        print("build/web/index.html, index.pck, index.wasm が必要です", file=sys.stderr)
        return 1

    # Split the PCK into chunks under Cloudflare Pages' 25 MiB per-file limit.
    pck_size = os.path.getsize(pck_path)
    chunk_count = (pck_size + CHUNK_SIZE - 1) // CHUNK_SIZE
    with open(pck_path, "rb") as src:
        for i in range(chunk_count):
            part_path = os.path.join(WEB, f"index.pck.part{i:03d}")
            with open(part_path, "wb") as dst:
                remaining = min(CHUNK_SIZE, pck_size - i * CHUNK_SIZE)
                while remaining > 0:
                    buf = src.read(min(1024 * 1024, remaining))
                    if not buf:
                        raise RuntimeError("unexpected end of PCK")
                    dst.write(buf)
                    remaining -= len(buf)
    os.remove(pck_path)

    # Split the WASM into chunks as well (Cloudflare Pages allows 25 MiB per file).
    wasm_size = os.path.getsize(wasm_path)
    wasm_chunk_count = (wasm_size + CHUNK_SIZE - 1) // CHUNK_SIZE
    with open(wasm_path, "rb") as src:
        for i in range(wasm_chunk_count):
            part_path = os.path.join(WEB, f"index.wasm.part{i:03d}")
            with open(part_path, "wb") as dst:
                remaining = min(CHUNK_SIZE, wasm_size - i * CHUNK_SIZE)
                while remaining > 0:
                    buf = src.read(min(1024 * 1024, remaining))
                    if not buf:
                        raise RuntimeError("unexpected end of WASM")
                    dst.write(buf)
                    remaining -= len(buf)
    os.remove(wasm_path)

    # Patch the generated engine JS so Engine.load uses the Blob URL for WASM.
    js_path = os.path.join(WEB, "index.js")
    with open(js_path, "r", encoding="utf-8") as f:
        js = f.read()
    needle = "loadPromise = preloader.loadPromise(`${loadPath}.wasm`, size, true);"
    if needle not in js:
        print("index.js のWASMロード箇所が見つかりません", file=sys.stderr)
        return 1
    js = js.replace(
        needle,
        "loadPromise = preloader.loadPromise(globalThis.__GODOT_WASM_URL || `${loadPath}.wasm`, size, true);"
    )
    with open(js_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(js)

    with open(html_path, "r", encoding="utf-8") as f:
        html = f.read()
    if START_BLOCK not in html:
        print("index.html の startGame ブロックが見つかりません", file=sys.stderr)
        return 1
    html = html.replace(START_BLOCK, REPLACEMENT)
    loader = LOADER.replace("__CHUNK_COUNT__", str(chunk_count)).replace("__PCK_SIZE__", str(pck_size))
    loader = loader.replace("__WASM_CHUNK_COUNT__", str(wasm_chunk_count)).replace("__WASM_SIZE__", str(wasm_size))
    html = html.replace("const engine = new Engine(GODOT_CONFIG);", "const engine = new Engine(GODOT_CONFIG);" + loader)

    # ?????: ??????????????????? ????????
    mobile_patch = """<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Roguelike Puzzle">
<meta name="theme-color" content="#000000">
<style>
html, body {
  width:100%; height:100%; margin:0; padding:0;
  background:#000; overflow:hidden;
  -webkit-text-size-adjust:100%;
  -webkit-user-select:none; user-select:none;
  -webkit-touch-callout:none;
  -webkit-tap-highlight-color:transparent;
  overscroll-behavior:none;
  touch-action:manipulation;
}
/* Godot ????????????????????????? */
html, body { width:100%; height:100%; overflow:hidden; }
#canvas, canvas {
  margin:0 !important; padding:0 !important; display:block;
  width:100% !important; height:100% !important;
}
@supports (height: 100dvh) {
  html, body { height:100dvh; }
}
/* ????????????90????????????????iPhone ? orientation.lock ???? */
@media (orientation: portrait) {
  #canvas, canvas {
    width:100vh !important; height:100vw !important;
    position:fixed; left:50%; top:50%;
    transform:translate(-50%, -50%) rotate(90deg);
  }
}
</style>
<script>
async function __lockLandscape() {
  try {
    const el = document.documentElement;
    if (el.requestFullscreen) { await el.requestFullscreen({ navigationUI: "hide" }); }
    else if (el.webkitRequestFullscreen) { el.webkitRequestFullscreen(); }
  } catch (e) {}
  try {
    if (screen.orientation && screen.orientation.lock) { await screen.orientation.lock("landscape"); }
  } catch (e) {}
}
document.addEventListener("click", __lockLandscape, { once: true });
document.addEventListener("touchstart", __lockLandscape, { once: true, passive: true });
document.addEventListener("keydown", __lockLandscape, { once: true });
</script>
"""
    html = html.replace(
        '<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0">',
        '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">',
    )
    html = html.replace("</head>", mobile_patch + "</head>")

    with open(html_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(html)

    headers = """/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
/index.pck.part*
  Content-Type: application/octet-stream
/index.wasm.part*
  Content-Type: application/octet-stream
"""
    with open(os.path.join(WEB, "_headers"), "w", encoding="utf-8", newline="\n") as f:
        f.write(headers)

    worker_path = os.path.join(WEB, "_worker.js")
    if os.path.exists(worker_path):
        os.remove(worker_path)

    print(f"prepared build/web: pck={chunk_count} chunks/{pck_size} bytes, wasm={wasm_chunk_count} chunks/{wasm_size} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
