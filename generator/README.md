# Chattr Lab — generador experimental con Gemini

Página aislada donde pegás el resumen de los últimos partidos y **Gemini 2.5
Flash** (gratis) genera una tanda de posts al estilo Chattr, en el momento, en
tu navegador. No toca `chattr/`, `threadit/`, ni ningún `data/*.json` — es un
experimento aparte, nada se guarda (refrescar la página borra todo).

## ⚠️ Solo funciona corriendo el sitio en tu PC

Este sitio es **100% estático, sin servidor**, así que la llamada a Gemini se
hace directo desde el navegador con tu API key. Para que esa key **no quede
públicamente en el repo de GitHub**, `generator/config.js` (donde va tu key
real) está en `.gitignore` — nunca se commitea.

La consecuencia: esta función **no va a funcionar** abriendo la URL pública
(`joacorea.github.io/fake-web-fc/generator/`), porque ahí `config.js` no
existe. Para usarla, corré el sitio localmente:

```bash
python3 -m http.server 8000
# abrí http://localhost:8000/generator/
```

(Si en algún momento querés que funcione también desde la URL pública, hace
falta un mini-servidor/proxy que guarde la key del lado del servidor — eso
agrega infraestructura nueva al proyecto, y por ahora se decidió no sumarla.)

## Setup (una sola vez)

1. Copiá la plantilla:
   ```bash
   cp generator/config.example.js generator/config.js
   ```
2. Generá tu API key en [Google AI Studio](https://aistudio.google.com/apikey)
   y pegala en `generator/config.js`, reemplazando el placeholder.
   - Nunca reutilices una key que ya haya aparecido en un chat, un commit, o
     cualquier lugar que no sea tu propia pantalla — tratala como comprometida
     y generá otra.
3. (Opcional pero recomendado) Restringila en
   [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   Credentials → tu key → Application restrictions → HTTP referrers → agregá
   `http://localhost:8000/*`. Como esta función solo corre en local, alcanza
   con restringirla a eso.
4. Listo — abrí `generator/index.html` (servido por http, no como archivo
   directo), pegá un resumen de partidos, y probá.

## Límites a tener en cuenta

- Nivel gratis de Gemini 2.5 Flash (verificar límites actuales en
  [ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing)):
  del orden de 250 pedidos por día, de sobra para este uso.
- Si ves "Se acabó la cuota gratis de Gemini por ahora", esperá a que se
  resetee (diario) o probá con otra key.
