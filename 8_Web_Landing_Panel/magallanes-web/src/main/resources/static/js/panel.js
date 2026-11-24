// =====================================================================
// Panel del estudio: W04 Bandeja de consultas + W06 Agendar cita
// =====================================================================
const $ = (id) => document.getElementById(id);
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
let actual = null;          // consulta seleccionada (detalle)
let horaElegida = null;

async function api(url, opciones) {
  const r = await fetch(url, opciones);
  if (r.status === 401) { location.href = "login.html"; throw new Error("Sesión vencida"); }
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.error || "Error " + r.status);
  return d;
}
const fechaLocal = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
const estado = (e) => `<span class="estado e-${esc(e)}">${esc(e)}</span>`;

// ---------- Sesión (W02)
async function iniciar() {
  await api("../api/auth/yo");   // el nombre y el rol los muestra js/menu.js
  const manana = new Date(); manana.setDate(manana.getDate() + 1);
  $("fecha").value = fechaLocal(manana);
  $("fecha").min = fechaLocal(new Date());
  cargarBandeja();
}


// ---------- Menú
document.querySelectorAll("button[data-vista]").forEach((b) => b.addEventListener("click", () => {
  $("vista-bandeja").hidden = b.dataset.vista !== "bandeja";
  $("vista-agenda").hidden = b.dataset.vista !== "agenda";
  if (b.dataset.vista === "agenda") cargarAgenda();
}));

// ---------- W04 · Bandeja
async function cargarBandeja() {
  const p = new URLSearchParams({ estado: $("f-estado").value, canal: $("f-canal").value });
  try {
    const filas = await api("../api/panel/consultas?" + p);
    $("total").textContent = `(${filas.length})`;
    $("filas").innerHTML = filas.length ? filas.map((f) => `
      <tr data-id="${f.idConsulta}" class="${actual && actual.consulta.idConsulta === f.idConsulta ? "sel" : ""}">
        <td><b>${f.idConsulta}</b>${f.esUrgente ? ' <span class="urg" title="Urgente">●</span>' : ""}</td>
        <td>${esc(f.fechaRecepcion)}</td><td>${esc(f.cliente)}</td><td>${esc(f.documento)}</td><td>${esc(f.materia)}</td>
        <td>${f.canal === "LANDING" ? '<span class="landing-tag">LANDING</span>' : esc(f.canal)}</td><td>${estado(f.estado)}</td><td>${esc(f.proximaCita || "—")}</td>
      </tr>`).join("") : '<tr><td colspan="8" class="vacio">No hay consultas con ese filtro.</td></tr>';
    document.querySelectorAll("#filas tr[data-id]").forEach((tr) => tr.addEventListener("click", () => abrirConsulta(Number(tr.dataset.id))));
  } catch (e) {
    $("filas").innerHTML = `<tr><td colspan="8" class="vacio" style="color:var(--rojo)">${esc(e.message)}</td></tr>`;
  }
}
$("f-estado").addEventListener("change", cargarBandeja);
$("f-canal").addEventListener("change", cargarBandeja);
$("refrescar").addEventListener("click", cargarBandeja);

async function abrirConsulta(id) {
  document.querySelectorAll("#filas tr").forEach((tr) => tr.classList.toggle("sel", Number(tr.dataset.id) === id));
  const d = await api("../api/panel/consultas/" + id);
  actual = d;
  const c = d.consulta;
  let conflicto;
  if (d.existeConflicto === true) conflicto = '<div class="aviso rojo">La consulta tiene conflicto de interés registrado: no se puede agendar.</div>';
  else if (d.posiblesConflictos.length) conflicto = `<div class="aviso amarillo"><b>Posible conflicto de interés (W05):</b><br>${d.posiblesConflictos.map(esc).join("<br>")}<br><span class="bd">consulta_contraparte ⋈ caso_parte (CLIENTE)</span></div>`;
  else conflicto = `<div class="aviso verde">Sin coincidencias: ninguna contraparte es cliente del estudio. <span class="bd">consulta_contraparte ⋈ caso_parte</span></div>`;

  $("detalle").innerHTML = `
    <h2>Consulta N.° ${c.idConsulta} ${estado(c.estado)} ${c.esUrgente ? '<span class="urg">URGENTE</span>' : ""}</h2>
    <dl>
      <dt>Cliente</dt><dd>${esc(c.cliente)} · ${esc(c.documento)} <span class="bd">persona</span></dd>
      <dt>Contacto</dt><dd>${esc(c.telefono || "—")} · ${esc(d.email || "—")}</dd>
      <dt>Materia / canal</dt><dd>${esc(c.materia)} · ${esc(c.canal)} <span class="bd">consulta.id_materia · consulta.canal</span></dd>
      <dt>Recepción</dt><dd>${esc(c.fechaRecepcion)}</dd>
      <dt>Relato</dt><dd>${esc(d.resumen)} <span class="bd">consulta.resumen</span></dd>
      <dt>Contraparte</dt><dd>${d.contrapartes.length ? d.contrapartes.map(esc).join("<br>") : "—"} <span class="bd">consulta_contraparte</span></dd>
    </dl>
    ${conflicto}
    ${d.citas.length ? `<h2 style="margin-top:16px">Citas</h2><table class="tabla mini"><tr><th>N.°</th><th>Fecha</th><th>Abogado</th><th>Modalidad</th><th>Estado</th></tr>
      ${d.citas.map((x) => `<tr><td>${x.idCita}</td><td>${esc(x.fechaHora)}</td><td>${esc(x.abogado)}</td><td>${esc(x.modalidad)}</td><td>${estado(x.estado)}</td></tr>`).join("")}</table>` : ""}
    ${d.notificaciones.length ? `<h2 style="margin-top:16px">Notificaciones generadas <span class="bd">notificacion</span></h2><table class="tabla mini"><tr><th>N.°</th><th>Para</th><th>Evento</th><th>Canal</th><th>Programada</th><th>Estado</th></tr>
      ${d.notificaciones.map((n) => `<tr title="${esc(n.mensaje)}"><td>${n.idNotificacion}</td><td>${esc(n.destinatario)}</td><td>${esc(n.tipoEvento)}</td><td>${esc(n.canal)}</td><td>${esc(n.fechaProgramada)}</td><td>${estado(n.estado)}</td></tr>`).join("")}</table>` : ""}`;

  const agendable = (c.estado === "RECIBIDA" || c.estado === "NO_ATENDIDA") && d.existeConflicto !== true;
  $("form-cita").hidden = !agendable;
  $("detalle").scrollIntoView({ behavior: "smooth", block: "start" });
  $("alerta-cita").className = "alerta";
  if (agendable) {
    const abogados = await api("../api/panel/abogados?materia=" + c.idMateria);
    $("abogado").innerHTML = abogados.map((a) => `<option value="${a.idEmpleado}">${esc(a.nombre)} · ${esc(a.colegiatura)}${a.esPrincipal ? " (principal)" : ""}</option>`).join("")
      || '<option value="">Ningún abogado atiende esta materia</option>';
    cargarHoras();
  }
}

