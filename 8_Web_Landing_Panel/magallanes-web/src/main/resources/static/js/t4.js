// =====================================================================
// T4 · Cobranza y cierre: W18 comprobante · W19 pago · W21 cierre · W22 encuesta
// =====================================================================
let series = [], respuestas = {};

document.querySelectorAll(".pestanas button").forEach((b) => b.addEventListener("click", () => {
  document.querySelectorAll(".pestanas button").forEach((x) => x.classList.toggle("activo", x === b));
  ["w18", "w19", "w21", "w22", "w22r"].forEach((id) => $(id).hidden = id !== b.dataset.p);
  if (b.dataset.p === "w22r") cargarResultados();
}));

function traza(div, titulo, lineas, aviso, mensaje, extra) {
  div.innerHTML = `<div class="aviso verde">✔ ${esc(mensaje)}</div>${aviso ? `<div class="aviso amarillo">${esc(aviso)}</div>` : ""}
    <div class="traza bd-traza"><div>COMMIT ✔ ${esc(titulo)}</div>${lineas.map((l) => `<div>${l}</div>`).join("")}</div>${extra || ""}`;
}

// ---------------- W18
async function cargarClientes() {
  const cl = await api("../api/panel/t4/clientes-con-cuotas");
  opciones($("c-cliente"), cl, "id_cliente", (c) => `${c.cliente} · ${c.documento} · ${c.cuotas} cuota(s)${c.documento === "SIN DOCUMENTO" ? " ⚠" : ""}`, cl.length ? null : "No hay cuotas por facturar");
  if (cl.length) await cargarCuotas();
}
async function cargarCuotas() {
  if (!$("c-cliente").value) { $("c-cuotas").innerHTML = ""; return; }
  const cu = await api(`../api/panel/t4/clientes/${$("c-cliente").value}/cuotas`);
  $("c-cuotas").innerHTML = cu.map((q) => `<label><input type="checkbox" class="cu" value="${q.id_cuota}" data-monto="${q.monto}">
      <span>${esc(q.nro_contrato)} · ${esc(q.concepto)} ${q.nro_cuota} · <b>${soles(q.monto)}</b> · vence ${esc(q.vence)} ${estado(q.estado)}</span></label>`).join("");
  document.querySelectorAll(".cu").forEach((c) => c.addEventListener("change", totalComprobante));
  const p = document.querySelector(".cu"); if (p) p.checked = true;
  totalComprobante();
}
function totalComprobante() {
  const s = series.find((x) => x.serie === $("c-serie").value) || {};
  const igv = s.tipo_comprobante === "RECIBO_HONORARIOS" ? 0 : 0.18;
  $("c-numero").textContent = s.serie ? `${s.serie}-${String(s.siguiente).padStart(6, "0")} (${s.tipo_comprobante})` : "—";
  $("c-igv").textContent = (igv * 100) + " %";
  const sub = [...document.querySelectorAll(".cu:checked")].reduce((a, c) => a + Number(c.dataset.monto), 0);
  $("c-total").textContent = `Subtotal ${soles(sub)} · IGV ${soles(sub * igv)} · Total ${soles(sub * (1 + igv))}`;
}
$("c-cliente").addEventListener("change", cargarCuotas);
$("c-serie").addEventListener("change", totalComprobante);
$("w18").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("a18"); a.className = "alerta";
  const cuotas = [...document.querySelectorAll(".cu:checked")].map((c) => Number(c.value));
  if (!cuotas.length) { a.className = "alerta mal"; a.textContent = "Marque al menos una cuota."; return; }
  const b = $("b18"); b.disabled = true;
  try {
    const r = await postJSON("../api/panel/t4/comprobantes", { idPersona: Number($("c-cliente").value), serie: $("c-serie").value, fechaVencimiento: $("c-vence").value, cuotas });
    const t = r.totales[0] || {};
    traza($("r18"), "Transacción W18", [`<b>COMPROBANTE</b> id_comprobante = ${r.idComprobante} · ${esc(r.comprobante)} · EMITIDO`,
      `<b>DETALLE_COMPROBANTE</b> ${r.lineas} línea(s)`, `<b>SERIE_COMPROBANTE</b> ultimo_numero avanzado por el trigger`,
      `vw_comprobante_total → subtotal ${soles(t.subtotal)} · IGV ${soles(t.igv)} · total ${soles(t.total)}${Number(t.detraccion) ? " · detracción " + soles(t.detraccion) : ""}`], null, r.mensaje);
    await Promise.all([cargarSeries(), cargarClientes(), cargarComprobantes(), cargarConSaldo()]);
  } catch (err) { mostrarError(a, err); } finally { b.disabled = false; }
});
async function cargarSeries() {
  series = await api("../api/panel/t4/series");
  const v = $("c-serie").value;
  opciones($("c-serie"), series, "serie", (s) => `${s.serie} · ${s.tipo_comprobante}`);
  if (v) $("c-serie").value = v;
  totalComprobante();
}

