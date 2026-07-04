# The Alonso Rebuild — sitios ficticios para el modo carrera de FC 26 (Chelsea)

Redes sociales falsas que reaccionan a lo que pasa en tu save. 100% estático, sin dependencias.

- **`index.html`** — hub de entrada.
- **`chattr/`** — red social tipo X/Twitter: primicias de periodistas, meltdowns de hinchas, encuestas, trending topics, tabla y fixture.
- **`threadit/`** — foro tipo Reddit (`t/chelseafc`): post-match threads, análisis tácticos, vent threads.
- **`data/*.json`** — TODO el contenido vive acá. Los sitios solo renderizan estos archivos.

## Cómo publicarlo (una sola vez)

1. Mergeá el branch a `main` (o usá el branch directamente).
2. En GitHub: **Settings → Pages → Source: Deploy from a branch → `main` → `/ (root)` → Save**.
3. En unos minutos queda en `https://joacorea.github.io/fake-web-fc/`.

## Cómo verlo local

```bash
python3 -m http.server 8000
# abrir http://localhost:8000
```

(Hace falta servirlo por HTTP porque los sitios cargan los JSON con `fetch`.)

## Cómo actualizarlo después de jugar

Volvé a una sesión de Claude Code en este repo y contale qué pasó en tu save:
resultados, goles, fichajes, lesiones, posición en la tabla, cualquier drama.
Claude escribe los posts, hilos y reacciones nuevas en `data/*.json` y pushea.

**Atajo si jugás en PC con FC-26 Live Editor**: cada 5 partidos podés generar un
resumen de texto automático (tabla, resultados, fixtures, goleadores) para pegar acá
en vez de escribirlo todo a mano — ver `automation/live-editor/README.md`.

Los personajes recurrentes (mantener su personalidad al generar contenido nuevo):

| Cuenta | Personalidad |
|---|---|
| `@CFCDanny` / `u/CFCDanny` | Eufórico, todo en mayúsculas, "WE ARE SO BACK" |
| `@BluesTilIDie_Sue` / `u/BluesTilIDie_Sue` | Pesimista crónica con humor negro |
| `@ShedEndTerry` / `u/ShedEndTerry` | Boomer, "in my day...", quejoso hasta en las goleadas |
| `@xG_Marcus` / `u/xG_Marcus` | El estadístico, defiende al equipo con xG |
| `@CarefreeChloe` / `u/CarefreeChloe` | Optimista con banter filoso |
| `@GoonerGaz` / `u/GoonerGaz_` | Hincha del Arsenal que viene a gastar |
| `u/ZolaWasMyDad` | Nostálgico y meme lord del foro |
| `u/KTBFFH_1905` | La memoria histórica, comentarios sensatos |
| `u/KepaApologist` | Sigue defendiendo a Kepa, siempre downvoteado |

> Estado actual del save (15 Mar 2026, DT **Xabi Alonso**): 5º con 50 pts tras un tramo irregular
> en liga (derrotas vs Arsenal 0-3 y Aston Villa 1-2, empate 1-1 con Newcastle con gol de Kubo en
> el 96'), pero brillante en las copas: semifinales de FA Cup (3-0 a Birmingham, doblete de Kubo,
> gran debut de Perrone) y ventaja 3-1 de visitante en la ida de octavos de Champions vs Galatasaray
> (partidazo de Neves). Semana decisiva por delante: vuelta vs Galatasaray, Everton, y la final de
> la Carabao vs Man City en Wembley, todo en 5 días. Drama central: la venta de Cole Palmer y la
> salida de Reece James en plena reconstrucción de 12 fichajes.

---
*Proyecto personal de diversión para un save de FC 26. Sin afiliación con nadie. KTBFFH 💙*
