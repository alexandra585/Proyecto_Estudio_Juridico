// =====================================================================
// W08 · Contrato y cronograma de cuotas
//   Paso 1: el cliente acepta la propuesta  → UPDATE PROPUESTA
//   Paso 2: contrato + cuotas + consulta     → TRANSACCIÓN (POST api/panel/t2/contratos)
//   Paso 3: últimos contratos                → lectura
// =====================================================================
const $ = (id) => document.getElementById(id);
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const soles = (n) => "S/ " + Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const estado = (e) => `<span class="estado e-${esc(e)}">${esc(e)}</span>`;
const hoy = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; };
function sumarMeses(iso, n) {
  const [a, m, d] = iso.split("-").map(Number);
  const f = new Date(a, m - 1 + n, 1);
  const ultimo = new Date(f.getFullYear(), f.getMonth() + 1, 0).getDate();
  f.setDate(Math.min(d, ultimo));
  return `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, "0")}-${String(f.getDate()).padStart(2, "0")}`;
}

let propuestas = [];      // aceptadas sin contrato
let actual = null;        // propuesta elegida

async function api(url, opciones) {
  const r = await fetch(url, opciones);
  if (r.status === 401) { location.href = "login.html"; throw new Error("Sesión vencida"); }
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.error || "Error " + r.status);
  return d;
}

// ---------------- Paso 1 · propuestas por responder
async function cargarPorResponder() {
  const t = $("por-responder");
  try {
    const filas = await api("../api/panel/t2/propuestas-por-responder");
    t.innerHTML = filas.length ? filas.map((p) => `<tr>
        <td><b>${p.id_propuesta}</b> <small>v${p.version}</small></td><td>${esc(p.cliente)}</td><td>${esc(p.materia)}</td><td>${esc(p.abogado)}</td>
        <td>${soles(p.monto_honorarios)}</td><td>${p.nro_cuotas}</td><td>${esc(p.fecha_envio)}</td><td>${estado(p.estado)}</td>
        <td><button class="btn btn-sec" type="button" data-aceptar="${p.id_propuesta}" style="padding:6px 10px">Aceptó ✓</button></td></tr>`).join("")
      : '<tr><td colspan="9" class="vacio">No hay propuestas esperando respuesta.</td></tr>';
    t.querySelectorAll("[data-aceptar]").forEach((b) => b.addEventListener("click", () => aceptar(Number(b.dataset.aceptar), b)));
  } catch (e) { t.innerHTML = `<tr><td colspan="9" class="vacio" style="color:var(--rojo)">${esc(e.message)}</td></tr>`; }
}

async function aceptar(id, boton) {
  boton.disabled = true; boton.textContent = "…";
  try {
    await api(`../api/panel/t2/propuestas/${id}/aceptar`, { method: "POST" });
    await Promise.all([cargarPorResponder(), cargarPropuestas()]);
    $("propuesta").value = String(id);
    elegirPropuesta();
    $("form-contrato").scrollIntoView({ behavior: "smooth", block: "start" });
  } catch (e) { boton.disabled = false; boton.textContent = "Aceptó ✓";
    $("alerta").className = "alerta mal"; $("alerta").textContent = e.message; }
}

// ---------------- Paso 2 · combos
async function cargarPropuestas() {
  propuestas = await api("../api/panel/t2/propuestas-aceptadas");
  $("propuesta").innerHTML = '<option value="">— Elija una propuesta aceptada —</option>' + propuestas.map((p) =>
    `<option value="${p.id_propuesta}">Propuesta ${p.id_propuesta} v${p.version} · ${esc(p.cliente)} · ${soles(p.monto_honorarios)}</option>`).join("");
  if (!propuestas.length) $("propuesta").innerHTML = '<option value="">No hay propuestas aceptadas sin contrato</option>';
}

async function cargarClientes() {
  const cs = await api("../api/panel/t2/clientes");
  $("cliente").innerHTML = cs.map((c) =>
    `<option value="${c.id_persona}">${esc(c.nombre)} · ${esc(c.documento)}${c.sin_documento ? "  ⚠" : ""}</option>`).join("");
}

