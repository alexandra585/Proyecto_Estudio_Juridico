// =====================================================================
// Utilidades comunes de las pantallas del panel (W09, T3 y T4)
// =====================================================================
const $ = (id) => document.getElementById(id);
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const soles = (n) => "S/ " + Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const estado = (e) => `<span class="estado e-${esc(e)}">${esc(e)}</span>`;
const hoyISO = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; };

async function api(url, opciones) {
  const r = await fetch(url, opciones);
  if (r.status === 401) { location.href = "login.html"; throw new Error("Sesión vencida"); }
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.error || "Error " + r.status);
  return d;
}
const postJSON = (url, datos) => api(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(datos ?? {}) });

/** Llena un <select> con filas. */
function opciones(sel, filas, valor, texto, vacio) {
  sel.innerHTML = (vacio ? `<option value="">${esc(vacio)}</option>` : "") + filas.map((f) => `<option value="${esc(f[valor])}">${esc(texto(f))}</option>`).join("");
}

/** Tabla simple: columnas [{t: título, f: (fila) => html}] */
function tabla(tbody, filas, columnas, vacio) {
  tbody.innerHTML = filas.length ? filas.map((f) => "<tr>" + columnas.map((c) => `<td>${c.f(f)}</td>`).join("") + "</tr>").join("")
    : `<tr><td colspan="${columnas.length}" class="vacio">${esc(vacio || "Sin registros.")}</td></tr>`;
}

/** Muestra el error de una transacción (ROLLBACK) en un div .alerta */
function mostrarError(div, err) {
  div.className = "alerta mal";
  div.innerHTML = `${esc(err.message)}<div class="bd" style="display:block">ROLLBACK: SQL Server deshizo todo lo de esta operación y, si se había creado un documento en MongoDB, se borró (compensación).</div>`;
}

/** Indicador del estado de MongoDB en la cabecera de la pantalla. */
async function estadoMongo(el) {
  try {
    const m = await api("../api/panel/mongo/estado");
    el.innerHTML = m.disponible ? '<span class="mongo-ok">● MongoDB conectado</span>' : '<span class="mongo-off">● MongoDB apagado (se graba solo en SQL Server)</span>';
  } catch (e) { el.textContent = ""; }
}

/** Ventana con el documento JSON tal como está guardado en MongoDB. */
async function verMongo(url) {
  let caja = $("modal-mongo");
  if (!caja) {
    caja = document.createElement("div");
    caja.id = "modal-mongo"; caja.className = "modal";
    caja.innerHTML = '<div class="modal-caja"><div class="modal-cab"><b id="mm-tit">MongoDB</b><button type="button" id="mm-cerrar">✕</button></div><pre id="mm-json"></pre></div>';
    document.body.appendChild(caja);
    $("mm-cerrar").addEventListener("click", () => caja.hidden = true);
    caja.addEventListener("click", (e) => { if (e.target === caja) caja.hidden = true; });
  }
  caja.hidden = false;
  $("mm-tit").textContent = "MongoDB · cargando…"; $("mm-json").textContent = "";
  try {
    const d = await api(url);
    $("mm-tit").textContent = "MongoDB · base magallanes_montero · colección «" + d.coleccion + "»";
    $("mm-json").textContent = JSON.stringify(JSON.parse(d.json), null, 2);
  } catch (e) { $("mm-tit").textContent = "MongoDB"; $("mm-json").textContent = e.message; }
}
