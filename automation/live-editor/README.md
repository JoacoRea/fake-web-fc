# Export cada 5 partidos (FC-26 Live Editor)

Un script Lua que corre dentro de **[FC-26 Live Editor](https://github.com/xAranaktu/FC-26-Live-Editor)**
(la herramienta de la comunidad que inyecta un DLL en el proceso de FC 26 para leer
memoria en tiempo real). Cada 5 partidos completados en tu save (jugados o simulados),
escribe un archivo de texto local con la tabla de posiciones, resultados recientes,
próximos fixtures y goleadores/asistencias. Vos abrís ese archivo, copiás el contenido,
y lo pegás en un chat de Claude Code sobre este repo — Claude actualiza el sitio con esa
información, igual que viene haciendo hasta ahora.

**No hay tokens, credenciales, ni conexión a internet involucrados.** El script solo
lee memoria del juego y escribe un archivo `.txt` local.

> El script está construido sobre la API real de Live Editor, verificada contra el
> código fuente de los scripts oficiales `export_fixtures.lua`, `export_season_stats.lua`
> y `track_cm_events.lua` (y la wiki [LUA API v2](https://github.com/xAranaktu/FC-26-Live-Editor/wiki/LUA-API-v2-Events)).
> Ya **no hace falta calibrar ningún nombre de evento a mano**: usa los enums
> documentados `ENUM_CM_EVENT_MSG_USER_MATCH_COMPLETED` / `..._IN_TOURNAMENT` /
> `..._DAY_PASSED` (con fallback automático por nombre si tu versión no los trae).

## Setup (una sola vez)

1. **Instalar Live Editor**: seguí las instrucciones de instalación en
   [github.com/xAranaktu/FC-26-Live-Editor](https://github.com/xAranaktu/FC-26-Live-Editor).
2. **Copiar el script**: copiá `export_every_5_matches.lua` (este archivo) a la
   carpeta `lua/` de Live Editor en tu PC, junto a los scripts oficiales de ejemplo
   (`export_fixtures.lua`, `export_season_stats.lua`, `track_cm_events.lua`).
3. **(Opcional) Ajustar la config** al principio del script:
   ```lua
   local CLUB_NAME          = "Chelsea"          -- tu club
   local LEAGUE_NAME        = "Premier League"   -- qué tabla imprimir
   local MATCHES_PER_EXPORT = 5                  -- cada cuántos partidos exportar
   local OUTPUT_DIR         = ...                -- por defecto: el Escritorio
   ```
   Por defecto los exports (y el archivito de estado que lleva la cuenta de partidos)
   se escriben en el **Escritorio** (`%USERPROFILE%\Desktop\`).

## Cada sesión de juego

Live Editor no autocarga scripts propios, así que hay que repetir esto una vez por
sesión:

1. Iniciá FC 26, cargá tu save de Chelsea, y conectá Live Editor.
2. **Features → Lua Engine → Execute** sobre `export_every_5_matches.lua`.
3. Jugá normalmente. El contador de partidos persiste entre sesiones (se guarda en
   `fake_web_fc_last_export.txt` junto a los exports), así que no importa si cerrás
   y volvés a abrir el juego — el conteo hacia el próximo export sigue donde quedó.
   Además, al ejecutar el script se hace un chequeo inmediato: si quedó un export
   pendiente de la sesión anterior, sale al toque.

## Cómo usarlo

Cada 5 partidos completados, aparece un archivo nuevo `fake_web_fc_export_<fecha>.txt`
en el Escritorio. Contiene algo así:

```
=== FAKE-WEB-FC SAVE EXPORT ===
Generated: 2026-03-01 22:14 (in-save date: 2026-03-01)
Chelsea - matches completed this season (all comps): 38

-- PREMIER LEAGUE TABLE --
 1. Arsenal                P30 W20 D8  L2  GD +31 Pts 68
 ...
 4. Chelsea                P30 W16 D7  L7  GD +30 Pts 55  <-- US
 ...

-- RECENT RESULTS (last 5) --
2026-02-22 [Premier League] Chelsea 2-1 Arsenal
...

-- UPCOMING FIXTURES --
2026-03-08 [FA Cup] vs Birmingham
...

-- TOP SCORERS / ASSISTS (season so far, all comps) --
Enzo Fernández         Apps:28  Goals:15  Assists:9   Avg:7.80 MOTM:6
...

=== END OF EXPORT -- copy everything above into your Claude Code chat ===
```

Abrí el archivo, copiá todo, y pegalo en un chat de Claude Code sobre este repo
(`joacorea/fake-web-fc`). Contale también cualquier cosa que la memoria del juego no
capture — fichajes, dramas, lesiones, lo que quieras — y Claude actualiza
`data/season.json` y escribe posts/hilos nuevos con esa info.

## Si algo no funciona

- **Lectores de memoria**: las funciones `GetValidStandings` / `GetValidFixtures` /
  `GetStandingsByIndex` están copiadas literalmente del `export_fixtures.lua` oficial
  (offsets de memoria incluidos). Si una actualización del juego o de Live Editor los
  rompe, van a fallar igual en el script oficial — compará con tu copia local y copiá
  los offsets nuevos.
- **Eventos**: si en la consola aparece
  `NOTE: career_mode/enums not found -- matching events by name instead`, el script
  sigue funcionando matcheando nombres de evento (`MATCH_COMPLETED`, `DAY_PASSED`).
  Podés verificar los nombres reales ejecutando el `track_cm_events.lua` oficial.
- **Fechas raras en los fixtures**: el campo de fecha en memoria no está documentado;
  el script prueba varios formatos conocidos y si no reconoce ninguno imprime el
  número crudo (que igual ordena cronológicamente). Los resultados siguen siendo
  usables — Claude puede deducir las fechas por contexto.
- Cualquier otro error se puede resolver pidiéndole ayuda a Claude en una sesión
  local en tu PC, donde se puede iterar directo sobre el archivo.
