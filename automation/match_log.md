# Match log (buffer)

Registro temporal de partidos contados en el chat, todavía no volcados al sitio.
Cada vez que el usuario pasa un partido, se agrega una entrada acá y se commitea.
Cuando se llega a 5 entradas pendientes (o el usuario pide actualizar antes), se usa
este log para escribir contenido nuevo en `data/*.json`, y las entradas usadas se
mueven a la sección "Procesados" de abajo (no se borran, quedan como historial).

Ver `README.md` para el estado general del save y las personalidades recurrentes.

## Pendientes (sin volcar al sitio todavía)

_(vacío por ahora)_

## Procesados

_(vacío por ahora)_