// ---------------- W19
async function cargarConSaldo() {
  const c = await api("../api/panel/t4/comprobantes-con-saldo");
  opciones($("g-comp"), c, "id_comprobante", (x) => `${x.serie}-${String(x.numero).padStart(6, "0")} · ${x.cliente} · saldo ${soles(x.saldo)}`, c.length ? null : "No hay comprobantes con saldo");
  const sel = c.find((x) => String(x.id_comprobante) === $("g-comp").value); if (sel) $("g-monto").value = sel.saldo;
  $("g-comp").onchange = () => { const s = c.find((x) => String(x.id_comprobante) === $("g-comp").value); if (s) $("g-monto").value = s.saldo; };
}
$("w19").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("a19"); a.className = "alerta";
  if (!$("g-comp").value) { a.className = "alerta mal"; a.textContent = "No hay comprobante con saldo."; return; }
  const b = $("b19"); b.disabled = true;
  try {
    const r = await postJSON("../api/panel/t4/pagos", { idComprobante: Number($("g-comp").value), monto: $("g-monto").value, medioPago: $("g-medio").value, nroOperacion: $("g-op").value.trim() });
    traza($("r19"), "Transacción W19", [`<b>PAGO</b> id_pago = ${r.idPago} · saldo ${soles(r.saldoAnterior)} → ${soles(r.saldo)}`,
      `<b>CUOTA</b> ${r.cuotasActualizadas} cuota(s) → ${esc(r.estadoCuotas)}`, `<b>NOTIFICACION</b> ${r.idNotificacion ? "id " + r.idNotificacion + " · CONSTANCIA_PAGO por WhatsApp" : "—"}`], null, r.mensaje);
    $("g-op").value = "";
    await Promise.all([cargarConSaldo(), cargarComprobantes()]);
  } catch (err) { mostrarError(a, err); } finally { b.disabled = false; }
});

