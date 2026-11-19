# Flujo completo del panel: Landing → Cita → Propuesta (W07) → Contrato (W08)

| Paso | Pantalla (menú cliente / técnico) | Qué pasa en la BD | Estado de la consulta |
|---|---|---|---|
| 1 | Página web · formulario (W01) | INSERT PERSONA, CONSULTA, CONSULTA_CONTRAPARTE, NOTIFICACION | RECIBIDA |
| 2 | Consultas y citas (W04 · W06) | INSERT CITA + UPDATE CONSULTA + INSERT NOTIFICACION ×2 | AGENDADA |
| 3 | Propuestas (W07) | UPDATE PROPUESTA anterior → EN_NEGOCIACION · INSERT PROPUESTA (ENVIADA) · UPDATE CONSULTA | PROPUESTA |
| 4 | Contratos y cuotas (W08) · paso 1 | UPDATE PROPUESTA → ACEPTADA | PROPUESTA |
| 5 | Contratos y cuotas (W08) · paso 2 | INSERT CONTRATO + INSERT CUOTA ×n + UPDATE CONSULTA | CONTRATADA |
| 6 | Dashboard (W03) | solo lectura (vistas vw_dash_*) | — |

Los códigos P1/P2/P3 son los procesos del BPMN TO-BE; T1–T4 son las transacciones del informe (4.5); W01–W30 son las pantallas del Figma.
Con el botón «Mostrar campos BD» se ven estos códigos y las tablas; con «Ocultar» el menú y los títulos usan nombres simples (clases `solo-tec` / `solo-cli`).

## W07 · Propuesta de honorarios (ya funciona)

Pantalla `panel/propuesta.html` + `js/propuesta.js`. Reglas: la consulta debe estar AGENDADA, ATENDIDA o PROPUESTA; el abogado debe atender la materia (ABOGADO_MATERIA); versión = MAX + 1 (UNIQUE id_consulta + version); honorarios ≥ 0; cuota litis 0–100; pro bono = 1 cuota.

| Pantalla | Tablas que utiliza |
|---|---|
| W07 · Propuesta de honorarios | **PROPUESTA** (UPDATE versión anterior + INSERT) · **CONSULTA** (UPDATE estado = PROPUESTA) · lee PERSONA, MATERIA, CITA, ABOGADO_MATERIA, EMPLEADO |

# W08 · Contrato y cronograma de cuotas (ya funciona)

Pantalla: `panel/contrato.html` (menú «W08 · Contrato y cuotas»). Código: `t2/T2Repositorio.java` y `js/contrato.js`.

## Cuadro Pantalla | Tablas que utiliza

| Pantalla | Tablas que utiliza |
|---|---|
| W08 · Paso 1: el cliente acepta la propuesta | **PROPUESTA** (UPDATE estado = ACEPTADA, fecha_respuesta) · lee CONSULTA, PERSONA, MATERIA, EMPLEADO |
| W08 · Paso 2: registrar contrato y cronograma | **CONTRATO** (INSERT, 1 fila) · **CUOTA** (INSERT, n filas) · **CONSULTA** (UPDATE estado = CONTRATADA) · lee PROPUESTA, PERSONA |
| W08 · Paso 3: últimos contratos | CONTRATO, CUOTA, PERSONA, PROPUESTA, CONSULTA · vista **vw_cuota_estado** |

## La transacción (maestro-detalle)

1. `SELECT … FROM propuesta WITH (UPDLOCK)`: la propuesta debe estar ACEPTADA y sin contrato (1:1).
2. Validaciones de la app: la suma de las cuotas debe ser igual a `propuesta.monto_honorarios`; las cuotas van numeradas 1, 2, 3…; ninguna vence antes de la firma; si es pro bono no lleva cuotas.
3. `INSERT contrato` → el trigger `trg_contrato_cliente_documento` exige que el cliente tenga DNI o RUC.
4. `INSERT cuota` × n (FK `id_contrato`, estado PENDIENTE por DEFAULT).
5. `UPDATE consulta SET estado = 'CONTRATADA'`.
6. `COMMIT`. Si algo falla en cualquier paso → `ROLLBACK`: no queda ni el contrato, ni las cuotas, ni el cambio de estado.

## Demostración para el profesor (3 minutos)

1. Pulse **Mostrar campos BD** (abajo a la derecha): aparecen las etiquetas tabla.columna.
2. Paso 1: en la propuesta de Sofía Cárdenas (N.° 10) pulse **Aceptó ✓**.
3. Paso 2: ya está elegida. Pulse **Generar**: 2 cuotas de S/ 1,300 que suman S/ 2,600.
4. **Prueba de ROLLBACK**: en «Cliente que firma» elija *Textiles Huallaga (SIN DOCUMENTO ⚠)* y pulse Registrar. SQL Server responde con el error del trigger y no se graba nada.
5. Vuelva a elegir a Sofía y pulse **Registrar** → COMMIT con los id generados.
6. En SSMS ejecute `sql/04_ver_lo_que_grabo_w08.sql` y abra el diagrama **Flujo_Contrato_Cuotas_Transaccional**.
7. Abra el Dashboard: «Honorarios contratados» subió S/ 2,600 y aparecen las nuevas cuotas por cobrar.

## Botón «Mostrar / Ocultar campos BD»

Está en todas las pantallas (`js/bd.js`). Arranca oculto, que es la vista del cliente, y recuerda la elección al pasar de una pantalla a otra.
Oculta las etiquetas `.bd`, los bloques técnicos `.bd-bloque` (chips GRABA/CONSULTA, SQL para SSMS) y las trazas de COMMIT `.bd-traza`.
Para que algo nuevo se oculte con el botón, ponga `class="bd"` (etiqueta) o `class="bd-bloque"` (bloque entero).
