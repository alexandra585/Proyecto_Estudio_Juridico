// =====================================================================
// PORTAL DEL CLIENTE (TO-BE): ver su caso, firmar su contrato, ver sus cuotas y responder la encuesta.
// API: /api/portal/** (sesión de cliente: USUARIO con id_persona)
// =====================================================================
const $ = (id) => document.getElementById(id);
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const soles = (n) => "S/ " + Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const estado = (e) => `<span class="estado e-${esc(e)}">${esc(String(e).replace("_", " "))}</span>`;
let datos = null, yo = null;

async function api(url, opc) {
  const r = await fetch(url, opc);
  const d = await r.json().catch(() => ({}));
  if (r.status === 401 && !url.endsWith("/login")) { mostrarLogin(); throw new Error(d.error || "Inicie sesión"); }
  if (!r.ok) throw new Error(d.error || "Error " + r.status);
  return d;
}
const post = (url, body) => api(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body || {}) });

// ---------------------------------------------------------------- ingreso
function mostrarLogin() {
  $("p-login").hidden = false; $("p-app").hidden = true; $("p-nav").hidden = true; $("p-user").hidden = true;
}
$("f-login").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("l-alerta"); a.className = "alerta";
  const usuario = $("l-usuario").value.trim(), contrasena = $("l-clave").value;
  if (!usuario || !contrasena) { a.className = "alerta mal"; a.textContent = "Escriba su documento (o correo) y su contraseña."; return; }
  $("l-btn").disabled = true;
  try { yo = await post("../api/portal/login", { usuario, contrasena }); $("l-clave").value = ""; await entrar(); }
  catch (err) { a.className = "alerta mal"; a.textContent = err.message; }
  finally { $("l-btn").disabled = false; }
});
document.querySelectorAll("[data-demo]").forEach((b) => b.addEventListener("click", () => { $("l-usuario").value = b.dataset.demo; $("l-clave").value = "Cliente2026!"; $("l-clave").focus(); }));
$("p-salir").addEventListener("click", async () => { await fetch("../api/portal/salir", { method: "POST" }); yo = null; mostrarLogin(); });

async function entrar() {
  $("p-login").hidden = true; $("p-app").hidden = false; $("p-nav").hidden = false; $("p-user").hidden = false;
  const nombre = yo.nombre || "";
  const corto = nombre.split(/\s+/).slice(0, 1).join(" ");
  $("p-nom").textContent = nombre; $("p-av").textContent = nombre.split(/\s+/).map((x) => x[0]).join("").slice(0, 2).toUpperCase();
  $("p-hola").textContent = "Hola, " + corto;
  $("p-sub").textContent = yo.documento + " · Portal del cliente de Magallanes-Montero Abogados";
  await cargar();
}

// ---------------------------------------------------------------- navegación
function ir(sec) {
  ["inicio", "casos", "pagos", "avisos"].forEach((s) => $("s-" + s).hidden = s !== sec);
  document.querySelectorAll("#p-tabs button, #p-nav button").forEach((b) => b.classList.toggle("activo", b.dataset.s === sec));
  if (sec === "casos") { $("casos-lista").hidden = false; $("caso-det").hidden = true; }
  if (sec === "avisos") { try { localStorage.setItem("mm-portal-avisos", (datos.avisos[0] || {}).fecha || ""); } catch (e) { /* */ } marcarAvisos(); }
  window.scrollTo({ top: 0, behavior: "smooth" });
}
document.querySelectorAll("#p-tabs button, #p-nav button").forEach((b) => b.addEventListener("click", () => ir(b.dataset.s)));
$("volver").addEventListener("click", () => { $("casos-lista").hidden = false; $("caso-det").hidden = true; });

// ---------------------------------------------------------------- datos
async function cargar() {
  datos = await api("../api/portal/resumen");
  pintarTareas(); pintarCasos(); pintarContratos(); pintarPagos(); pintarAvisos();
}

