# Directivas del proyecto: Análisis de Faltas y Reposición

Este archivo debe mantenerse **sincronizado** con `.cursor/rules/analisis-faltas-reposicion.mdc`.  
Al agregar o modificar una directiva, actualizar **ambos** archivos.

---

## Mantenimiento de directivas

- **Al agregar o cambiar una directiva**: actualizar siempre **los dos** sitios:
  - `.cursor/rules/analisis-faltas-reposicion.mdc`
  - `AI_GUIDELINES.md` (este archivo)

---

## Carpeta "old"

- **No tomar en cuenta la carpeta "old"**: Ignorar su contenido para análisis, consultas, scripts y referencias. No usar archivos ni rutas dentro de `old/`.

---

## Motor de base de datos

- **MySQL 5.7**: Todas las consultas, sintaxis y funciones deben ser compatibles con MySQL 5.7 (evitar características de 8.0+ si no están soportadas).

## Antes de implementar: preguntar

- **Campos desconocidos**: Si no está claro para qué sirve un campo de la base de datos, **preguntar al usuario antes de usarlo o implementar** lógica que lo dependa.
- **Campos para relacionar**: Si hace falta un campo para relacionar tablas y no se sabe cuál es el correcto, **preguntar al usuario antes de implementar** la relación o la consulta.

## Periodos de tiempo

- Trabajar siempre sobre **periodos cortos**: 1 o 2 días, bien identificados.
- Los filtros de fechas deben estar **claramente visibles y fáciles de cambiar a mano** (por ejemplo variables al inicio del script, comentarios con el rango, o constantes con nombres explícitos como `FECHA_INICIO` / `FECHA_FIN`).
- Evitar periodos largos o fechas hardcodeadas sin que el usuario pueda ajustarlas con poco esfuerzo.
