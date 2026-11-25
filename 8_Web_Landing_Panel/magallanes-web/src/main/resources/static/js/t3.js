// =====================================================================
// T3 · Gestión del expediente: W11 escrito · W12 presentación · W13 resolución y plazo
// =====================================================================
let casos = [];
const caso = () => Number($("caso").value);

document.querySelectorAll(".pestanas button").forEach((b) => b.addEventListener("click", () => {
  document.querySelectorAll(".pestanas button").forEach((x) => x.classList.toggle("activo", x === b));
  ["w11", "w12", "w13"].forEach((id) => $(id).hidden = id !== b.dataset.p);
}));

async function cambiarCaso() {
  if (!caso()) return;
  const jur = await api(`../api/panel/t3/casos/${caso()}/jurisprudencia`);
  $("e-juris").innerHTML = jur.length ? jur.map((j) => `<label><input type="checkbox" class="ju" value="${j.id_jurisprudencia}" data-ref="${esc(j.referencia)}">
      <span><b>${esc(j.referencia)}</b> · ${esc(j.tipo)}<br><small>${esc(j.titulo)}</small></span></label>`).join("")
    : '<div class="vacio" style="padding:10px">No hay jurisprudencia registrada para esta materia.</div>';
  await cargarMovimientos();
}

async function cargarFicha() {
  try { renderFicha($("ficha"), await api(`../api/panel/t3/casos/${caso()}/ficha`)); }
  catch (e) { $("ficha").innerHTML = `<div class="vacio" style="color:var(--rojo)">${esc(e.message)}</div>`; }
}

async function cargarMovimientos() {
  cargarFicha();
  const [docs, pres, res, plazos] = await Promise.all([api(`../api/panel/t3/casos/${caso()}/documentos`),
    api(`../api/panel/t3/casos/${caso()}/presentaciones`), api(`../api/panel/t3/casos/${caso()}/resoluciones`),
    api(`../api/panel/t3/casos/${caso()}/plazos-pendientes`)]);
  opciones($("p-plazo"), plazos, "id_plazo", (p) => `${p.descripcion} · vence ${p.vence} · ${p.estado}`, plazos.length ? "— No, solo presentar —" : "El caso no tiene plazos pendientes");
  opciones($("p-doc"), docs.filter((d) => d.estado !== "PRESENTADO"), "id_documento", (d) => `N.° ${d.id_documento} · ${d.tipo_documento} · ${d.titulo}`, docs.some((d) => d.estado !== "PRESENTADO") ? null : "No hay escritos por presentar");
  opciones($("r-pres"), pres, "id_presentacion", (p) => `N.° ${p.id_presentacion} · ${p.titulo} · ${p.fecha}`, "— Ninguna —");
  const mongoBtn = (id) => id ? `<button class="btn btn-sec btn-mini" type="button" onclick="verMongo('../api/panel/t3/archivos/${id.trim()}')">JSON</button>` : "—";
  tabla($("t-docs"), docs, [{ f: (d) => `<b>${d.id_documento}</b>` }, { f: (d) => esc(d.tipo_documento) }, { f: (d) => esc(d.titulo) }, { f: (d) => d.citas },
    { f: (d) => estado(d.estado) }, { f: (d) => mongoBtn(d.archivo_mongo_id) }], "Sin escritos.");
  tabla($("t-res"), res, [{ f: (r) => `<b>${r.id_resolucion}</b> ${esc(r.nro_resolucion || "")}` }, { f: (r) => esc(r.tipo_resolucion) }, { f: (r) => esc(r.notificada) },
    { f: (r) => esc(r.plazo || "—") }, { f: (r) => mongoBtn(r.archivo_mongo_id) }], "Sin resoluciones.");
}

async function calcularVence() {
  if (!$("r-con-plazo").checked || !$("r-fecha").value || !(Number($("pl-dias").value) > 0)) { $("pl-vence").textContent = "—"; return; }
  try {
    const v = await api(`../api/panel/t3/vencimiento?inicio=${$("r-fecha").value}&dias=${$("pl-dias").value}&tipo=${$("pl-tipo").value}`);
    $("pl-vence").textContent = v.vence.split("-").reverse().join("/");
  } catch (e) { $("pl-vence").textContent = "—"; }
}
["r-fecha", "pl-dias", "pl-tipo"].forEach((id) => $(id).addEventListener("change", calcularVence));
$("r-con-plazo").addEventListener("change", () => { $("r-plazo").hidden = !$("r-con-plazo").checked; calcularVence(); });

function traza(div, titulo, lineas, mongoUrl, aviso, mensaje) {
  div.innerHTML = `<div class="aviso verde">✔ ${esc(mensaje)}</div>${aviso ? `<div class="aviso amarillo">${esc(aviso)}</div>` : ""}
    <div class="traza bd-traza"><div>COMMIT ✔ ${esc(titulo)}</div>${lineas.map((l) => `<div>${l}</div>`).join("")}</div>
    ${mongoUrl ? `<button class="btn btn-sec btn-mini" type="button" onclick="verMongo('${mongoUrl}')">Ver el documento guardado en MongoDB</button>` : ""}`;
}