function pintarTareas() {
  const t = [];
  datos.contratos.filter((k) => k.pendiente_firma).forEach((k) => t.push(`<div class="p-tarea"><div class="ic">✍</div>
    <div><b>Firme su contrato ${esc(k.nro_contrato)}</b><small>${esc(k.materia)} · ${esc(k.abogado)} · honorarios ${soles(k.monto_honorarios)}</small></div>
    <button class="btn btn-oro" type="button" data-contrato="${k.id_contrato}">Revisar y firmar</button></div>`));
  datos.encuestas.filter((e) => !e.respondida).forEach((e) => t.push(`<div class="p-tarea azul"><div class="ic">★</div>
    <div><b>¿Cómo le atendimos?</b><small>Su caso ${esc(e.codigo_interno)} concluyó. Responda la encuesta (1 minuto).</small></div>
    <button class="btn btn-oro" type="button" data-encuesta="${e.id_encuesta}" data-caso="${esc(e.codigo_interno)}">Responder encuesta</button></div>`));
  datos.cuotas.filter((q) => q.estado === "VENCIDA").forEach((q) => t.push(`<div class="p-tarea rojo"><div class="ic">💳</div>
    <div><b>Cuota vencida: ${soles(q.monto)}</b><small>${esc(q.nro_contrato)} · ${esc(q.concepto.toLowerCase())} ${q.nro_cuota} · venció el ${esc(q.vence)}</small></div>
    <button class="btn btn-sec" type="button" data-ir="pagos">Ver mis pagos</button></div>`));
  datos.cuotas.filter((q) => (q.estado === "PENDIENTE" || q.estado === "PAGADA_PARCIAL") && q.dias >= 0 && q.dias <= 7 && !q.pendiente_firma).forEach((q) => t.push(`<div class="p-tarea"><div class="ic">📅</div>
    <div><b>Cuota por vencer: ${soles(q.monto)}</b><small>${esc(q.nro_contrato)} · vence el ${esc(q.vence)} (${q.dias === 0 ? "hoy" : "en " + q.dias + " día(s)"})</small></div>
    <button class="btn btn-sec" type="button" data-ir="pagos">Ver mis pagos</button></div>`));
  datos.casos.filter((c) => c.proxima_audiencia).forEach((c) => t.push(`<div class="p-tarea azul"><div class="ic">🗓</div>
    <div><b>Audiencia programada</b><small>${esc(c.codigo_interno)} · ${esc(c.proxima_audiencia)}</small></div>
    <button class="btn btn-sec" type="button" data-caso-id="${c.id_caso}">Ver mi caso</button></div>`));
  $("tareas").innerHTML = t.join("") || '<div class="p-todo-ok">✓ Está todo al día. Le avisaremos aquí cuando necesitemos algo de usted.</div>';
  enlazar($("tareas"));
}

const tarjetaCaso = (c) => `<button class="p-caso" type="button" data-caso-id="${c.id_caso}">
    <div class="cod">${esc(c.codigo_interno)}${c.nro_expediente_judicial ? " · " + esc(c.nro_expediente_judicial) : ""}</div>
    <h3>${esc(c.descripcion)}</h3>
    <div class="barra"><div style="width:${c.estado === "CERRADO" ? 100 : Math.round(100 * (c.orden_etapa || 1) / (c.total_etapas || 9))}%"></div></div>
    <div class="et"><span>${c.estado === "CERRADO" ? "Concluido" : "Etapa: <b>" + esc(c.etapa || "—") + "</b>"}</span><span>${esc(c.materia)}</span></div>
    ${c.proxima_audiencia ? `<div class="aud">🗓 Audiencia: ${esc(c.proxima_audiencia)}</div>` : ""}
    <div class="p-pie"><span>Abogado: ${esc(c.abogado)}</span><span class="ver">Ver detalle →</span></div></button>`;

