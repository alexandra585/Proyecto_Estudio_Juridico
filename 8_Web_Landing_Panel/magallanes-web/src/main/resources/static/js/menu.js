// =====================================================================
// Menú lateral común del panel (todas las pantallas lo comparten).
// Uso: <aside id="lateral" data-activo="dashboard"></aside> + <script src="../js/menu.js">
//
// Cada grupo y cada opción tiene DOS nombres:
//   tec = nombre técnico (proceso P1/P2/P3 del BPMN, transacción T1–T4, pantalla W01–W30 del Figma)
//   cli = nombre simple que ve el usuario del estudio
// El botón «Mostrar / Ocultar campos BD» (js/bd.js) decide cuál se ve.
// =====================================================================
(function () {
  const MENU = [
    { grupo: { tec: "Socios", cli: "Gerencia" } },
    { id: "dashboard", href: "dashboard.html", tec: "W03 · Dashboard gerencial", cli: "Dashboard" },
    { grupo: { tec: "P1 · Captación (T1)", cli: "Clientes nuevos" } },
    { id: "bandeja", href: "index.html", tec: "W04 · Bandeja y W06 · Cita", cli: "Consultas y citas" },
    { grupo: { tec: "P1 · Contratación (T2)", cli: "Contratación" } },
    { id: "w07", href: "propuesta.html", tec: "W07 · Propuesta de honorarios", cli: "Propuestas" },
    { id: "w08", href: "contrato.html", tec: "W08 · Contrato y cuotas", cli: "Contratos y cuotas" },
    { id: "t2", href: "t2-contratacion.html", tec: "W09 · Apertura del expediente", cli: "Expediente nuevo" },
    { grupo: { tec: "P2 · Expediente (T3)", cli: "Expedientes" } },
    { id: "t3", href: "t3-expediente.html", tec: "W11–W13 · Escrito, presentación y resolución", cli: "Escritos y resoluciones" },
    { grupo: { tec: "P3 · Cobranza y cierre (T4)", cli: "Cobranza y cierre" } },
    { id: "t4", href: "t4-cobranza.html", tec: "W18–W22 · Comprobante, pago y encuesta", cli: "Comprobantes y pagos" },
  ];
  const doble = (x) => `<span class="solo-tec">${x.tec}</span><span class="solo-cli">${x.cli}</span>`;
  const aside = document.getElementById("lateral");
  if (!aside) return;
  const activo = aside.dataset.activo;
  aside.classList.add("lateral");
  aside.innerHTML = `
    <a class="logo" href="../index.html"><span class="logo-mm">MM</span><span><b>Magallanes-Montero</b><small>PANEL</small></span></a>
    ${MENU.map((m) => m.grupo ? `<div class="grupo">${doble(m.grupo)}</div>`
      : `<a class="item ${m.id === activo ? "activo" : ""}" href="${m.href}">${doble(m)}</a>`).join("")}
    <a class="item" href="../index.html">Ver la página web</a>
    <div class="relleno"></div>
    <div class="usuario"><b id="u-nombre">…</b><small id="u-cargo"></small><div id="u-email" style="font-size:12px"></div>
      <button class="btn btn-borde" id="salir" type="button">Cerrar sesión</button></div>`;
  fetch("../api/auth/yo").then((r) => {
    if (r.status === 401) { location.href = "login.html"; return null; }
    return r.json();
  }).then((u) => {
    if (!u) return;
    document.getElementById("u-nombre").textContent = u.nombre;
    document.getElementById("u-cargo").textContent = u.cargo;
    document.getElementById("u-email").textContent = u.email;
  });
  document.getElementById("salir").addEventListener("click", async () => {
    await fetch("../api/auth/salir", { method: "POST" });
    location.href = "../index.html";
  });
})();