// ---------------- W21
async function cargarCerrar() {
  const c = await api("../api/panel/t4/casos-para-cerrar");
  tabla($("t-cerrar"), c, [{ f: (x) => `<b>${esc(x.codigo_interno)}</b>` }, { f: (x) => esc(x.cliente) }, { f: (x) => esc(x.materia) },
    { f: (x) => x.plazos_pendientes > 0 ? `<span class="urg">${x.plazos_pendientes}</span>` : "0" }, { f: (x) => soles(x.saldo_cliente) },
    { f: (x) => x.plazos_pendientes > 0
        ? `<button class="btn btn-sec btn-mini" type="button" data-plazos="${x.id_caso}" data-cod="${esc(x.codigo_interno)}">Ver plazos pendientes</button>`
        : `<button class="btn btn-oro btn-mini" type="button" data-cerrar="${x.id_caso}">Cerrar y enviar encuesta</button>` }], "No hay casos activos.");
  document.querySelectorAll("[data-cerrar]").forEach((b) => b.addEventListener("click", () => cerrar(Number(b.dataset.cerrar), b)));
  document.querySelectorAll("[data-plazos]").forEach((b) => b.addEventListener("click", () => verPlazos(Number(b.dataset.plazos), b.dataset.cod)));
}
// Un caso con plazos sin cumplir no se puede cerrar: aquí se ven y se marcan como cumplidos (UPDATE plazo).
async function verPlazos(idCaso, codigo) {
  const a = $("a21"); a.className = "alerta";
  try {
    const p = await api(`../api/panel/t3/casos/${idCaso}/plazos-pendientes`);
    $("r21").innerHTML = `<div class="aviso amarillo">El caso <b>${esc(codigo)}</b> no se puede cerrar mientras tenga plazos sin cumplir.
      Normalmente el plazo se cumple al presentar el escrito (W12); aquí también puede marcarlo como cumplido.</div>
      <div style="overflow-x:auto;margin-top:10px"><table class="tabla mini"><thead><tr><th>Plazo</th><th>Vence</th><th>Estado</th><th></th></tr></thead><tbody>
      ${p.map((x) => `<tr><td>${esc(x.descripcion)}</td><td>${esc(x.vence)}</td><td>${estado(x.estado)}</td>
        <td><button class="btn btn-oro btn-mini" type="button" data-cumplir="${x.id_plazo}">Marcar cumplido</button></td></tr>`).join("")}
      </tbody></table></div><span class="bd">UPDATE plazo SET fecha_cumplimiento = hoy · vw_plazo_estado → CUMPLIDO · MongoDB: bitácora del expediente</span>`;
    document.querySelectorAll("[data-cumplir]").forEach((b) => b.addEventListener("click", async () => {
      b.disabled = true;
      try {
        const r = await postJSON(`../api/panel/t3/plazos/${b.dataset.cumplir}/cumplir`, {});
        a.className = "alerta ok"; a.textContent = r.mensaje;
        await cargarCerrar(); await verPlazos(idCaso, codigo);
        if (!document.querySelector("[data-cumplir]")) $("r21").innerHTML = `<div class="aviso verde">✔ ${esc(codigo)} ya no tiene plazos pendientes: ya puede cerrarlo.</div>`;
      } catch (err) { mostrarError(a, err); b.disabled = false; }
    }));
  } catch (err) { mostrarError(a, err); }
}
async function cerrar(id, b) {
  const a = $("a21"); a.className = "alerta"; b.disabled = true;
  try {
    const r = await postJSON(`../api/panel/t4/casos/${id}/cerrar`);
    traza($("r21"), "Transacción W21", [`<b>CASO_ETAPA</b> etapa actual cerrada + etapa «Cerrado»`, `<b>CASO</b> id_caso = ${r.idCaso} → CERRADO`,
      `<b>ENCUESTA</b> id_encuesta = ${r.idEncuesta} · enviada`, `<b>NOTIFICACION</b> ENVIO_ENCUESTA por WhatsApp · el cliente la responde en su portal`, `<b>MongoDB · encuestas</b> _id = ${esc(r.encuestaMongoId || "—")} · ENVIADA`],
      r.aviso, r.mensaje, r.encuestaMongoId ? `<button class="btn btn-sec btn-mini" type="button" onclick="verMongo('../api/panel/t4/encuestas/${r.idEncuesta}/mongo')">Ver el documento en MongoDB</button>` : "");
    await Promise.all([cargarCerrar(), cargarEncuestas()]);
  } catch (err) { mostrarError(a, err); b.disabled = false; }
}

// ---------------- W22 · seguimiento (el cliente responde en su portal)
async function cargarFormulario() {
  const f = await api("../api/panel/t4/formulario-encuesta");
  $("s-origen").innerHTML = `El portal muestra al cliente ${f.preguntas.length} preguntas leídas de <b>${esc(f.origen)}</b> (versión ${esc(f.version)}). <span class="bd">formularios_encuesta: las preguntas cambian sin modificar tablas</span>`;
}
async function cargarEncuestas() {
  const [pend, resp] = await Promise.all([api("../api/panel/t4/encuestas-pendientes"), api("../api/panel/t4/encuestas-respondidas")]);
  tabla($("t-enc-pend"), pend, [{ f: (e) => e.id_encuesta }, { f: (e) => esc(e.codigo_interno) }, { f: (e) => esc(e.cliente) }, { f: (e) => esc(e.enviada) }],
    "No hay encuestas esperando respuesta.");
  tabla($("t-enc"), resp, [{ f: (e) => e.id_encuesta }, { f: (e) => esc(e.codigo_interno) }, { f: (e) => "★".repeat(e.calificacion || 0) }, { f: (e) => e.nps },
    { f: (e) => `<button class="btn btn-sec btn-mini" type="button" onclick="verMongo('../api/panel/t4/encuestas/${e.id_encuesta}/mongo')">JSON</button>` }], "Sin respuestas.");
}

