// =====================================================================
// W03 · Dashboard gerencial: GET /api/panel/dashboard?desde=&hasta= (funciones fn_dash_* de SQL Server)
// =====================================================================
const $ = (id) => document.getElementById(id);
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const soles = (n) => "S/ " + Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const solesCorto = (n) => "S/ " + Number(n || 0).toLocaleString("es-PE", { maximumFractionDigits: 0 });
const NAVY = "#1F3864", GOLD = "#B8902F", VERDE = "#2E7D32", ROJO = "#C62828", AZUL = "#1565C0";
const graficos = {};

Chart.defaults.font.family = "Inter, 'Segoe UI', Arial, sans-serif";
Chart.defaults.color = "#5B6575";

function grafico(id, config) {
  if (graficos[id]) graficos[id].destroy();
  graficos[id] = new Chart($(id), config);
}

// ---------------- Filtro por periodo
const iso = (f) => `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, "0")}-${String(f.getDate()).padStart(2, "0")}`;
const dmy = (s) => s.split("-").reverse().join("/");
function rango(clave) {
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0);
  let d = new Date(hoy);
  switch (clave) {
    case "hoy": break;
    case "semana": d.setDate(hoy.getDate() - ((hoy.getDay() + 6) % 7)); break;          // lunes de esta semana
    case "mes": d = new Date(hoy.getFullYear(), hoy.getMonth(), 1); break;
    case "trimestre": d = new Date(hoy.getFullYear(), Math.floor(hoy.getMonth() / 3) * 3, 1); break;
    case "anio": d = new Date(hoy.getFullYear(), 0, 1); break;
    case "12m": d = new Date(hoy.getFullYear(), hoy.getMonth() - 11, 1); break;
    case "todo": d = new Date(2000, 0, 1); break;
  }
  return { desde: iso(d), hasta: iso(hoy) };
}
function elegirRapido(clave) {
  const r = rango(clave);
  $("f-desde").value = r.desde; $("f-hasta").value = r.hasta;
  document.querySelectorAll("#rapidos button").forEach((b) => b.classList.toggle("activo", b.dataset.rango === clave));
  try { localStorage.setItem("mm-dash-rango", clave); } catch (e) { /* sin almacenamiento */ }
  cargar();
}
document.querySelectorAll("#rapidos button").forEach((b) => b.addEventListener("click", () => elegirRapido(b.dataset.rango)));
$("aplicar").addEventListener("click", () => {
  document.querySelectorAll("#rapidos button").forEach((b) => b.classList.remove("activo"));
  cargar();
});

async function cargar() {
  const desde = $("f-desde").value, hasta = $("f-hasta").value;
  if (desde && hasta && desde > hasta) { $("error").className = "alerta mal"; $("error").textContent = "«Desde» no puede ser posterior a «Hasta»."; return; }
  try {
    const r = await fetch(`../api/panel/dashboard?desde=${desde}&hasta=${hasta}`);
    if (r.status === 401) { location.href = "login.html"; return; }
    const d = await r.json();
    if (!r.ok) throw new Error(d.error || "Error " + r.status);
    $("error").className = "alerta";
    $("periodo-txt").textContent = `Periodo: ${dmy(d.desde)} – ${dmy(d.hasta)}`;
    pintar(d);
    $("actualizado").textContent = "· Actualizado " + new Date().toLocaleTimeString("es-PE");
  } catch (e) {
    $("error").className = "alerta mal";
    $("error").textContent = "No se pudo cargar el dashboard: " + e.message
      + " (¿ejecutó 1_SQL_Server/magallanes_montero_dashboard_filtros.sql?)";
  }
}