async function elegirPropuesta() {
  actual = propuestas.find((p) => String(p.id_propuesta) === $("propuesta").value) || null;
  $("resumen-propuesta").hidden = !actual;
  $("resultado").innerHTML = "";
  $("alerta").className = "alerta";
  if (!actual) { $("cuotas").innerHTML = ""; pintarSuma(); return; }
  $("r-consulta").textContent = `N.° ${actual.id_consulta} · ${actual.cliente} (${actual.documento})`;
  $("r-materia").textContent = `${actual.materia} · ${actual.abogado}`;
  $("r-honorarios").textContent = soles(actual.monto_honorarios);
  $("r-cuotas").textContent = actual.nro_cuotas;
  $("r-litis").textContent = Number(actual.porcentaje_cuota_litis) > 0 ? actual.porcentaje_cuota_litis + " % del monto que se obtenga" : "No pactada";
  $("cliente").value = String(actual.id_cliente);       // por defecto firma quien hizo la consulta
  $("nro").value = (await api("../api/panel/t2/siguiente-nro-contrato")).nroContrato;

  const proBono = Number(actual.monto_honorarios) === 0;
  $("zona-cronograma").hidden = proBono;
  $("aviso-probono").hidden = !proBono;
  if (proBono) { $("tipo").value = "PRO_BONO"; $("modalidad").value = "UNICO"; $("cuotas").innerHTML = ""; }
  else {
    if ($("tipo").value === "PRO_BONO") $("tipo").value = "PATROCINIO";
    $("modalidad").value = Number(actual.nro_cuotas) > 1 ? "CUOTAS" : "UNICO";
    $("g-n").value = actual.nro_cuotas;
    $("g-inicio").value = $("firma").value;
    generar();
  }
  pintarSuma();
}

// ---------------- Cronograma (detalle)
function filaCuota(n, concepto, monto, fecha) {
  const tr = document.createElement("tr");
  tr.innerHTML = `<td class="nro">${n}</td>
    <td><select class="q-concepto">${["ADELANTO", "CUOTA", "IGUALA", "SALDO"].map((c) => `<option ${c === concepto ? "selected" : ""}>${c}</option>`).join("")}</select></td>
    <td><input class="q-monto" type="number" min="0.01" step="0.01" value="${monto}"></td>
    <td><input class="q-fecha" type="date" value="${fecha}"></td>
    <td><button type="button" class="quitar" title="Quitar">×</button></td>`;
  tr.querySelector(".quitar").addEventListener("click", () => { tr.remove(); renumerar(); });
  tr.querySelectorAll("input,select").forEach((x) => x.addEventListener("input", pintarSuma));
  return tr;
}
function renumerar() { [...$("cuotas").rows].forEach((tr, i) => { tr.querySelector(".nro").textContent = i + 1; }); pintarSuma(); }

function generar() {
  if (!actual) return;
  const n = Math.max(1, Math.min(24, Number($("g-n").value) || 1));
  const total = Math.round(Number(actual.monto_honorarios) * 100);
  const base = Math.floor(total / n);
  const inicio = $("g-inicio").value || $("firma").value;
  const iguala = $("modalidad").value === "IGUALA_MENSUAL";
  $("cuotas").innerHTML = "";
  for (let i = 0; i < n; i++) {
    const centimos = i === n - 1 ? total - base * (n - 1) : base;        // la última absorbe el redondeo
    const concepto = iguala ? "IGUALA" : (i === 0 && $("g-adelanto").checked && n > 1 ? "ADELANTO" : "CUOTA");
    $("cuotas").appendChild(filaCuota(i + 1, concepto, (centimos / 100).toFixed(2), sumarMeses(inicio, i)));
  }
  pintarSuma();
}

function leerCuotas() {
  return [...$("cuotas").rows].map((tr, i) => ({
    nroCuota: i + 1,
    concepto: tr.querySelector(".q-concepto").value,
    monto: tr.querySelector(".q-monto").value,
    fechaVencimiento: tr.querySelector(".q-fecha").value,
  }));
}

function pintarSuma() {
  const s = $("suma");
  if (!actual || Number(actual.monto_honorarios) === 0) { s.className = "suma"; s.textContent = ""; return true; }
  const suma = leerCuotas().reduce((a, q) => a + Math.round(Number(q.monto || 0) * 100), 0);
  const meta = Math.round(Number(actual.monto_honorarios) * 100);
  const ok = suma === meta;
  s.className = "suma " + (ok ? "ok" : "mal");
  s.innerHTML = `Suma de cuotas ${soles(suma / 100)} · honorarios aceptados ${soles(meta / 100)} ${ok ? "✓ cuadra" : "✗ deben ser iguales"}`
    + ' <span class="bd">Σ cuota.monto = propuesta.monto_honorarios</span>';
  return ok;
}