// ---------------- Resultados de las encuestas (promedio, NPS y comentarios con el nombre del cliente)
async function cargarResultados() {
  try {
    const d = await api("../api/panel/t4/encuestas-resumen");
    const t = d.totales || {}, n = Number(t.respondidas || 0);
    $("r-prom").textContent = t.promedio != null ? Number(t.promedio).toFixed(1) : "–";
    const ll = Math.round(Number(t.promedio || 0));
    $("r-est").textContent = "★".repeat(ll) + "☆".repeat(5 - ll);
    $("r-n").textContent = `${n} respuesta(s) · ${t.pendientes || 0} pendiente(s)`;
    const dist = Object.fromEntries((d.estrellas || []).map((x) => [x.estrellas, x.cantidad]));
    $("r-dist").innerHTML = [5, 4, 3, 2, 1].map((k) => `<div class="barra-est"><span>${k} ★</span><i><span style="width:${n ? (100 * (dist[k] || 0)) / n : 0}%"></span></i><span>${dist[k] || 0}</span></div>`).join("");
    const p = Number(t.promotores || 0), pa = Number(t.pasivos || 0), de = Number(t.detractores || 0);
    $("r-nps").textContent = n ? Math.round(((p - de) / n) * 100) : "–";
    [["r-bp", p], ["r-bn", pa], ["r-bd", de]].forEach(([id, v]) => $(id).style.width = (n ? (100 * v) / n : 0) + "%");
    $("r-p").textContent = p; $("r-pa").textContent = pa; $("r-d").textContent = de;
    const ini = (s) => String(s || "").split(/\s+/).filter(Boolean).map((x) => x[0]).slice(0, 2).join("").toUpperCase();
    $("r-coment").innerHTML = (d.respuestas || []).map((r) => `
      <article class="comentario">
        <div><span class="est-txt">${"★".repeat(r.calificacion)}${"☆".repeat(5 - r.calificacion)}</span> · <small>NPS ${r.nps}</small>
          ${r.publicable ? '<span class="pub-si">PUBLICADO EN LA WEB</span>' : '<span class="pub-no">SOLO INTERNO</span>'}</div>
        <p>${r.comentario ? esc(r.comentario) : '<i style="color:var(--muted)">Sin comentario</i>'}</p>
        <div class="quien"><span class="av">${esc(ini(r.cliente))}</span><span><b>${esc(r.cliente)}</b><small>${esc(r.materia)} · ${esc(r.codigo_interno)} · ${esc(r.fecha)}</small></span></div>
      </article>`).join("") || '<div class="vacio">Aún no hay encuestas respondidas.</div>';
  } catch (e) { $("r-coment").innerHTML = `<div class="alerta mal">${esc(e.message)}</div>`; }
}

// ---------------- Lista de comprobantes
async function cargarComprobantes() {
  const c = await api("../api/panel/t4/comprobantes");
  tabla($("t-comp"), c, [{ f: (x) => x.id_comprobante }, { f: (x) => `${esc(x.serie)}-${String(x.numero).padStart(6, "0")}` }, { f: (x) => esc(x.emision) }, { f: (x) => esc(x.cliente) },
    { f: (x) => soles(x.total) }, { f: (x) => soles(x.pagado) }, { f: (x) => soles(x.saldo) }, { f: (x) => estado(x.estado_pago) }], "Sin comprobantes.");
}

(async () => {
  estadoMongo($("mongo-estado"));
  const v = new Date(); v.setDate(v.getDate() + 7);
  $("c-vence").value = `${v.getFullYear()}-${String(v.getMonth() + 1).padStart(2, "0")}-${String(v.getDate()).padStart(2, "0")}`; $("c-vence").min = hoyISO();
  try {
    await cargarSeries();
    await Promise.all([cargarClientes(), cargarConSaldo(), cargarCerrar(), cargarFormulario(), cargarEncuestas(), cargarComprobantes()]);
  } catch (e) { $("a18").className = "alerta mal"; $("a18").textContent = e.message; }
})();
