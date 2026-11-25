// =====================================================================
// W09 · Apertura del expediente: CASO + CASO_PARTE + CASO_ETAPA + MongoDB «expedientes»
// =====================================================================
let contratos = [], roles = [], actual = null;

async function cargarContratos() {
  try {
    contratos = await api("../api/panel/t2/contratos-sin-caso");
    $("contratos").innerHTML = contratos.length ? contratos.map((k) => `<tr data-id="${k.id_contrato}" class="${actual && actual.id_contrato === k.id_contrato ? "sel" : ""}">
      <td><b>${k.id_contrato}</b></td><td>${esc(k.nro_contrato)}</td><td>${esc(k.fecha_firma)}</td><td>${esc(k.cliente)}</td><td>${esc(k.materia)}</td>
      <td>${esc(k.abogado)}</td><td>${esc(k.tipo_encargo)}</td></tr>`).join("")
      : '<tr><td colspan="7" class="vacio">Todos los contratos ya tienen expediente. Registre un contrato en «Contratos y cuotas».</td></tr>';
    document.querySelectorAll("#contratos tr[data-id]").forEach((tr) => tr.addEventListener("click", () => elegir(Number(tr.dataset.id))));
    // TO-BE: el expediente se abre solo con el contrato FIRMADO (digital en el portal o presencial)
    const pend = await api("../api/panel/t2/contratos-por-firmar").catch(() => []);
    $("por-firmar").innerHTML = pend.length ? `<div class="aviso amarillo">Esperando la firma del cliente (no se puede abrir su expediente todavía): ${pend.map((k) =>
      `<b>${esc(k.nro_contrato)}</b> · ${esc(k.cliente)}`).join(" — ")} <span class="bd">contrato.fecha_firma IS NULL</span></div>` : "";
  } catch (e) { $("contratos").innerHTML = `<tr><td colspan="7" class="vacio" style="color:var(--rojo)">${esc(e.message)}</td></tr>`; }
}

async function elegir(id) {
  actual = contratos.find((k) => k.id_contrato === id);
  document.querySelectorAll("#contratos tr").forEach((tr) => tr.classList.toggle("sel", Number(tr.dataset.id) === id));
  $("form-caso").hidden = false; $("resultado").innerHTML = ""; $("alerta").className = "alerta";
  $("c-nro").textContent = actual.nro_contrato + " · " + actual.cliente;
  $("codigo").value = (await api("../api/panel/t2/siguiente-codigo-caso")).codigoInterno;
  $("descripcion").value = `${actual.materia}: ${actual.resumen || ""}`.slice(0, 500);
  $("resumen").value = actual.resumen || "";
  const abogados = await api("../api/panel/abogados?materia=" + actual.id_materia);
  opciones($("abogado"), abogados, "idEmpleado", (a) => a.nombre + (a.esPrincipal ? " (principal)" : ""));
  if (abogados.some((a) => a.idEmpleado === actual.id_abogado)) $("abogado").value = actual.id_abogado;
  const cps = await api(`../api/panel/t2/consultas/${actual.id_consulta}/contrapartes`);
  const rolOpts = roles.map((r) => `<option value="${r.id_rol}">${esc(r.nombre)}</option>`).join("");
  $("contrapartes").innerHTML = cps.length ? cps.map((c) => `<label><input type="checkbox" class="cp" value="${c.id_persona}" checked>
      <span style="flex:1">${esc(c.nombre)} <small style="color:var(--muted)">· ${esc(c.documento)}</small><br>
      <select class="cp-rol" style="margin-top:4px;padding:4px;border-radius:6px;border:1px solid var(--linea)">${rolOpts}</select></span></label>`).join("")
    : '<div class="vacio" style="padding:10px">La consulta no registró contrapartes.</div>';
  const pasivo = roles.find((r) => r.nombre === "Demandado"); if (pasivo) document.querySelectorAll(".cp-rol").forEach((s) => s.value = pasivo.id_rol);
  $("form-caso").scrollIntoView({ behavior: "smooth", block: "start" });
}