function pintar(d) {
  const k = d.resumen;
  $("k-ingresos").textContent = soles(k.ingresos_cobrados);
  $("k-ganancia").textContent = soles(k.ganancia_neta);
  $("k-margen").textContent = "Margen " + (k.ingresos_cobrados ? (100 * k.ganancia_neta / k.ingresos_cobrados).toFixed(1) : "0") + " %";
  $("k-gastos").textContent = soles(k.gastos_casos);
  $("k-porcobrar").textContent = soles(k.por_cobrar);
  $("k-litis").textContent = soles(k.cuota_litis);
  $("k-contratados").textContent = soles(k.honorarios_contratados);
  $("k-facturado").textContent = "Facturado sin IGV: " + soles(k.facturado_sin_igv);
  $("a-casos").textContent = k.casos_activos;
  $("a-plazos").textContent = k.plazos_por_vencer;
  $("a-cuotas").textContent = k.cuotas_vencidas;
  $("a-cuotas-monto").textContent = soles(k.monto_cuotas_vencidas) + " · vw_cuota_estado";
  $("a-aud").textContent = k.audiencias_7_dias;

  const meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "set", "oct", "nov", "dic"];
  const gran = d.cobranza.length ? d.cobranza[0].granularidad : "MES";
  $("t-gran").textContent = { DIA: "por día", SEMANA: "por semana", MES: "por mes" }[gran];
  const etiqueta = (c) => gran === "MES" ? meses[Number(c.periodo.slice(5, 7)) - 1] + " " + c.periodo.slice(2, 4)
    : gran === "SEMANA" ? "sem. " + c.periodo.slice(8, 10) + "/" + c.periodo.slice(5, 7)
    : c.periodo.slice(8, 10) + "/" + c.periodo.slice(5, 7);
  grafico("g-mensual", { type: "bar",
    data: { labels: d.cobranza.map(etiqueta),
      datasets: [{ label: "Cobrado sin IGV", data: d.cobranza.map((m) => m.cobrado_sin_igv), backgroundColor: NAVY, borderRadius: 6 }] },
    options: { maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: (c) => soles(c.raw) } } },
      scales: { y: { beginAtZero: true, ticks: { callback: (v) => solesCorto(v) } } } } });
  if (!d.cobranza.length) $("t-gran").textContent += " · sin pagos en el periodo";

  grafico("g-materia", { type: "bar",
    data: { labels: d.materias.map((m) => m.materia),
      datasets: [{ label: "Ingresos", data: d.materias.map((m) => m.ingresos), backgroundColor: GOLD, borderRadius: 4 },
                 { label: "Gastos", data: d.materias.map((m) => m.gastos), backgroundColor: ROJO, borderRadius: 4 },
                 { label: "Ganancia", data: d.materias.map((m) => m.ganancia), backgroundColor: VERDE, borderRadius: 4 }] },
    options: { indexAxis: "y", maintainAspectRatio: false, plugins: { tooltip: { callbacks: { label: (c) => c.dataset.label + ": " + soles(c.raw) } } },
      scales: { x: { ticks: { callback: (v) => solesCorto(v) } } } } });

  grafico("g-abogado", { type: "bar",
    data: { labels: d.abogados.map((a) => a.abogado.split(" ").slice(0, 1).concat(a.abogado.split(" ").slice(-2, -1)).join(" ")),
      datasets: [{ label: "Ganancia", data: d.abogados.map((a) => a.ganancia), backgroundColor: VERDE, borderRadius: 6, yAxisID: "y" },
                 { label: "Casos activos", data: d.abogados.map((a) => a.casos_activos), type: "line", borderColor: GOLD, backgroundColor: GOLD, yAxisID: "y2" }] },
    options: { maintainAspectRatio: false, scales: { y: { ticks: { callback: (v) => solesCorto(v) } },
      y2: { position: "right", grid: { display: false }, ticks: { stepSize: 1 }, title: { display: true, text: "casos" } } } } });
  $("t-abogados").innerHTML = d.abogados.map((a) => `<tr><td>${esc(a.abogado)}</td><td>${soles(a.ganancia)}</td><td>${a.casos_activos}</td><td>${a.plazos_pendientes}</td><td>${a.audiencias_proximas}</td></tr>`).join("");

  const base = d.embudo.length ? d.embudo[0].cantidad : 0;
  grafico("g-embudo", { type: "bar",
    data: { labels: d.embudo.map((e) => e.etapa + (base ? ` (${Math.round(100 * e.cantidad / base)} %)` : "")),
      datasets: [{ label: "Consultas", data: d.embudo.map((e) => e.cantidad), backgroundColor: [NAVY, "#2C4A7C", GOLD, VERDE], borderRadius: 6 }] },
    options: { indexAxis: "y", maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { x: { ticks: { stepSize: 1 } } } } });

  grafico("g-canal", { type: "bar",
    data: { labels: d.canales.map((c) => c.canal),
      datasets: [{ label: "Consultas", data: d.canales.map((c) => c.consultas), backgroundColor: NAVY, borderRadius: 4 },
                 { label: "Contratadas", data: d.canales.map((c) => c.contratadas), backgroundColor: GOLD, borderRadius: 4 }] },
    options: { maintainAspectRatio: false, scales: { y: { ticks: { stepSize: 1 } } } } });

  $("t-plazos").innerHTML = d.plazos.length ? d.plazos.map((p) => `<tr><td>${esc(p.codigo_interno)}</td><td>${esc(p.descripcion)}</td><td>${esc(p.vence)}</td>
      <td class="${p.dias_restantes < 0 ? "dias-neg" : "dias-ok"}">${p.dias_restantes < 0 ? "vencido " + (-p.dias_restantes) + " d" : p.dias_restantes + " d"}</td><td>${esc(p.responsable)}</td></tr>`).join("")
    : '<tr><td colspan="5" class="vacio">Sin plazos por vencer.</td></tr>';
  $("t-cuotas").innerHTML = d.cuotasVencidas.length ? d.cuotasVencidas.map((q) => `<tr><td>${esc(q.nro_contrato)}</td><td>${esc(q.cliente)}</td><td>${esc(q.concepto)}</td><td>${soles(q.monto)}</td><td>${esc(q.vence)}</td></tr>`).join("")
    : '<tr><td colspan="5" class="vacio">Sin cuotas vencidas.</td></tr>';

  const s = d.satisfaccion;
  $("s-prom").textContent = s.calificacion_promedio != null ? Number(s.calificacion_promedio).toFixed(1) + " / 5" : "—";
  $("s-nps").textContent = s.nps != null ? Number(s.nps).toFixed(0) : "—";
  $("s-resp").textContent = `${s.respondidas || 0} de ${s.encuestas_enviadas || 0} encuestas respondidas`;
}

$("refrescar").addEventListener("click", cargar);
let inicial = "anio";
try { inicial = localStorage.getItem("mm-dash-rango") || "anio"; } catch (e) { /* sin almacenamiento */ }
elegirRapido(inicial);