function pintarCasos() {
  const activos = datos.casos.filter((c) => c.estado !== "CERRADO");
  $("casos-ini").innerHTML = (activos.length ? activos : datos.casos).map(tarjetaCaso).join("")
    || '<div class="p-todo-ok" style="color:var(--muted);border-color:var(--linea)">Su expediente se abrirá cuando el contrato esté firmado.</div>';
  $("casos-todos").innerHTML = datos.casos.map(tarjetaCaso).join("") || '<div class="p-todo-ok" style="color:var(--muted);border-color:var(--linea)">Aún no tiene casos abiertos.</div>';
  enlazar($("casos-ini")); enlazar($("casos-todos"));
}

function pintarContratos() {
  $("contratos").innerHTML = datos.contratos.map((k) => `<div class="p-tarea ${k.pendiente_firma ? "" : "verde"}"><div class="ic">${k.pendiente_firma ? "✍" : "📄"}</div>
    <div><b>${esc(k.nro_contrato)} · ${esc(k.materia)}</b><small>${k.pendiente_firma ? "Pendiente de su firma" : `Firmado el ${esc(k.fecha_firma)} (${esc((k.modalidad_firma || "").toLowerCase())})`} · ${esc(k.tipo_encargo.toLowerCase())}</small></div>
    <button class="btn ${k.pendiente_firma ? "btn-oro" : "btn-sec"}" type="button" data-contrato="${k.id_contrato}">${k.pendiente_firma ? "Revisar y firmar" : "Ver contrato"}</button></div>`).join("")
    || '<div class="p-nota">Sin contratos.</div>';
  enlazar($("contratos"));
}

function pintarPagos() {
  const q = datos.cuotas.filter((x) => !x.pendiente_firma);
  const sum = (f) => q.filter(f).reduce((a, x) => a + Number(x.monto), 0);
  const pagado = sum((x) => x.estado === "PAGADA"), pendiente = sum((x) => x.estado !== "PAGADA"), vencido = sum((x) => x.estado === "VENCIDA");
  $("kpis").innerHTML = `<div class="p-kpi verde"><small>Pagado</small><b>${soles(pagado)}</b></div>
    <div class="p-kpi"><small>Por pagar</small><b>${soles(pendiente)}</b></div><div class="p-kpi ${vencido ? "rojo" : ""}"><small>Vencido</small><b>${soles(vencido)}</b></div>`;
  $("cuotas").innerHTML = datos.cuotas.map((x) => `<div class="p-cuota"><div><b>${esc(x.concepto.replace("_", " ").toLowerCase())} ${x.nro_cuota}</b> <small>· ${esc(x.nro_contrato)}</small><br>
      <small>${x.pendiente_firma ? "Se activa cuando firme el contrato" : "Vence el " + esc(x.vence)}</small></div>
      <div><div class="m">${soles(x.monto)}</div>${x.pendiente_firma ? '<span class="estado e-PENDIENTE">POR FIRMAR</span>' : estado(x.estado)}</div></div>`).join("")
    || '<p class="p-nota">No tiene cuotas registradas (servicio pro bono o contrato sin cronograma).</p>';
}

const ICON = { APERTURA_EXPEDIENTE: "📂", FIRMA_DOCUMENTO: "✍", CONFIRMACION_CONSULTA: "📩", AVISO_AUDIENCIA: "🗓", RECORDATORIO_CUOTA: "💳", CONSTANCIA_PAGO: "✅", ENVIO_ENCUESTA: "★", RECORDATORIO_CITA: "📅" };
function pintarAvisos() {
  $("avisos").innerHTML = datos.avisos.map((a) => `<div class="p-aviso"><div class="ic">${ICON[a.tipo_evento] || "•"}</div>
    <div><b>${esc(a.mensaje)}</b><small>${new Date(a.fecha).toLocaleString("es-PE", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })} · ${esc(a.canal === "SISTEMA" ? "portal" : a.canal.toLowerCase())}</small></div></div>`).join("")
    || '<p class="p-nota">No tiene avisos.</p>';
  marcarAvisos();
}
function marcarAvisos() {
  let visto = ""; try { visto = localStorage.getItem("mm-portal-avisos") || ""; } catch (e) { /* */ }
  const n = datos.avisos.filter((a) => a.fecha > visto).length;
  ["n-avisos", "n-avisos2"].forEach((id) => { $(id).hidden = !n; $(id).textContent = n; });
}

