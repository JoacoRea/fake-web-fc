# Exports del save (FC-26 Live Editor)

Scripts Lua que corren dentro de **[FC-26 Live Editor](https://github.com/xAranaktu/FC-26-Live-Editor)**
(la herramienta de la comunidad que inyecta un DLL en el proceso de FC 26 para leer
memoria en tiempo real). Escriben un archivo de texto local con la tabla de
posiciones, resultados recientes, próximos fixtures y estadísticas del plantel.
Vos abrís ese archivo, copiás el contenido, y lo pegás en un chat de Claude Code
sobre este repo — Claude actualiza el sitio con esa información.

**No hay tokens, credenciales, ni conexión a internet involucrados.** Los scripts
solo leen memoria del juego y escriben un archivo `.txt` local.

## Los dos scripts

- **`exportar_datos.lua` — manual, el recomendado.** Lo ejecutás cuando VOS
  decidís que hay material para una actualización del sitio (después de una
  semana importante, una final, lo que sea). Genera el reporte al instante:
  tabla completa, últimos 5 resultados con forma (W/D/L), próximos 5 fixtures,
  top 10 por goles+asistencias, top 5 por rating promedio, desglose por
  competición de los 6 máximos contribuyentes, y **cambios de OVR del plantel
  desde el export anterior** (guarda un snapshot en
  `fake_web_fc_ovr_state.txt`; la primera corrida solo saca la foto, a partir
  de la segunda reporta subas/bajas tipo "Nico Paz 80 -> 82 (+2)"). Sin hooks
  de eventos ni contadores — ejecutar el script ES el disparador.
- **`export_every_5_matches.lua` — automático, opcional.** Queda corriendo y
  genera el reporte solo, cada 5 partidos jugados. Usa el Career Mode Event 137
  (`JOB_OFFER_ACCEPTED`, nombre engañoso — dispara una vez al pitido final,
  descubierto con el `track_cm_events.lua` oficial) y un archivo de estado para
  el conteo. Útil si algún día querés el loop sin pensar; hoy el flujo real de
  actualización es irregular, por eso el manual es el principal.

## Setup (una sola vez)

1. **Instalar Live Editor**: seguí las instrucciones de instalación en
   [github.com/xAranaktu/FC-26-Live-Editor](https://github.com/xAranaktu/FC-26-Live-Editor).
2. **Copiar el script**: copiá `exportar_datos.lua` (y opcionalmente
   `export_every_5_matches.lua`) a la carpeta `lua/` de Live Editor en tu PC,
   junto a los scripts oficiales de ejemplo (`export_fixtures.lua`,
   `export_season_stats.lua`, `track_cm_events.lua`).
3. **(Opcional) Elegir carpeta de salida**: por defecto, el archivo se escribe al
   lado del script. Si preferís otra ubicación (por ejemplo el Escritorio), editá:
   ```lua
   local OUTPUT_DIR = "C:\\Users\\vos\\Desktop\\"
   ```

## Cómo usarlo (flujo manual)

1. Iniciá FC 26, cargá tu save de Chelsea, y conectá Live Editor como siempre.
2. Cuando quieras actualizar el sitio: **Lua Engine → Execute** sobre
   `exportar_datos.lua`.
3. Aparece un `fake_web_fc_export_<fecha>.txt` al lado del script. Contiene algo así:

```
=== FAKE-WEB-FC SAVE EXPORT (manual) ===
Generated: 2026-04-12 22:14

-- LEAGUE TABLE --
 1. Arsenal              P31 W20 D7  L4  GD+34 Pts 67
 ...
 5. Chelsea              P32 W15 D8  L9  GD+23 Pts 53  <-- US

-- LAST 5 RESULTS (all competitions) --
2026-04-04 [FA Cup] Chelsea 3-0 Leeds  (W)
...
Form: W W D L W

-- NEXT 5 FIXTURES --
2026-04-14 [Champions League] @ Atlético Madrid
...

-- TOP 10 BY GOALS+ASSISTS (season) --
Enzo Fernández       Apps:38  Goals:16  Assists:9   Avg:7.8  MOTM:6
...

-- TOP 5 BY AVG RATING (min 8 apps) --
Moisés Caicedo       Avg:7.9  Apps:40  MOTM:8
...
```

4. Copiá todo y pegalo en un chat de Claude Code sobre este repo
   (`joacorea/fake-web-fc`). Contale también cualquier cosa que la memoria del
   juego no capture — fichajes, dramas, lesiones, despidos de DTs rivales, lo
   que quieras — y Claude actualiza `data/season.json` y escribe hilos nuevos
   en los tres subthreadits con esa info.

## Flujo automático (opcional)

Si preferís el export automático cada 5 partidos: una vez por sesión de juego,
**Lua Engine → Execute** sobre `export_every_5_matches.lua` y jugá normalmente.
El contador de partidos persiste entre sesiones en un archivo de estado al lado
del script. La calibración del evento de fin de partido ya está hecha (ver
arriba); si en tu instalación no disparara, corré el `track_cm_events.lua`
oficial durante un partido y ajustá `TARGET_EVENT_NAME`.

## Si algo no funciona

El plumbing de lectura de memoria (`GetFCEDataManager`, `GetValidStandings`,
`GetValidFixtures`, offsets como `+ 0x88`) está copiado **literalmente** del
`export_fixtures.lua` oficial del repo de Live Editor, y la lectura de
estadísticas sigue al `export_season_stats.lua` oficial. Dos cosas pueden
romperse igual:

- **Una actualización de Live Editor cambia los offsets de memoria**: síntoma
  típico, valores absurdos o crash al leer standings. Solución: comparar contra
  las copias de esos dos scripts oficiales que vinieron con tu versión de la
  herramienta (carpeta `lua/`) y ajustar los offsets que difieran.
- **El formato de fecha de los fixtures** (`mDate`, un entero sin documentar):
  el script intenta interpretarlo como `yyyymmdd` o como días desde 1582
  (formato clásico de FC), y si no matchea ninguno imprime el número crudo. Si
  ves fechas crudas o incoherentes en el `.txt`, pasale a Claude un par de
  valores crudos junto con la fecha in-game real y se calibra el conversor.

Cualquiera de los dos casos se resuelve pegando el contenido de los scripts
oficiales (o el `.txt` roto) en el chat para que Claude devuelva la versión
corregida.
