// =====================================================================
// Menú lateral común del panel (todas las pantallas lo comparten).
// Uso: <aside class="lateral" id="lateral" data-activo="dashboard"></aside> + <script src="../js/menu.js">
// =====================================================================
(function () {
  const MENU = [
    { grupo: "Socios" },
    { id: "dashboard", texto: "W03 · Dashboard gerencial", href: "dashboard.html" },
    { grupo: "P1 · Captación (T1)" },
    { id: "bandeja", texto: "W04 · Bandeja y W06 · Cita", href: "index.html" },
    { grupo: "P1 · Contratación (T2)" },
    { id: "t2", texto: "W07–W09 · Propuesta, contrato y expediente", href: "t2-contratacion.html" },
    { grupo: "P2 · Expediente (T3)" },
    { id: "t3", texto: "W11–W13 · Escrito, presentación y resolución", href: "t3-expediente.html" },
    { grupo: "P3 · Cobranza y cierre (T4)" },
    { id: "t4", texto: "W18–W22 · Comprobante, pago y encuesta", href: "t4-cobranza.html" },
  ];
  const aside = document.getElementById("lateral");
  if (!aside) return;
  const activo = aside.dataset.activo;
  aside.classList.add("lateral");
  aside.innerHTML = `
    <a class="logo" href="../index.html"><span class="logo-mm">MM</span><span><b>Magallanes-Montero</b><small>PANEL</small></span></a>
    ${MENU.map((m) => m.grupo ? `<div class="grupo">${m.grupo}</div>`
      : `<a class="item ${m.id === activo ? "activo" : ""}" href="${m.href}">${m.texto}</a>`).join("")}
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