// ---------------- W11
$("w11").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("a11"); a.className = "alerta";
  if (!$("e-titulo").value.trim() || !$("e-texto").value.trim()) { a.className = "alerta mal"; a.textContent = "Escriba la sumilla y el texto del escrito."; return; }
  const juris = [...document.querySelectorAll(".ju:checked")].map((c) => ({ idJurisprudencia: Number(c.value), referencia: c.dataset.ref }));
  const b = $("b11"); b.disabled = true;
  try {
    const r = await postJSON("../api/panel/t3/escritos", { idCaso: caso(), tipoDocumento: $("e-tipo").value, titulo: $("e-titulo").value.trim(),
      contenido: $("e-texto").value, elaboradoConIa: $("e-ia").checked, requiereFirmaCliente: $("e-firma").checked, jurisprudencia: juris });
    traza($("r11"), "Transacción W11", [`<b>DOCUMENTO_LEGAL</b> id_documento = ${r.idDocumento} · BORRADOR · versión 1`,
      `<b>DOCUMENTO_JURISPRUDENCIA</b> ${r.citas} fila(s)`, `<b>MongoDB · archivos</b> _id = ${esc(r.archivoMongoId || "—")} → documento_legal.archivo_mongo_id`,
      `<b>MongoDB · expedientes</b> bitácora + índice de archivos del caso`], r.archivoMongoId ? `../api/panel/t3/archivos/${r.archivoMongoId}` : null, r.aviso, r.mensaje);
    $("e-titulo").value = ""; $("e-texto").value = ""; document.querySelectorAll(".ju").forEach((c) => c.checked = false);
    await cargarMovimientos();
  } catch (err) { mostrarError(a, err); } finally { b.disabled = false; }
});

// ---------------- W12
$("w12").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("a12"); a.className = "alerta";
  if (!$("p-doc").value) { a.className = "alerta mal"; a.textContent = "No hay escrito para presentar."; return; }
  const b = $("b12"); b.disabled = true;
  try {
    const r = await postJSON("../api/panel/t3/presentaciones", { idDocumento: Number($("p-doc").value), idEntidad: Number($("p-entidad").value),
      fechaHora: $("p-fecha").value ? $("p-fecha").value + ":00" : "", modalidad: $("p-modalidad").value, nroCargo: $("p-cargo").value.trim(),
      idPlazo: $("p-plazo").value ? Number($("p-plazo").value) : null });
    traza($("r12"), "Transacción W12", [`<b>PRESENTACION</b> id_presentacion = ${r.idPresentacion}`, `<b>DOCUMENTO_LEGAL</b> N.° ${r.idDocumento} → PRESENTADO`,
      ...(r.idPlazo ? [`<b>PLAZO</b> N.° ${r.idPlazo} → CUMPLIDO (id_presentacion_cumplimiento = ${r.idPresentacion})`] : [])], null, null, r.mensaje);
    $("p-cargo").value = "";
    await cargarMovimientos();
  } catch (err) { mostrarError(a, err); } finally { b.disabled = false; }
});

// ---------------- W13
$("w13").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("a13"); a.className = "alerta";
  const conPlazo = $("r-con-plazo").checked;
  if (conPlazo && !$("pl-desc").value.trim()) { a.className = "alerta mal"; a.textContent = "Describa qué hay que hacer en el plazo."; return; }
  const b = $("b13"); b.disabled = true;
  try {
    const r = await postJSON("../api/panel/t3/resoluciones", { idCaso: caso(), idEntidad: Number($("r-entidad").value), idPresentacion: $("r-pres").value,
      nroResolucion: $("r-nro").value.trim(), tipoResolucion: $("r-tipo").value, fechaNotificacion: $("r-fecha").value, medioNotificacion: $("r-medio").value,
      sumilla: $("r-sumilla").value.trim(), texto: $("r-texto").value.trim(),
      plazoDescripcion: conPlazo ? $("pl-desc").value.trim() : "", plazoDias: $("pl-dias").value, plazoTipoComputo: $("pl-tipo").value, plazoResponsable: $("pl-resp").value });
    traza($("r13"), "Transacción W13", [`<b>RESOLUCION</b> id_resolucion = ${r.idResolucion}`,
      r.idPlazo ? `<b>PLAZO</b> id_plazo = ${r.idPlazo} · vence ${r.vence.split("-").reverse().join("/")}` : "PLAZO: no aplica",
      `<b>MongoDB · archivos</b> _id = ${esc(r.archivoMongoId || "—")}`], r.archivoMongoId ? `../api/panel/t3/archivos/${r.archivoMongoId}` : null, r.aviso, r.mensaje);
    ["r-nro", "r-sumilla", "r-texto", "pl-desc"].forEach((id) => $(id).value = "");
    await cargarMovimientos();
  } catch (err) { mostrarError(a, err); } finally { b.disabled = false; }
});

$("ver-exp").addEventListener("click", () => verMongo(`../api/panel/t2/casos/${caso()}/expediente-mongo`));
$("caso").addEventListener("change", cambiarCaso);

(async () => {
  estadoMongo($("mongo-estado"));
  const ahora = new Date(); ahora.setMinutes(ahora.getMinutes() - ahora.getTimezoneOffset());
  $("p-fecha").value = ahora.toISOString().slice(0, 16);
  $("r-fecha").value = hoyISO(); $("r-fecha").max = hoyISO();
  try {
    casos = await api("../api/panel/t3/casos-activos");
    opciones($("caso"), casos, "id_caso", (c) => `${c.codigo_interno} · ${c.cliente} · ${c.materia}`);
    const ent = await api("../api/panel/t3/entidades");
    opciones($("p-entidad"), ent, "id_entidad", (x) => x.nombre); opciones($("r-entidad"), ent, "id_entidad", (x) => x.nombre);
    opciones($("pl-resp"), await api("../api/panel/t3/empleados"), "id_empleado", (x) => x.nombre + " · " + x.cargo);
    if (casos.length) await cambiarCaso();
    calcularVence();
  } catch (e) { $("a11").className = "alerta mal"; $("a11").textContent = e.message; }
})();