// ---------------- Grabar (TRANSACCIÓN)
$("form-contrato").addEventListener("submit", async (e) => {
  e.preventDefault();
  const a = $("alerta"); a.className = "alerta";
  if (!actual) { a.className = "alerta mal"; a.textContent = "Elija una propuesta aceptada."; return; }
  if (!$("nro").value.trim() || !$("firma").value) { a.className = "alerta mal"; a.textContent = "Complete el número y la fecha de firma."; return; }
  const proBono = Number(actual.monto_honorarios) === 0;
  if (!proBono && !pintarSuma()) { a.className = "alerta mal"; a.textContent = "La suma de las cuotas debe ser igual a los honorarios aceptados."; return; }

  const datos = {
    idPropuesta: actual.id_propuesta, idCliente: Number($("cliente").value), nroContrato: $("nro").value.trim(),
    fechaFirma: $("firma").value, tipoEncargo: $("tipo").value, modalidadPago: $("modalidad").value,
    conCartaPoder: $("carta").checked, cuotas: proBono ? [] : leerCuotas(),
  };
  const b = $("btn-grabar"); b.disabled = true; b.textContent = "Grabando…";
  try {
    const r = await api("../api/panel/t2/contratos", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(datos) });
    $("resultado").innerHTML = `
      <div class="aviso verde">✔ ${esc(r.mensaje)} La consulta N.° ${r.idConsulta} quedó como CONTRATADA.</div>
      <div class="traza bd-traza">
        <div>COMMIT ✔ Transacción W08 registrada en SQL Server:</div>
        <div><b>CONTRATO</b> id_contrato = ${r.idContrato} · nro_contrato = ${esc(r.nroContrato)} · id_propuesta = ${datos.idPropuesta} · id_cliente = ${datos.idCliente}</div>
        <div><b>CUOTA</b> ${r.idsCuota.length ? "id_cuota = " + r.idsCuota.join(", ") + " · estado PENDIENTE" : "sin cuotas (pro bono)"}</div>
        <div><b>CONSULTA</b> N.° ${r.idConsulta} → estado CONTRATADA</div>
      </div>
      ${r.cuotas.length ? `<table class="tabla mini" style="margin-top:6px"><thead><tr><th>id_cuota</th><th>N.°</th><th>Concepto</th><th>Monto</th><th>Vence</th><th>Estado</th></tr></thead><tbody>
        ${r.cuotas.map((q) => `<tr><td>${q.id_cuota}</td><td>${q.nro_cuota}</td><td>${esc(q.concepto)}</td><td>${soles(q.monto)}</td><td>${esc(q.fecha_vencimiento)}</td><td>${estado(q.estado)}</td></tr>`).join("")}
        </tbody></table><div class="bd">leído de la vista vw_cuota_estado (VENCIDA se calcula, no se guarda)</div>` : ""}`;
    await Promise.all([cargarPropuestas(), cargarContratos()]);
    actual = null; $("resumen-propuesta").hidden = true; $("cuotas").innerHTML = ""; pintarSuma();
  } catch (err) {
    a.className = "alerta mal";
    a.innerHTML = `${esc(err.message)}<div class="bd" style="display:block">ROLLBACK: no se grabó ni el contrato, ni las cuotas, ni el cambio de estado.</div>`;
  } finally { b.disabled = false; b.textContent = "Registrar contrato y cronograma"; }
});

// ---------------- Paso 3 · contratos
async function cargarContratos() {
  const t = $("contratos");
  try {
    const filas = await api("../api/panel/t2/contratos");
    t.innerHTML = filas.length ? filas.map((k) => `<tr><td><b>${k.id_contrato}</b></td><td>${esc(k.nro_contrato)}</td><td>${esc(k.fecha_firma)}</td>
      <td>${esc(k.cliente)}</td><td>${esc(k.tipo_encargo)}</td><td>${esc(k.modalidad_pago)}</td><td>${k.nro_cuotas}</td><td>${soles(k.total_cuotas)}</td>
      <td>N.° ${k.id_consulta} ${estado(k.estado_consulta)}</td></tr>`).join("") : '<tr><td colspan="9" class="vacio">Sin contratos.</td></tr>';
  } catch (e) { t.innerHTML = `<tr><td colspan="9" class="vacio" style="color:var(--rojo)">${esc(e.message)}</td></tr>`; }
}

// ---------------- Eventos e inicio
$("propuesta").addEventListener("change", elegirPropuesta);
$("generar").addEventListener("click", generar);
$("modalidad").addEventListener("change", () => { if (actual && Number(actual.monto_honorarios) > 0) generar(); });
$("agregar").addEventListener("click", () => {
  const n = $("cuotas").rows.length;
  const ultima = n ? $("cuotas").rows[n - 1].querySelector(".q-fecha").value : $("firma").value;
  $("cuotas").appendChild(filaCuota(n + 1, "CUOTA", "", n ? sumarMeses(ultima, 1) : ultima));
  pintarSuma();
});
$("firma").value = hoy();
$("firma").max = hoy();
$("g-inicio").value = hoy();

cargarPorResponder();
Promise.all([cargarPropuestas(), cargarClientes()]).catch((e) => { $("alerta").className = "alerta mal"; $("alerta").textContent = e.message; });
cargarContratos();