function enlazar(zona) {
  zona.querySelectorAll("[data-contrato]").forEach((b) => b.addEventListener("click", () => abrirContrato(Number(b.dataset.contrato))));
  zona.querySelectorAll("[data-encuesta]").forEach((b) => b.addEventListener("click", () => abrirEncuesta(Number(b.dataset.encuesta), b.dataset.caso)));
  zona.querySelectorAll("[data-ir]").forEach((b) => b.addEventListener("click", () => ir(b.dataset.ir)));
  zona.querySelectorAll("[data-caso-id]").forEach((b) => b.addEventListener("click", () => verCaso(Number(b.dataset.casoId))));
}

async function verCaso(id) {
  ir("casos");
  $("casos-lista").hidden = true; $("caso-det").hidden = false;
  $("ficha").innerHTML = '<div class="p-nota">Cargando su expediente…</div>';
  try { renderFicha($("ficha"), await api(`../api/portal/casos/${id}`), { cliente: true }); }
  catch (e) { $("ficha").innerHTML = `<div class="alerta mal" style="display:block">${esc(e.message)}</div>`; }
}

// ---------------------------------------------------------------- ventanas
document.querySelectorAll(".p-modal").forEach((m) => {
  m.querySelector("[data-cerrar]").addEventListener("click", () => m.hidden = true);
  m.addEventListener("click", (e) => { if (e.target === m) m.hidden = true; });
});

// ---- Contrato + firma digital (lienzo)
async function abrirContrato(id) {
  const m = $("m-contrato"); m.hidden = false;
  $("mc-cuerpo").innerHTML = '<p class="p-nota">Cargando contrato…</p>';
  try {
    const k = await api(`../api/portal/contratos/${id}`);
    $("mc-tit").textContent = "Contrato " + k.nro_contrato;
    const pendiente = !k.fecha_firma;
    $("mc-cuerpo").innerHTML = `<div class="p-contrato">
        <h3>CONTRATO DE PRESTACIÓN DE SERVICIOS PROFESIONALES</h3>
        <div class="partes">N.° ${esc(k.nro_contrato)}<br>MAGALLANES-MONTERO ABOGADOS y ${esc(k.cliente)} (${esc(k.documento)})</div>
        ${k.clausulas.map((c) => `<p>${esc(c)}</p>`).join("")}
      </div>
      ${pendiente ? `<div class="p-firma-zona">
        <label class="check"><input type="checkbox" id="mc-acepta"> He leído el contrato y acepto sus condiciones.</label>
        <div style="margin-top:12px"><label for="mc-lienzo">Firme aquí con el dedo o el mouse</label>
          <canvas class="p-lienzo" id="mc-lienzo"></canvas>
          <div class="p-firma-acc"><span>Firma de: <b>${esc(k.cliente)}</b></span><button type="button" id="mc-borrar">Borrar firma</button></div></div>
        <div class="alerta" id="mc-alerta"></div>
        <button class="btn btn-oro" type="button" id="mc-firmar" style="width:100%;margin-top:14px">Firmar contrato</button>
        <p class="p-nota">Si prefiere, puede firmarlo en papel en el estudio. Su firma digital se guarda con la fecha y hora.</p></div>`
      : `<div class="p-firmado">${k.firma && k.firma.imagen_png ? `<img src="${esc(k.firma.imagen_png)}" alt="Firma">` : "✓"}
          <div>Contrato firmado el ${esc(k.fecha_firma)}<br><small style="font-weight:600">Modalidad: ${esc((k.modalidad_firma || "").toLowerCase())}${k.firma ? " · " + esc(k.firma.firmado_por) : ""}</small></div></div>`}`;
    if (pendiente) prepararLienzo(id);
  } catch (e) { $("mc-cuerpo").innerHTML = `<div class="alerta mal" style="display:block">${esc(e.message)}</div>`; }
}

