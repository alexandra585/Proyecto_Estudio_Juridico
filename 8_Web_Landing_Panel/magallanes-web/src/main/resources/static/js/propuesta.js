// =====================================================================
// W07 · Propuesta de honorarios
//   Paso 1: consultas con cita            → lectura
//   Paso 2: enviar propuesta              → TRANSACCIÓN (POST api/panel/t2/propuestas)
//   Paso 3: últimas propuestas            → lectura
// =====================================================================
const $ = (id) => document.getElementById(id);
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const soles = (n) => "S/ " + Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const estado = (e) => `<span class="estado e-${esc(e)}">${esc(e)}</span>`;

let consultas = [];
let actual = null;

async function api(url, opciones) {
  const r = await fetch(url, opciones);
  if (r.status === 401) { location.href = "login.html"; throw new Error("Sesión vencida"); }
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.error || "Error " + r.status);
  return d;
}

// ---------------- Paso 1
async function cargarConsultas() {
  const t = $("consultas");
  try {
    consultas = await api("../api/panel/t2/consultas-para-propuesta");
    t.innerHTML = consultas.length ? consultas.map((c) => `<tr data-id="${c.id_consulta}" class="${actual && actual.id_consulta === c.id_consulta ? "sel" : ""}">
        <td><b>${c.id_consulta}</b></td><td>${esc(c.cliente)}</td><td>${esc(c.documento)}</td><td>${esc(c.materia)}</td>
        <td>${c.canal === "LANDING" ? '<span class="landing-tag">LANDING</span>' : esc(c.canal)}</td><td>${esc(c.cita || "—")}</td>
        <td>${estado(c.estado)}</td><td>${c.ultima_version ? "v" + c.ultima_version : "—"}</td></tr>`).join("")
      : '<tr><td colspan="8" class="vacio">No hay consultas con cita. Primero agende una cita en «Consultas y citas».</td></tr>';
    t.querySelectorAll("tr[data-id]").forEach((tr) => tr.addEventListener("click", () => elegir(Number(tr.dataset.id))));
  } catch (e) { t.innerHTML = `<tr><td colspan="8" class="vacio" style="color:var(--rojo)">${esc(e.message)}</td></tr>`; }
}

async function elegir(id) {
  actual = consultas.find((c) => c.id_consulta === id);
  document.querySelectorAll("#consultas tr").forEach((tr) => tr.classList.toggle("sel", Number(tr.dataset.id) === id));
  $("resultado").innerHTML = "";
  $("alerta").className = "alerta";
  $("form-propuesta").hidden = false;
  $("p-consulta").textContent = actual.id_consulta;
  $("p-cliente").textContent = `${actual.cliente} · ${actual.documento}`;
  $("p-materia").textContent = actual.materia;
  $("p-resumen").textContent = actual.resumen || "—";
  const v = (actual.ultima_version || 0) + 1;
  $("p-version").textContent = "Versión " + v;
  $("p-aviso-version").hidden = !actual.ultima_version;
  const abogados = await api("../api/panel/abogados?materia=" + actual.id_materia);
  $("abogado").innerHTML = abogados.map((a) => `<option value="${a.idEmpleado}">${esc(a.nombre)}${a.esPrincipal ? " (principal)" : ""}</option>`).join("")
    || '<option value="">Ningún abogado atiende esta materia</option>';
  if (actual.id_abogado_cita && abogados.some((a) => a.idEmpleado === actual.id_abogado_cita)) $("abogado").value = String(actual.id_abogado_cita);
  resumenPago();
  $("form-propuesta").scrollIntoView({ behavior: "smooth", block: "start" });
}

function resumenPago() {
  const h = Number($("honorarios").value || 0), n = Math.max(1, Number($("cuotas").value || 1)), l = Number($("litis").value || 0);
  $("p-resumen-pago").textContent = h === 0 ? "Pro bono: el estudio no cobra honorarios."
    : `${n} cuota(s) de aprox. ${soles(h / n)}${l > 0 ? ` + ${l} % de lo que se obtenga al ganar el caso` : ""}.`;
}
["honorarios", "cuotas", "litis"].forEach((i) => $(i).addEventListener("input", resumenPago));

// ---------------- Paso 2 · TRANSACCIÓN
$("form-propuesta").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("alerta"); a.className = "alerta";
  if (!actual) return;
  if (!$("abogado").value) { a.className = "alerta mal"; a.textContent = "No hay abogado para esta materia."; return; }
  if ($("honorarios").value === "") { a.className = "alerta mal"; a.textContent = "Escriba los honorarios (0 si es pro bono)."; return; }
  const datos = { idConsulta: actual.id_consulta, idAbogado: Number($("abogado").value), montoHonorarios: $("honorarios").value,
    porcentajeCuotaLitis: $("litis").value || "0", nroCuotas: $("cuotas").value };
  const b = $("btn-grabar"); b.disabled = true; b.textContent = "Enviando…";
  try {
    const r = await api("../api/panel/t2/propuestas", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(datos) });
    $("form-propuesta").hidden = true;
    $("resultado").innerHTML = `<div class="tarjeta">
      <div class="aviso verde" style="margin-top:0">✔ ${esc(r.mensaje)} Cuando el cliente acepte, regístrelo en
        <a href="contrato.html" style="font-weight:700;text-decoration:underline">Contratos y cuotas</a>.</div>
      <div class="traza bd-traza">
        <div>COMMIT ✔ Transacción W07 registrada en SQL Server:</div>
        ${r.anterioresEnNegociacion ? `<div><b>PROPUESTA</b> versión anterior → EN_NEGOCIACION (${r.anterioresEnNegociacion} fila)</div>` : ""}
        <div><b>PROPUESTA</b> id_propuesta = ${r.idPropuesta} · version = ${r.version} · ${soles(datos.montoHonorarios)} · ${datos.nroCuotas} cuota(s) · ENVIADA</div>
        <div><b>CONSULTA</b> N.° ${r.idConsulta} → estado PROPUESTA</div>
      </div></div>`;
    actual = null;
    await Promise.all([cargarConsultas(), cargarPropuestas()]);
  } catch (err) {
    a.className = "alerta mal";
    a.innerHTML = `${esc(err.message)}<div class="bd" style="display:block">ROLLBACK: no se grabó la propuesta ni el cambio de estado.</div>`;
  } finally { b.disabled = false; b.textContent = "Enviar propuesta al cliente"; }
});

// ---------------- Paso 3
async function cargarPropuestas() {
  const t = $("propuestas");
  try {
    const f = await api("../api/panel/t2/propuestas");
    t.innerHTML = f.length ? f.map((p) => `<tr><td><b>${p.id_propuesta}</b></td><td>N.° ${p.id_consulta}</td><td>v${p.version}</td><td>${esc(p.cliente)}</td>
      <td>${esc(p.abogado)}</td><td>${soles(p.monto_honorarios)}</td><td>${p.nro_cuotas}</td><td>${Number(p.porcentaje_cuota_litis)} %</td>
      <td>${esc(p.fecha_envio)}</td><td>${estado(p.estado)}</td></tr>`).join("") : '<tr><td colspan="10" class="vacio">Sin propuestas.</td></tr>';
  } catch (e) { t.innerHTML = `<tr><td colspan="10" class="vacio" style="color:var(--rojo)">${esc(e.message)}</td></tr>`; }
}

cargarConsultas();
cargarPropuestas();