// ---------- W06 · Disponibilidad y horas
async function cargarHoras() {
  horaElegida = null;
  const ab = $("abogado").value, f = $("fecha").value;
  if (!ab || !f) { $("horas").innerHTML = ""; return; }
  const disp = await api(`../api/panel/disponibilidad?abogado=${ab}&fecha=${f}`);
  let bloqueado = false;
  if (disp.feriado) { $("info-dia").textContent = "· Feriado: " + disp.feriado; bloqueado = true; }
  else if (disp.domingo) { $("info-dia").textContent = "· Domingo: el estudio no atiende"; bloqueado = true; }
  else $("info-dia").textContent = disp.ocupadas.length ? `· ${disp.ocupadas.length} hora(s) ocupada(s)` : "· todas las horas libres";
  const ahora = new Date();
  $("horas").innerHTML = disp.horas.map((h) => {
    const pasada = new Date(`${f}T${h}:00`) <= ahora;
    const ocupada = disp.ocupadas.includes(h);
    return `<button type="button" data-h="${h}" ${bloqueado || ocupada || pasada ? "disabled" : ""}>${h}</button>`;
  }).join("");
  document.querySelectorAll("#horas button:not(:disabled)").forEach((b) => b.addEventListener("click", () => {
    document.querySelectorAll("#horas button").forEach((x) => x.classList.remove("sel"));
    b.classList.add("sel"); horaElegida = b.dataset.h;
  }));
}
$("abogado").addEventListener("change", cargarHoras);
$("fecha").addEventListener("change", cargarHoras);

$("form-cita").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("alerta-cita");
  if (!$("abogado").value) { a.className = "alerta mal"; a.textContent = "No hay abogado para esta materia."; return; }
  if (!horaElegida) { a.className = "alerta mal"; a.textContent = "Elija una hora disponible."; return; }
  const b = $("btn-cita"); b.disabled = true; b.textContent = "Agendando…";
  try {
    const r = await api("../api/panel/citas", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idConsulta: actual.consulta.idConsulta, idAbogado: Number($("abogado").value), fecha: $("fecha").value,
        hora: horaElegida, modalidad: document.querySelector('input[name="modalidad"]:checked').value }) });
    const id = actual.consulta.idConsulta;
    await cargarBandeja();
    await abrirConsulta(id);
    $("detalle").insertAdjacentHTML("afterbegin", `<div class="aviso verde" style="margin:0 0 10px">✔ ${esc(r.mensaje)} Después de la cita, el abogado envía su <a href="propuesta.html" style="font-weight:700;text-decoration:underline">propuesta de honorarios</a>.</div><div class="traza bd-traza" style="margin-top:0">
      <div>COMMIT ✔ Transacción registrada en SQL Server</div>
      <div><b>CITA</b> id_cita = ${r.idCita} · ${esc(r.fechaHora)} · PROGRAMADA</div>
      <div><b>CONSULTA</b> N.° ${id} → estado AGENDADA</div>
      <div><b>NOTIFICACION</b> ${r.idNotificacionCliente} (cliente) y ${r.idNotificacionAbogado} (abogado) · RECORDATORIO_CITA</div></div>`);
  } catch (err) {
    a.className = "alerta mal"; a.textContent = err.message;
  } finally {
    b.disabled = false; b.textContent = "Agendar cita y notificar";
  }
});

// ---------- Agenda
async function cargarAgenda() {
  const citas = await api("../api/panel/citas");
  $("agenda-filas").innerHTML = citas.length ? citas.map((c) => `<tr><td>${c.idCita}</td><td>${esc(c.fechaHora)}</td><td>${esc(c.cliente)}</td>
    <td>${esc(c.abogado)}</td><td>${esc(c.modalidad)}</td><td>${estado(c.estado)}</td><td>${c.idConsulta}</td></tr>`).join("")
    : '<tr><td colspan="7" class="vacio">No hay citas desde hoy.</td></tr>';
}


iniciar().catch(() => {});
