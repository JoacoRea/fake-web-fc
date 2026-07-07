# Export cada 5 partidos (FC-26 Live Editor)

Un script Lua que corre dentro de **[FC-26 Live Editor](https://github.com/xAranaktu/FC-26-Live-Editor)**
(la herramienta de la comunidad que inyecta un DLL en el proceso de FC 26 para leer
memoria en tiempo real). Cada 5 partidos jugados en tu save, escribe un archivo de
texto local con la tabla de posiciones, resultados recientes, próximos fixtures y
goleadores/asistencias. Vos abrís ese archivo, copiás el contenido, y lo pegás en un
chat de Claude Code sobre este repo — Claude actualiza el sitio con esa información,
igual que viene haciendo hasta ahora.

**No hay tokens, credenciales, ni conexión a internet involucrados.** El script solo
lee memoria del juego y escribe un archivo `.txt` local.

## Setup (una sola vez)

1. **Instalar Live Editor**: seguí las instrucciones de instalación en
   [github.com/xAranaktu/FC-26-Live-Editor](https://github.com/xAranaktu/FC-26-Live-Editor).
2. **Copiar el script**: copiá `export_every_5_matches.lua` (este archivo) a la
   carpeta `lua/` de Live Editor en tu PC, junto a los scripts oficiales de ejemplo
   (`export_fixtures.lua`, `export_season_stats.lua`, `track_cm_events.lua`).
3. **Calibración del evento: ya hecha.** El evento de "partido recién terminado"
   es el **Career Mode Event 137, `JOB_OFFER_ACCEPTED`** (sí, el nombre es
   engañoso — se descubrió corriendo el `track_cm_events.lua` oficial: dispara
   exactamente una vez al pitido final, seguido ~20s después por la ráfaga
   post-partido de `CPU_TRANSFER_INFO` / `BOARD_EMAIL_EVENT` /
   `ABOUT_TO_INIT_MODE`). El script ya lo trae configurado. Si en tu instalación
   viera otro comportamiento, repetí la observación con `track_cm_events.lua` y
   ajustá `TARGET_EVENT_NAME`.
4. **(Opcional) Elegir carpeta de salida**: por defecto, el archivo se escribe al
   lado del script. Si preferís otra ubicación (por ejemplo el Escritorio), editá:
   ```lua
   local OUTPUT_DIR = "C:\\Users\\vos\\Desktop\\"
   ```

## Cada sesión de juego

No hay autoload confirmado en Live Editor, así que hay que repetir esto una vez por
sesión:

1. Iniciá FC 26 y conectá Live Editor como siempre.
2. **Lua Engine → Execute** sobre `export_every_5_matches.lua`.
3. Jugá normalmente. El contador de partidos jugados persiste entre sesiones (se
   guarda en un archivo de estado al lado del script), así que no importa si cerrás
   y volvés a abrir el juego — el conteo hacia el próximo export sigue donde quedó.

## Cómo usarlo

Cada 5 partidos jugados, aparece un archivo nuevo `fake_web_fc_export_<fecha>.txt`.
Contiene algo así:

```
=== FAKE-WEB-FC SAVE EXPORT ===
Generated: 2026-03-01 22:14
Chelsea - matches played: 30

-- LEAGUE TABLE --
 1. Arsenal              P30 W20 D8  L2  GD+31 Pts 68
 ...
 4. Chelsea               P30 W16 D7  L7  GD+30 Pts 55  <-- US
 ...

-- RECENT RESULTS (since last export) --
2026-02-22 [Premier League] Chelsea 2-1 Arsenal
...

-- UPCOMING FIXTURES --
2026-03-08 [FA Cup] vs Birmingham
...

-- TOP SCORERS / ASSISTS (season so far) --
Enzo Fernández       Apps:28  Goals:15  Assists:9   Avg:7.8  MOTM:6
...

=== END OF EXPORT -- copy everything above into your Claude Code chat ===
```

Abrí el archivo, copiá todo, y pegalo en un chat de Claude Code sobre este repo
(`joacorea/fake-web-fc`). Contale también cualquier cosa que la memoria del juego no
capture — fichajes, dramas, lesiones, lo que quieras — y Claude actualiza
`data/season.json` y escribe posts/hilos nuevos con esa info.

## Si algo no funciona

Los nombres de campo usados en el script (`row.WinsHome`, `mgr:GetSquadPlayers`,
etc.) son una reconstrucción de buena fe basada en el comportamiento documentado de
los scripts oficiales `export_fixtures.lua` / `export_season_stats.lua` — no su
código fuente literal. Si al ejecutar ves errores en la consola de Live Editor
(`GetValidStandings failed`, `GetSquadPlayers failed`, etc.), compará esos nombres
contra tu copia local de esos dos scripts oficiales y ajustá los que no coincidan.
Esto se puede resolver fácilmente pidiéndole ayuda a Claude en una sesión local en
tu PC, donde se puede iterar directo sobre el archivo.
