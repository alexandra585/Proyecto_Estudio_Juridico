// =====================================================================
// Menú lateral + barra superior comunes del panel (todas las pantallas).
// Uso: <aside id="lateral" data-activo="dashboard"></aside> + <script src="../js/menu.js">
//
// ROLES: cada opción indica qué cargos (empleado.cargo) la ven. Es solo la parte visual:
// quien de verdad bloquea es el servidor (SesionInterceptor + Roles.java → 403).
//   ADMINISTRADOR = Gerencia · ABOGADO · SECRETARIA · PRACTICANTE
//
// Cada grupo y opción tiene DOS nombres (botón «Mostrar / Ocultar campos BD», js/bd.js):
//   tec = nombre técnico (proceso P1/P2/P3, transacción T1–T4, pantalla W01–W30 del Figma) · cli = nombre simple
// =====================================================================
(function () {
  const ADM = "ADMINISTRADOR", ABO = "ABOGADO", SEC = "SECRETARIA", PRA = "PRACTICANTE";
  const TODOS = [ADM, ABO, SEC, PRA];
  const ICONOS = {
    inicio: '<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
    dashboard: '<path d="M4 20V10"/><path d="M10 20V4"/><path d="M16 20v-7"/><path d="M22 20H2"/>',
    bandeja: '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.5 5h13L22 12v7H2v-7z"/>',
    w07: '<path d="M14 3H6v18h12V7z"/><path d="M14 3v4h4"/><path d="M9 13h6M9 17h4"/>',
    w08: '<path d="M4 4h16v16H4z"/><path d="M4 9h16M9 4v16"/>',
    t2: '<path d="M3 7h6l2 2h10v10H3z"/><path d="M12 12v5M9.5 14.5h5"/>',
    t3: '<path d="M12 3l9 4-9 4-9-4z"/><path d="M3 12l9 4 9-4"/><path d="M3 17l9 4 9-4"/>',
    t4: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20M6 15h4"/>',
    web: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
    salir: '<path d="M9 21H5V3h4"/><path d="M16 17l5-5-5-5M21 12H9"/>',
    buscar: '<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>',
    menu: '<path d="M3 6h18M3 12h18M3 18h18"/>',
    campana: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  };
  const svg = (k) => `<svg class="ico" viewBox="0 0 24 24" aria-hidden="true">${ICONOS[k] || ""}</svg>`;
  const MENU = [
    { id: "inicio", href: "inicio.html", tec: "Inicio · pendientes del rol", cli: "Inicio", roles: TODOS },
    { grupo: { tec: "Socios", cli: "Gerencia" }, roles: [ADM, ABO] },
    { id: "dashboard", href: "dashboard.html", tec: "W03 · Dashboard gerencial", cli: "Dashboard", roles: [ADM, ABO] },
    { grupo: { tec: "P1 · Captación (T1)", cli: "Clientes nuevos" }, roles: TODOS },
    { id: "bandeja", href: "index.html", tec: "W04 · Bandeja y W06 · Cita", cli: "Consultas y citas", roles: TODOS },
    { grupo: { tec: "P1 · Contratación (T2)", cli: "Contratación" }, roles: [ADM, ABO, SEC] },
    { id: "w07", href: "propuesta.html", tec: "W07 · Propuesta de honorarios", cli: "Propuestas", roles: [ADM, ABO] },
    { id: "w08", href: "contrato.html", tec: "W08 · Contrato y cuotas", cli: "Contratos y cuotas", roles: [ADM, SEC] },
    { id: "t2", href: "t2-contratacion.html", tec: "W09 · Apertura del expediente", cli: "Expediente nuevo", roles: [ADM, ABO] },
    { grupo: { tec: "P2 · Expediente (T3)", cli: "Expedientes" }, roles: [ADM, ABO, PRA] },
    { id: "t3", href: "t3-expediente.html", tec: "W11–W13 · Escrito, presentación y resolución", cli: "Escritos y resoluciones", roles: [ADM, ABO, PRA] },
    { grupo: { tec: "P3 · Cobranza y cierre (T4)", cli: "Cobranza y cierre" }, roles: [ADM, SEC] },
    { id: "t4", href: "t4-cobranza.html", tec: "W18–W22 · Comprobante, pago y encuesta", cli: "Comprobantes y pagos", roles: [ADM, SEC] },
  ];
  const ROL_TXT = { ADMINISTRADOR: "Gerencia", ABOGADO: "Abogado", SECRETARIA: "Secretaría", PRACTICANTE: "Practicante" };
  const doble = (x) => `<span class="solo-tec">${x.tec}</span><span class="solo-cli">${x.cli}</span>`;
  const aside = document.getElementById("lateral");
  if (!aside) return;
  const activo = aside.dataset.activo;
  const actual = MENU.find((m) => m.id === activo);
  aside.classList.add("lateral");
  aside.innerHTML = `
    <a class="logo" href="inicio.html"><span class="logo-mm">MM</span><span><b>Magallanes-Montero</b><small>PANEL</small></span></a>
    <nav id="menu-items"></nav>
    <a class="item" href="../index.html">${svg("web")}<span>Ver la página web</span></a>
    <div class="relleno"></div>
    <div class="usuario"><div class="avatar" id="u-av">··</div><div class="u-txt"><b id="u-nombre">…</b><small id="u-cargo"></small></div>
      <button class="btn-salir" id="salir" type="button" title="Cerrar sesión">${svg("salir")}</button></div>`;

  // ---- Barra superior: menú móvil, ruta, buscador en las tablas de la pantalla, fecha y rol
  const principal = document.querySelector("main.principal");
  if (principal) {
    const barra = document.createElement("header");
    barra.className = "barra-sup";
    const hoy = new Date().toLocaleDateString("es-PE", { weekday: "long", day: "numeric", month: "long" });
    barra.innerHTML = `
      <button class="hamb" type="button" aria-label="Menú">${svg("menu")}</button>
      <div class="ruta">Panel <span>›</span> <b>${actual ? `<span class="solo-cli">${actual.cli}</span><span class="solo-tec">${actual.tec}</span>` : ""}</b></div>
      <label class="buscador">${svg("buscar")}<input type="search" id="buscar-tablas" placeholder="Buscar en esta pantalla…" autocomplete="off"></label>
      <div class="hoy">${hoy}</div>
      <div class="campana-zona"><button class="campana" id="campana" type="button" aria-label="Avisos">${svg("campana")}<span class="campana-n" id="campana-n" hidden>0</span></button>
        <div class="avisos-panel" id="avisos-panel" hidden><div class="avisos-cab"><b>Avisos</b><small class="bd">NOTIFICACION (canal SISTEMA) + vw_plazo_estado</small></div><div id="avisos-lista"><div class="vacio">Cargando…</div></div></div></div>
      <span class="rol-chip" id="rol-chip">…</span>`;
    principal.prepend(barra);
    barra.querySelector(".hamb").addEventListener("click", () => document.body.classList.toggle("menu-abierto"));
    // Filtra las filas de TODAS las tablas de la pantalla (no consulta la base: busca en lo que ya se cargó)
    barra.querySelector("#buscar-tablas").addEventListener("input", (e) => {
      const t = e.target.value.trim().toLowerCase();
      document.querySelectorAll("table.tabla tbody tr").forEach((tr) => {
        tr.style.display = !t || tr.textContent.toLowerCase().includes(t) ? "" : "none";
      });
    });
  }

  function pintarMenu(cargo) {
    const visibles = MENU.filter((m) => !cargo || m.roles.includes(cargo));
    document.getElementById("menu-items").innerHTML = visibles.map((m) => m.grupo
      ? `<div class="grupo">${doble(m.grupo)}</div>`
      : `<a class="item ${m.id === activo ? "activo" : ""}" href="${m.href}">${svg(m.id)}<span>${doble(m)}</span></a>`).join("");
  }
  pintarMenu(null);

  fetch("../api/auth/yo").then((r) => {
    if (r.status === 401) { location.href = "login.html"; return null; }
    return r.json();
  }).then((u) => {
    if (!u) return;
    window.USUARIO = u;
    pintarMenu(u.cargo);
    const p = u.nombre.split(/\s+/).filter(Boolean);
    const corto = p.length >= 4 ? `${p[0]} ${p[2]}` : p.length === 3 ? `${p[0]} ${p[1]}` : u.nombre;
    document.getElementById("u-av").textContent = corto.split(" ").map((x) => x[0]).join("").slice(0, 2).toUpperCase();
    document.getElementById("u-nombre").textContent = corto;
    document.getElementById("u-cargo").textContent = ROL_TXT[u.cargo] || u.cargo;
    const chip = document.getElementById("rol-chip");
    if (chip) { chip.textContent = ROL_TXT[u.cargo] || u.cargo; chip.dataset.rol = u.cargo; }
    // Pantalla que el rol no puede usar: se reemplaza por un aviso (el servidor igual respondería 403)
    if (actual && !actual.roles.includes(u.cargo) && principal) {
      [...principal.children].forEach((c) => { if (!c.classList.contains("barra-sup")) c.remove(); });
      principal.insertAdjacentHTML("beforeend", `<div class="sin-acceso"><div class="candado-g">🔒</div>
        <h1>Esta pantalla no es de su rol</h1>
        <p>Su cuenta es de <b>${ROL_TXT[u.cargo] || u.cargo}</b>. «${actual.cli}» la usa: ${actual.roles.map((r) => ROL_TXT[r]).join(", ")}.</p>
        <span class="bd">empleado.cargo = '${u.cargo}' → Roles.java responde 403</span>
        <p><a class="btn btn-oro" href="inicio.html">Ir a mi inicio</a></p></div>`);
    }
    cargarAvisos();
    document.dispatchEvent(new CustomEvent("usuario-listo", { detail: u }));
  });
  // ---- Campana de avisos (lo «leído» se recuerda en este navegador: no se guarda en la base)
  const ICONO_AVISO = { FIRMA_DOCUMENTO: "✍", CONFIRMACION_CONSULTA: "📩", ALERTA_PLAZO: "⏰", AVISO_AUDIENCIA: "🗓", RECORDATORIO_CUOTA: "💳",
    CONSTANCIA_PAGO: "✅", ENVIO_ENCUESTA: "★", RECORDATORIO_CITA: "📅" };
  const leer = () => { try { return localStorage.getItem("mm-avisos-visto") || ""; } catch (e) { return ""; } };
  const hace = (iso) => { const m = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
    return m < 1 ? "ahora" : m < 60 ? `hace ${m} min` : m < 1440 ? `hace ${Math.round(m / 60)} h` : `hace ${Math.round(m / 1440)} d`; };
  const esc2 = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  let ultimo = "";
  async function cargarAvisos() {
    const lista = document.getElementById("avisos-lista");
    if (!lista) return;
    try {
      const r = await fetch("../api/panel/avisos"); if (!r.ok) return;
      const d = await r.json();
      const visto = leer();
      ultimo = (d.avisos[0] || {}).fecha || "";
      const nuevos = d.avisos.filter((a) => a.fecha > visto).length + d.plazos.filter((p) => p.dias_restantes <= 1).length;
      const n = document.getElementById("campana-n"); n.hidden = !nuevos; n.textContent = nuevos > 9 ? "9+" : nuevos;
      lista.innerHTML = d.plazos.map((p) => `<a class="aviso-it urgente" href="t3-expediente.html"><span>⏰</span><div><b>${esc2(p.codigo_interno)} · ${esc2(p.descripcion)}</b>
          <small>${p.estado === "VENCIDO" ? "Plazo VENCIDO el " + esc2(p.vence) : p.dias_restantes === 0 ? "Vence HOY" : "Vence en " + p.dias_restantes + " día(s) · " + esc2(p.vence)}</small></div></a>`).join("")
        + d.avisos.map((a) => `<div class="aviso-it ${a.fecha > visto ? "nuevo" : ""}"><span>${ICONO_AVISO[a.tipo_evento] || "•"}</span><div><b>${esc2(a.mensaje)}</b>
          <small>${hace(a.fecha)}${a.codigo_interno ? " · " + esc2(a.codigo_interno) : ""} · ${esc2(a.canal)}</small></div></div>`).join("")
        || '<div class="vacio" style="padding:18px">No tiene avisos.</div>';
    } catch (e) { /* sin avisos */ }
  }
  const campana = document.getElementById("campana");
  if (campana) {
    campana.addEventListener("click", (ev) => {
      ev.stopPropagation();
      const p = document.getElementById("avisos-panel"); p.hidden = !p.hidden;
      if (!p.hidden && ultimo) { try { localStorage.setItem("mm-avisos-visto", ultimo); } catch (e) { /* sin almacenamiento */ }
        setTimeout(() => { document.getElementById("campana-n").hidden = true; }, 600); }
    });
    document.addEventListener("click", (ev) => { const p = document.getElementById("avisos-panel"); if (p && !p.hidden && !p.contains(ev.target)) p.hidden = true; });
    setInterval(cargarAvisos, 60000);
  }

  document.getElementById("salir").addEventListener("click", async () => {
    await fetch("../api/auth/salir", { method: "POST" });
    location.href = "login.html";
  });
})();
