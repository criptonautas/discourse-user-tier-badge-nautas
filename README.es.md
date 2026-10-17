# User Tier Badge

[ENGLISH](README.md) | **ESPAÑOL**

Mantenido por Criptonautas. Sin afiliación ni respaldo de Discourse (Civilized Discourse Construction Kit, Inc.).

Componente de tema de Discourse que muestra el avance de un miembro por niveles de
insignias personalizados (no niveles de confianza). Cada nivel es un conjunto de insignias;
completar el conjunto desbloquea un grupo.

## Características

- **Progreso por nivel en el menú del avatar**: el nivel actual, cuántas de sus
  insignias se consiguieron, una barra de progreso y la lista de las que faltan.
  Los niveles largos muestran cinco filas (primero las que faltan) y un enlace
  «ver todos» a `/badges`. Seguir cualquier enlace del recuadro cierra el menú.
- **Niveles definidos por ids de insignias** en un ajuste `objects`, una fila por nivel con
  el grupo que desbloquea. Pertenecer al grupo también satisface el nivel, así que una
  suscripción o una concesión manual cuentan.
- **Insignias de nivel recientes**: quién obtuvo una más recientemente, de la más nueva a la más
  antigua, una fila por miembro. No se coloca en ningún sitio por defecto; ver
  [Insignias recientes en la barra lateral derecha](#insignias-recientes-en-la-barra-lateral-derecha).
- **Caché del navegador** con TTL configurable, para no repetir la consulta de insignias en
  cada vista de página.

## Requisitos

El recuadro se inserta en el outlet `custom-user-menu-after-user-info`, que solo existe con
[discourse-custom-user-menu-nautas](https://github.com/somos-criptonautas/discourse-custom-user-menu-nautas)
(fork del Custom User Menu de Manuel Kostka). Sin él el recuadro simplemente no aparece; nada
se rompe. El bloque `theme:user-tier-badge:badge` sigue registrado para los temas que quieran
colocarlo ellos mismos en un outlet de bloques.

## Insignias recientes en la barra lateral derecha

[Right Sidebar Blocks](https://github.com/discourse/discourse-right-sidebar-blocks)
muestra cualquier componente por su nombre, así que acá no hace falta nada más. Agregá
esta fila a su ajuste `blocks`:

```json
{ "name": "recent-tier-badges" }
```

Ese componente muestra la barra solo en las listas de historias en desktop (vive en el
outlet `before-list-area`), nunca en una historia ni en el celular. La cantidad de filas
es el ajuste `recent_badges_count` de este componente. Un tema también puede colocar la
misma lista en un outlet de bloques por su nombre de bloque,
`theme:user-tier-badge:recent-badges`.

## Instalación

Instala primero discourse-custom-user-menu-nautas (sustituye al Custom User Menu original).
Luego sube este componente en **Admin > Personalizar > Temas**, asocia los dos a tu tema
activo y completa el ajuste `tiers` con los ids de insignias y el grupo de cada nivel.

## Licencia

MIT. Consulta [LICENSE](LICENSE).

Texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