$("form-caso").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("alerta"); a.className = "alerta";
  if (!$("descripcion").value.trim()) { a.className = "alerta mal"; a.textContent = "Escriba la descripción del caso."; return; }
  const contrapartes = [...document.querySelectorAll("#contrapartes label")].filter((l) => l.querySelector(".cp").checked)
    .map((l) => ({ idPersona: Number(l.querySelector(".cp").value), idRol: Number(l.querySelector(".cp-rol").value) }));
  const datos = { idContrato: actual.id_contrato, idAbogado: Number($("abogado").value), codigoInterno: $("codigo").value.trim(),
    nroExpedienteJudicial: $("nro-judicial").value.trim(), descripcion: $("descripcion").value.trim(), esAltaComplejidad: $("alta").checked,
    idRolCliente: Number($("rol-cliente").value), idEtapa: Number($("etapa").value), contrapartes,
    resumenHechos: $("resumen").value.trim(), etiquetas: $("etiquetas").value.split(",").map((x) => x.trim()).filter(Boolean) };
  const b = $("btn"); b.disabled = true; b.textContent = "Grabando…";
  try {
    const r = await postJSON("../api/panel/t2/casos", datos);
    $("form-caso").hidden = true;
    $("resultado").innerHTML = `<div class="tarjeta"><div class="aviso verde" style="margin-top:0">✔ ${esc(r.mensaje)}</div>
      ${r.aviso ? `<div class="aviso amarillo">${esc(r.aviso)}</div>` : ""}
      <div class="traza bd-traza"><div>COMMIT ✔ Transacción W09 registrada:</div>
        <div><b>CASO</b> id_caso = ${r.idCaso} · ${esc(r.codigoInterno)} · ACTIVO</div>
        <div><b>CASO_PARTE</b> ${r.partes} fila(s): 1 cliente + ${r.partes - 1} contraparte(s)</div>
        <div><b>CASO_ETAPA</b> etapa inicial abierta (fecha_fin NULL)</div>
        <div><b>MongoDB · expedientes</b> _id = ${esc(r.expedienteMongoId || "— (no disponible)")} → caso.expediente_mongo_id</div></div>
      ${r.expedienteMongoId ? `<button class="btn btn-sec btn-mini" type="button" onclick="verMongo('../api/panel/t2/casos/${r.idCaso}/expediente-mongo')">Ver el documento guardado en MongoDB</button>` : ""}</div>`;
    actual = null;
    await Promise.all([cargarContratos(), cargarCasos()]);
  } catch (err) { mostrarError(a, err); }
  finally { b.disabled = false; b.textContent = "Abrir expediente"; }
});

async function cargarCasos() {
  const casos = await api("../api/panel/t2/casos");
  tabla($("casos"), casos, [
    { f: (c) => `<b>${c.id_caso}</b>` }, { f: (c) => esc(c.codigo_interno) }, { f: (c) => esc(c.apertura) }, { f: (c) => esc(c.cliente) },
    { f: (c) => esc(c.materia) }, { f: (c) => esc(c.abogado) }, { f: (c) => c.partes }, { f: (c) => esc(c.etapa_actual || "—") }, { f: (c) => estado(c.estado) },
    { f: (c) => c.expediente_mongo_id ? `<button class="btn btn-sec btn-mini" type="button" onclick="verMongo('../api/panel/t2/casos/${c.id_caso}/expediente-mongo')">Ver JSON</button>` : "—" },
  ], "Sin casos.");
}

(async () => {
  estadoMongo($("mongo-estado"));
  try {
    roles = await api("../api/panel/t2/roles");
    opciones($("rol-cliente"), roles, "id_rol", (r) => r.nombre + " · " + r.familia);
    const dem = roles.find((r) => r.nombre === "Demandante"); if (dem) $("rol-cliente").value = dem.id_rol;
    opciones($("etapa"), await api("../api/panel/t2/etapas"), "id_etapa", (x) => x.orden + ". " + x.nombre);
    const post = [...$("etapa").options].find((o) => o.text.includes("Postulación")); if (post) $("etapa").value = post.value;
  } catch (e) { /* se ve en las tablas */ }
  cargarContratos(); cargarCasos();
})();
