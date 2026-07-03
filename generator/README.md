# Chattr Lab — generador experimental con Gemini

Página aislada donde pegás el resumen de los últimos partidos y **Gemini 2.5
Flash** (gratis) genera una tanda de posts al estilo Chattr, en el momento, en
tu navegador. No toca `chattr/`, `threadit/`, ni ningún `data/*.json` — es un
experimento aparte, nada se guarda (refrescar la página borra todo).

## ⚠️ Sobre la API key

Este sitio es **100% estático, sin servidor**. Eso significa que la llamada a
Gemini se hace directo desde el navegador, y la API key queda **visible en el
código fuente de la página** para cualquiera que la inspeccione. No hay forma
de evitar esto sin agregar un backend (que este proyecto, a propósito, no
tiene). La mitigación es restringir la key para que solo funcione desde este
sitio.

## Setup

1. **Generá una key nueva** en [Google AI Studio](https://aistudio.google.com/apikey).
   Nunca reutilices una key que ya haya aparecido en un chat, un commit, o
   cualquier lugar que no sea tu propia pantalla — tratala como comprometida
   y generá otra.
2. **Restringila** en [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   - Buscá la key → **Application restrictions** → **HTTP referrers (web sites)**.
   - Agregá `https://joacorea.github.io/*`.
   - (Opcional, para probar en local) agregá también `http://localhost:8000/*`
     y serví el sitio con `python3 -m http.server 8000` desde la raíz del repo
     — la restricción por referrer no funciona bien abriendo el archivo
     directo (`file://`).
3. **Pegala** en `generator/config.js`, reemplazando el placeholder:
   ```js
   const GEMINI_API_KEY = "tu-key-acá";
   ```
4. Listo — abrí `generator/index.html`, pegá un resumen de partidos, y probá.

## Límites a tener en cuenta

- La restricción por HTTP referrer frena el abuso casual (alguien copiando la
  key para usarla en otro sitio), pero **no es una garantía absoluta** — un
  llamado directo con headers falsificados podría sortearla. Al ser una key
  del nivel gratis de Gemini, el peor caso es que se agote tu cuota diaria.
- Nivel gratis de Gemini 2.5 Flash (verificar límites actuales en
  [ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing)):
  del orden de 250 pedidos por día, de sobra para este uso.
- Si ves "Se acabó la cuota gratis de Gemini por ahora", esperá a que se
  resetee (diario) o probá con otra key.