function prepararLienzo(idContrato) {
  const cv = $("mc-lienzo"), ctx = cv.getContext("2d");
  let trazos = 0, dibujando = false, ultimo = null;
  const ajustar = () => { const r = cv.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    cv.width = r.width * dpr; cv.height = r.height * dpr; ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.lineWidth = 2.4; ctx.lineCap = "round"; ctx.lineJoin = "round"; ctx.strokeStyle = "#14254A"; };
  ajustar();
  const pos = (e) => { const r = cv.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; };
  cv.addEventListener("pointerdown", (e) => { dibujando = true; ultimo = pos(e); cv.setPointerCapture(e.pointerId); });
  cv.addEventListener("pointermove", (e) => { if (!dibujando) return; const p = pos(e);
    ctx.beginPath(); ctx.moveTo(ultimo.x, ultimo.y); ctx.lineTo(p.x, p.y); ctx.stroke(); ultimo = p; trazos++; cv.classList.add("firmado"); });
  ["pointerup", "pointercancel", "pointerleave"].forEach((t) => cv.addEventListener(t, () => dibujando = false));
  $("mc-borrar").addEventListener("click", () => { ctx.clearRect(0, 0, cv.width, cv.height); trazos = 0; cv.classList.remove("firmado"); });
  $("mc-firmar").addEventListener("click", async () => {
    const a = $("mc-alerta"); a.className = "alerta";
    if (!$("mc-acepta").checked) { a.className = "alerta mal"; a.textContent = "Marque que leyó y acepta el contrato."; return; }
    if (trazos < 8) { a.className = "alerta mal"; a.textContent = "Dibuje su firma en el recuadro."; return; }
    // PNG con fondo blanco y tamaño reducido (se guarda en MongoDB «archivos».firma.imagen_png)
    const out = document.createElement("canvas"); out.width = 500; out.height = Math.round(500 * cv.height / cv.width);
    const o = out.getContext("2d"); o.fillStyle = "#fff"; o.fillRect(0, 0, out.width, out.height); o.drawImage(cv, 0, 0, out.width, out.height);
    const b = $("mc-firmar"); b.disabled = true; b.textContent = "Firmando…";
    try {
      const r = await post(`../api/portal/contratos/${idContrato}/firmar`, { acepta: true, firma: out.toDataURL("image/png") });
      a.className = "alerta ok"; a.textContent = "✓ " + r.mensaje + (r.aviso ? " " + r.aviso : "");
      await cargar();
      setTimeout(() => abrirContrato(idContrato), 900);
    } catch (err) { a.className = "alerta mal"; a.textContent = err.message; b.disabled = false; b.textContent = "Firmar contrato"; }
  });
}

