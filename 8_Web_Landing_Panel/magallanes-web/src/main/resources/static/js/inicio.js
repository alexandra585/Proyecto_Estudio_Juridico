// =====================================================================
// Inicio del panel por rol: GET /api/panel/inicio (InicioRepositorio.java)
// =====================================================================
const ICO = {
  bandeja: '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.5 5h13L22 12v7H2v-7z"/>',
  calendario: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
  alerta: '<path d="M12 3l10 18H2z"/><path d="M12 10v5M12 18h.01"/>',
  dinero: '<rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="3"/>',
  carpeta: '<path d="M3 7h6l2 2h10v10H3z"/>',
  reloj: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>',
  documento: '<path d="M14 3H6v18h12V7z"/><path d="M14 3v4h4"/>',
  grafico: '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
};
const ACCESOS = {
  SECRETARIA: [["index.html", "Atender consultas"], ["contrato.html", "Registrar contrato"], ["t4-cobranza.html", "Registrar pago"]],
  ABOGADO: [["propuesta.html", "Nueva propuesta"], ["t2-contratacion.html", "Abrir expediente"], ["t3-expediente.html", "Nuevo escrito"]],
  PRACTICANTE: [["t3-expediente.html", "Redactar escrito"], ["index.html", "Ver consultas"]],
  ADMINISTRADOR: [["dashboard.html", "Ver dashboard"], ["t4-cobranza.html", "Cobranza"], ["t3-expediente.html", "Expedientes"]],
};
(async function () {
  const h = new Date().getHours();
  $("saludo").textContent = h < 12 ? "Buenos días" : h < 19 ? "Buenas tardes" : "Buenas noches";
  try {
    const d = await api("../api/panel/inicio");
    $("titulo-inicio").textContent = d.nombre.split(" ")[0] + ", este es su día";
    $("accesos").innerHTML = (ACCESOS[d.cargo] || []).map(([h, t]) => `<a class="btn btn-sec" href="${h}">${esc(t)}</a>`).join("");
    $("kpis").innerHTML = d.kpis.map((k) => `
      <a class="kpi-i t-${k.tono}" href="${k.enlace}">
        <span class="ico-c"><svg viewBox="0 0 24 24">${ICO[k.icono] || ""}</svg></span>
        <span><small>${esc(k.titulo)}</small><b>${esc(k.valor)}</b><em>${esc(k.detalle)}</em></span>
      </a>`).join("");
    $("listas").innerHTML = d.listas.map((l) => `
      <div class="tarjeta">
        <div class="cab-tarjeta"><h2>${esc(l.titulo)}</h2><a href="${l.enlace}">Ver todo →</a></div>
        <div style="overflow-x:auto"><table class="tabla mini"><thead><tr>${l.columnas.map((c) => `<th>${esc(c)}</th>`).join("")}</tr></thead>
        <tbody>${l.filas.length ? l.filas.map((f) => `<tr>${f.map((v, i) => `<td>${celda(l.columnas[i], v)}</td>`).join("")}</tr>`).join("")
          : `<tr><td colspan="${l.columnas.length}" class="vacio">Nada pendiente 🎉</td></tr>`}</tbody></table></div>
      </div>`).join("");
  } catch (e) { mostrarError($("alerta"), e); }
})();
function celda(col, v) {
  if (v == null || v === "") return "—";
  if (col === "Días") return Number(v) < 0 ? `<span class="dias-neg">${-v} día(s) vencido</span>` : Number(v) <= 2 ? `<span class="dias-ok">${v} día(s)</span>` : `${v} días`;
  if (col === "Urgente") return v ? '<span class="estado e-VENCIDO">URGENTE</span>' : "";
  if (col === "★") return `<span class="est-txt">${"★".repeat(v)}${"☆".repeat(5 - v)}</span>`;
  return esc(v);
}