// ---- Encuesta (preguntas leídas de MongoDB «formularios_encuesta»)
async function abrirEncuesta(id, codigo) {
  const m = $("m-encuesta"); m.hidden = false;
  $("me-tit").textContent = "Encuesta · caso " + (codigo || "");
  const f = $("me-form"); f.innerHTML = '<p class="p-nota">Cargando…</p>';
  const resp = {};
  try {
    const form = await api("../api/portal/formulario-encuesta");
    f.innerHTML = `<p style="margin:0;color:var(--muted)">Su opinión nos ayuda a mejorar. Toma un minuto.</p>
      ${form.preguntas.map((p) => {
        let c = "";
        if (p.tipo === "ESTRELLAS_1_5") c = `<div class="p-estrellas" data-k="${esc(p.clave)}">${[1, 2, 3, 4, 5].map((n) => `<button type="button" data-v="${n}" aria-label="${n} estrellas">★</button>`).join("")}</div>`;
        else if (p.tipo === "NPS_0_10") c = `<div class="p-nps" data-k="${esc(p.clave)}">${[...Array(11).keys()].map((n) => `<button type="button" data-v="${n}">${n}</button>`).join("")}</div>
          <div class="p-nps-ley"><span>Nada probable</span><span>Muy probable</span></div>`;
        else if (p.tipo === "SI_NO") c = `<div class="p-sino" data-k="${esc(p.clave)}"><label><input type="radio" name="q-${esc(p.clave)}" value="Sí">Sí</label><label><input type="radio" name="q-${esc(p.clave)}" value="No">No</label></div>`;
        else c = `<div class="campo"><input data-txt="${esc(p.clave)}"></div>`;
        return `<div class="p-pregunta"><label>${esc(p.texto)}</label>${c}</div>`;
      }).join("")}
      <div class="p-pregunta campo"><label for="me-com">Comentario (opcional)</label><textarea id="me-com" maxlength="500" placeholder="Cuéntenos su experiencia"></textarea></div>
      <div class="p-permiso"><label class="check" style="margin:0"><input type="checkbox" id="me-pub"> Autorizo publicar mi comentario en la página web del estudio</label>
        <div class="radios" id="me-firma-pub" hidden>
          <label><input type="radio" name="me-firma" value="NOMBRE"> Con mi nombre e inicial del apellido</label>
          <label><input type="radio" name="me-firma" value="INICIALES" checked> Solo con mis iniciales</label>
          <label><input type="radio" name="me-firma" value="ANONIMO"> Como «Cliente del estudio»</label></div></div>
      <div class="alerta" id="me-alerta"></div>
      <button class="btn btn-oro" type="submit" id="me-btn" style="width:100%;margin-top:16px">Enviar respuestas</button>`;
    f.querySelectorAll(".p-estrellas, .p-nps").forEach((g) => g.querySelectorAll("button").forEach((b) => b.addEventListener("click", () => {
      resp[g.dataset.k] = Number(b.dataset.v);
      g.querySelectorAll("button").forEach((x) => x.classList.toggle("on", g.classList.contains("p-estrellas") ? Number(x.dataset.v) <= Number(b.dataset.v) : x === b));
    })));
    $("me-pub").addEventListener("change", () => $("me-firma-pub").hidden = !$("me-pub").checked);
    f.onsubmit = async (e) => {
      e.preventDefault();
      const a = $("me-alerta"); a.className = "alerta";
      f.querySelectorAll(".p-sino").forEach((g) => { const r = g.querySelector("input:checked"); if (r) resp[g.dataset.k] = r.value; });
      f.querySelectorAll("[data-txt]").forEach((i) => { if (i.value.trim()) resp[i.dataset.txt] = i.value.trim(); });
      if (resp.calificacion == null || resp.nps == null) { a.className = "alerta mal"; a.textContent = "Marque las estrellas y qué tan probable es que nos recomiende."; return; }
      const extra = { ...resp }; delete extra.calificacion; delete extra.nps;
      $("me-btn").disabled = true;
      try {
        const r = await post(`../api/portal/encuestas/${id}/responder`, { calificacion: resp.calificacion, nps: resp.nps, comentario: $("me-com").value.trim(),
          respuestas: extra, autorizaPublicar: $("me-pub").checked, firma: (f.querySelector('input[name="me-firma"]:checked') || {}).value || "INICIALES" });
        f.innerHTML = `<div class="p-firmado" style="margin-top:0">★ ¡Gracias! Recibimos su encuesta.${r.publicable ? `<br><small style="font-weight:600">Su comentario podrá aparecer en la web como «${esc(r.nombrePublico)}».</small>` : ""}</div>`;
        await cargar();
      } catch (err) { a.className = "alerta mal"; a.textContent = err.message; $("me-btn").disabled = false; }
    };
  } catch (e) { f.innerHTML = `<div class="alerta mal" style="display:block">${esc(e.message)}</div>`; }
}

// ---------------------------------------------------------------- inicio
(async () => {
  try { yo = await api("../api/portal/yo"); await entrar(); }
  catch (e) { mostrarLogin(); }
})();
