// =====================================================================
// Landing Page (W01): carga datos de SQL Server y envía el formulario.
// GET  /api/publico/materias      → tabla MATERIA
// GET  /api/publico/socios        → EMPLEADO + ABOGADO + ABOGADO_MATERIA
// GET  /api/publico/calificacion  → AVG(ENCUESTA.calificacion)
// GET  /api/publico/cifras        → COUNT(caso), clientes, abogados (SQL Server)
// GET  /api/publico/testimonios   → MongoDB encuestas con publicacion.autoriza = true
// POST /api/publico/consultas     → transacción T1
// =====================================================================
const $ = (id) => document.getElementById(id);

async function api(url, opciones) {
  const r = await fetch(url, opciones);
  const datos = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(datos.error || ("Error " + r.status));
  return datos;
}

const escapar = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// ---------- Áreas de práctica y combo «Materia» (ícono según el nombre de la materia)
const ICONO_AREA = [
  [/famil/i, '<circle cx="8" cy="7" r="3"/><circle cx="17" cy="8" r="2.5"/><path d="M2 20c0-3.5 2.7-6 6-6s6 2.5 6 6"/><path d="M14 20c0-2.6 1.3-4.6 3-4.6s4 2 4 4.6"/>'],
  [/labor/i, '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>'],
  [/penal/i, '<path d="M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/>'],
  [/comerc|empres|societ/i, '<path d="M3 21h18M5 21V7l7-4 7 4v14"/><path d="M9 10h.01M15 10h.01M9 14h.01M15 14h.01M10 21v-4h4v4"/>'],
  [/admin|públic|public/i, '<path d="M3 10l9-6 9 6"/><path d="M5 10v9M9 10v9M15 10v9M19 10v9M3 21h18"/>'],
  [/civil/i, '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-5h4v5"/>'],
];
const ICONO_DEF = '<path d="M12 3v17M7 20h10M4 7h16M12 4l-1 3h2z"/><path d="M4 7l-3 6h6zM20 7l-3 6h6z"/>';
const iconoArea = (n) => (ICONO_AREA.find(([r]) => r.test(n)) || [null, ICONO_DEF])[1];

async function cargarMaterias() {
  try {
    const materias = await api("api/publico/materias");
    $("areas-lista").innerHTML = materias.map((m) => `
      <article class="area revelar">
        <span class="ico-area"><svg viewBox="0 0 24 24">${iconoArea(m.nombre)}</svg></span>
        <h3>${escapar(m.nombre)}</h3>
        <p>${escapar(m.descripcion || "")}</p>
        <a onclick="elegirMateria(${m.idMateria})">Consultar sobre ${escapar(m.nombre.toLowerCase())} →</a>
      </article>`).join("");
    $("idMateria").innerHTML = '<option value="">Seleccione…</option>' +
      materias.map((m) => `<option value="${m.idMateria}">${escapar(m.nombre)}</option>`).join("");
    $("pie-areas").innerHTML = materias.slice(0, 5).map((m) => `<a href="#areas">${escapar(m.nombre)}</a>`).join("");
    revelar();
  } catch (e) {
    $("areas-lista").innerHTML = `<p class="alerta mal" style="display:block">No se pudo conectar con la base de datos: ${escapar(e.message)}</p>`;
    $("idMateria").innerHTML = '<option value="">(sin conexión a SQL Server)</option>';
    mostrarAlerta("mal", "No se pudo leer la tabla MATERIA de SQL Server: " + e.message);
  }
}

function elegirMateria(id) {
  $("idMateria").value = id;
  location.hash = "#contacto";
  $("nombres").focus();
}

function marcarUrgente() { $("esUrgente").checked = true; }

// ---------- Equipo (abogados)
async function cargarSocios() {
  try {
    const socios = await api("api/publico/socios");
    $("socios-lista").innerHTML = socios.map((s, i) => `
      <article class="socio revelar">
        <div class="franja"></div>
        <div class="av">${escapar(s.iniciales)}</div>
        <b>${escapar(s.nombre)}</b>
        <span class="cargo">${i < 2 ? "Socio fundador" : "Abogado asociado"}</span>
        <div class="chips-m">${String(s.materias || "").split(" · ").filter(Boolean).map((m) => `<span>${escapar(m)}</span>`).join("")}</div>
        <div class="col">Colegiatura ${escapar(s.colegiatura)}</div>
      </article>`).join("");
    revelar();
  } catch (e) {
    $("socios-lista").innerHTML = "";
  }
}

// ---------- Calificación promedio (ENCUESTA) y cifras (SQL Server)
async function cargarCalificacion() {
  try {
    const c = await api("api/publico/calificacion");
    if (c.promedio == null) return;
    $("promedio").textContent = Number(c.promedio).toFixed(1) + " / 5";
    const llenas = Math.round(c.promedio);
    $("estrellas").textContent = "★".repeat(llenas) + "☆".repeat(5 - llenas);
    $("satisf-texto").textContent = `según ${c.respuestas} encuesta(s) de clientes`;
  } catch (e) { /* sin datos: se deja el texto por defecto */ }
}

function contar(el, fin) {
  const n = Number(fin) || 0, t0 = performance.now();
  const paso = (t) => { const k = Math.min(1, (t - t0) / 1200); el.textContent = Math.round(n * (1 - Math.pow(1 - k, 3))); if (k < 1) requestAnimationFrame(paso); };
  requestAnimationFrame(paso);
}
async function cargarCifras() {
  try {
    const c = await api("api/publico/cifras");
    contar($("c-casos"), c.casos); contar($("c-clientes"), c.clientes); contar($("c-abogados"), c.abogados);
  } catch (e) { /* se quedan los guiones */ }
}

// ---------- Testimonios: SOLO los que el cliente autorizó en la encuesta (MongoDB)
async function cargarTestimonios() {
  const caja = $("testimonios-lista");
  try {
    const [t, c] = await Promise.all([api("api/publico/testimonios"), api("api/publico/calificacion").catch(() => ({}))]);
    if (!t.length) {
      caja.innerHTML = `<div class="sin-testimonios"><b>${c.promedio != null ? Number(c.promedio).toFixed(1) + " / 5" : "★★★★★"}</b>
        ${c.respuestas ? `Calificación promedio de ${c.respuestas} cliente(s) al cerrar su caso.` : "Muy pronto, las opiniones de nuestros clientes."}
        Publicamos comentarios solo cuando el cliente nos da su permiso.</div>`;
      return;
    }
    $("t-sub").textContent = c.respuestas ? `Promedio ${Number(c.promedio).toFixed(1)} / 5 en ${c.respuestas} encuesta(s). Publicamos solo los comentarios que el cliente autorizó.` : $("t-sub").textContent;
    const ini = (n) => String(n).replace(/\./g, "").split(/\s+/).filter(Boolean).map((x) => x[0]).slice(0, 2).join("").toUpperCase();
    caja.innerHTML = t.map((x) => `
      <article class="testimonio revelar">
        <div class="est">${"★".repeat(x.estrellas || 5)}${"☆".repeat(5 - (x.estrellas || 5))}</div>
        <p>${escapar(x.comentario)}</p>
        <div class="quien"><span class="av">${escapar(ini(x.nombre))}</span><span><b>${escapar(x.nombre)}</b><small>${escapar(x.materia || "")}${x.fecha ? " · " + escapar(x.fecha) : ""}</small></span></div>
      </article>`).join("");
    revelar();
  } catch (e) { caja.innerHTML = ""; }
}

// ---------- Efectos: sombra de la cabecera y aparición al hacer scroll
window.addEventListener("scroll", () => $("cabecera").classList.toggle("sombra", scrollY > 10), { passive: true });
const observador = "IntersectionObserver" in window
  ? new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("visible"); observador.unobserve(e.target); } }), { threshold: .12 })
  : null;
function revelar() {
  document.querySelectorAll(".revelar:not(.visible)").forEach((el) => observador ? observador.observe(el) : el.classList.add("visible"));
}
document.querySelectorAll(".ventajas article, .pl, .faq details, .hero-card").forEach((el) => el.classList.add("revelar"));
document.querySelectorAll(".menu a").forEach((a) => a.addEventListener("click", () => document.body.classList.remove("nav-abierta")));

// ---------- Contraparte: persona o empresa
document.querySelectorAll('input[name="cpTipo"]').forEach((r) => r.addEventListener("change", () => {
  const tipo = document.querySelector('input[name="cpTipo"]:checked').value;
  $("cp-natural").hidden = tipo !== "NATURAL";
  $("cp-juridica").hidden = tipo !== "JURIDICA";
}));

$("resumen").addEventListener("input", () => { $("contador").textContent = $("resumen").value.length + " / 500"; });

// ---------- Reglas de formato (las mismas de Validar.java y de los CHECK de SQL Server)
const DOC = {
  DNI: { re: /^\d{8}$/, max: 8, modo: "numeric", filtro: /[^0-9]/g, ph: "8 dígitos", txt: "DNI: 8 dígitos" },
  CE: { re: /^\d{9,12}$/, max: 12, modo: "numeric", filtro: /[^0-9]/g, ph: "9 a 12 dígitos", txt: "Carné de extranjería: 9 a 12 dígitos" },
  PASAPORTE: { re: /^[A-Z0-9]{6,12}$/, max: 12, modo: "text", filtro: /[^A-Za-z0-9]/g, ph: "6 a 12 letras o números", txt: "Pasaporte: 6 a 12 letras o números" },
};
const LETRAS = /[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ' -]/g;
const RE_NOMBRE = /^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ' -]{2,80}$/;
const RE_CEL = /^9\d{8}$/;
const RE_MAIL = /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/;
const limpiarTel = (t) => t.replace(/[\s-]/g, "");

// Mientras escribe: no deja poner letras en el DNI/celular ni números en los nombres, y respeta el máximo de caracteres
function filtrar(id, re, transformar) {
  $(id).addEventListener("input", (e) => {
    const el = e.target, antes = el.value;
    let v = antes.replace(re, "");
    if (transformar) v = transformar(v);
    if (v !== antes) { el.value = v; avisoBreve(id); }
    actualizarPistas();
  });
}
function avisoBreve(id) {
  const c = $(id).closest(".campo"); c.classList.add("error");
  c.querySelector(".msg").textContent = id === "nroDocumento" || id === "telefono" ? "Solo se permiten números." : "Solo se permiten letras.";
  clearTimeout(c._t); c._t = setTimeout(() => c.classList.remove("error"), 1600);
}
function configurarDocumento() {
  const d = DOC[$("tipoDocumento").value];
  const el = $("nroDocumento");
  el.maxLength = d.max; el.inputMode = d.modo; el.placeholder = d.ph;
  el.value = el.value.replace(d.filtro, "").toUpperCase().slice(0, d.max);
  actualizarPistas();
}
function actualizarPistas() {
  const d = DOC[$("tipoDocumento").value], v = $("nroDocumento").value;
  $("pista-doc").textContent = `${d.txt} · ${v.length} / ${d.max}${d.re.test(v) ? " ✓" : ""}`;
  const t = limpiarTel($("telefono").value);
  $("pista-tel").textContent = t ? (RE_CEL.test(t) ? "Celular válido ✓" : `9 dígitos, empieza con 9 · ${t.length} / 9`) : "9 dígitos, empieza con 9";
}
filtrar("nroDocumento", /[^A-Za-z0-9]/g, (v) => v.replace(DOC[$("tipoDocumento").value].filtro, "").toUpperCase());
filtrar("telefono", /[^0-9]/g, (v) => v.slice(0, 9));
["nombres", "apellidos", "cpNombres", "cpApellidos"].forEach((id) => filtrar(id, LETRAS, (v) => v.replace(/\s{2,}/g, " ")));
$("tipoDocumento").addEventListener("change", configurarDocumento);
$("email").addEventListener("blur", () => { $("email").value = $("email").value.trim().toLowerCase(); });
// Al salir de cada campo se revisa y se marca en verde o rojo
["nombres", "apellidos", "nroDocumento", "telefono", "email"].forEach((id) => $(id).addEventListener("blur", () => revisarCampo(id)));
function revisarCampo(id) {
  const v = $(id).value.trim(), c = $(id).closest(".campo");
  let m = "";
  if (id === "nombres" || id === "apellidos") m = !v ? "" : RE_NOMBRE.test(v) ? "" : "Mínimo 2 letras.";
  if (id === "nroDocumento") m = !v ? "" : DOC[$("tipoDocumento").value].re.test(v) ? "" : DOC[$("tipoDocumento").value].txt + ".";
  if (id === "telefono") m = !v ? "" : RE_CEL.test(limpiarTel(v)) ? "" : "Debe tener 9 dígitos y empezar con 9.";
  if (id === "email") m = !v ? "" : RE_MAIL.test(v) ? "" : "Correo no válido (ej.: nombre@gmail.com).";
  c.classList.toggle("error", !!m); c.classList.toggle("ok", !!v && !m);
  c.querySelector(".msg").textContent = m;
}
configurarDocumento();

// ---------- Validación al enviar (las mismas reglas valida el servidor y SQL Server)
function marcar(id, mensaje) {
  const campo = $(id).closest(".campo");
  campo.classList.add("error");
  campo.querySelector(".msg").textContent = mensaje;
}

function validar(d) {
  document.querySelectorAll(".campo.error").forEach((c) => c.classList.remove("error"));
  let ok = true;
  const mal = (id, m) => { marcar(id, m); ok = false; };
  if (!RE_NOMBRE.test(d.nombres)) mal("nombres", "Ingrese sus nombres (solo letras, mínimo 2).");
  if (!RE_NOMBRE.test(d.apellidos)) mal("apellidos", "Ingrese sus apellidos (solo letras, mínimo 2).");
  if (!DOC[d.tipoDocumento].re.test(d.nroDocumento)) mal("nroDocumento", DOC[d.tipoDocumento].txt + ".");
  if (!RE_CEL.test(d.telefono)) mal("telefono", "Celular de 9 dígitos que empiece con 9 (ej.: 987654321).");
  if (d.email && !RE_MAIL.test(d.email)) mal("email", "Correo no válido (ej.: nombre@gmail.com).");
  if (!d.idMateria) mal("idMateria", "Seleccione la materia.");
  if (d.resumen.length < 15) mal("resumen", "Cuéntenos un poco más (mínimo 15 caracteres).");
  if (d.contraparteTipo === "NATURAL") {
    if (!RE_NOMBRE.test(d.contraparteNombres)) mal("cpNombres", "Solo letras, mínimo 2.");
    if (!RE_NOMBRE.test(d.contraparteApellidos)) mal("cpApellidos", "Solo letras, mínimo 2.");
  }
  if (d.contraparteTipo === "JURIDICA" && d.contraparteRazonSocial.length < 3) mal("cpRazon", "Ingrese la razón social (mínimo 3 caracteres).");
  if (!d.aceptaDatos) { mostrarAlerta("mal", "Debe aceptar el tratamiento de sus datos personales (Ley 29733)."); ok = false; }
  return ok;
}

function mostrarAlerta(tipo, texto) {
  const a = $("alerta");
  a.className = "alerta " + tipo;
  a.textContent = texto;
}

// ---------- Envío → POST /api/publico/consultas (transacción T1 en SQL Server)
$("form-consulta").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  $("alerta").className = "alerta";
  const v = (id) => $(id).value.trim();
  const tipo = document.querySelector('input[name="cpTipo"]:checked').value;
  const datos = {
    nombres: v("nombres").replace(/\s+/g, " "), apellidos: v("apellidos").replace(/\s+/g, " "), tipoDocumento: v("tipoDocumento"), nroDocumento: v("nroDocumento"),
    telefono: limpiarTel(v("telefono")), email: v("email").toLowerCase(), idMateria: v("idMateria") ? Number(v("idMateria")) : null, resumen: v("resumen"),
    esUrgente: $("esUrgente").checked, aceptaDatos: $("aceptaDatos").checked,
    contraparteTipo: tipo || null, contraparteNombres: v("cpNombres"), contraparteApellidos: v("cpApellidos"), contraparteRazonSocial: v("cpRazon"),
  };
  if (!validar(datos)) {
    const primero = document.querySelector(".campo.error input, .campo.error select, .campo.error textarea");
    if (primero) primero.focus();
    return;
  }
  const boton = $("btn-enviar");
  boton.disabled = true; boton.textContent = "Enviando…";
  try {
    const r = await api("api/publico/consultas", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(datos),
    });
    $("form-zona").innerHTML = `
      <div class="exito">
        <div class="circulo">✓</div>
        <h3>¡Gracias, ${escapar(datos.nombres)}! Recibimos su consulta N.° ${r.idConsulta}</h3>
        <p style="color:var(--muted)">Un abogado revisará su caso y le escribirá por WhatsApp en menos de 24 horas.</p>
        <div class="traza bd-traza">
          <div>COMMIT ✔ Transacción T1 registrada en SQL Server:</div>
          <div><b>PERSONA</b> id_persona = ${r.idPersona} ${r.personaNueva ? "(nueva)" : "(ya existía: se reutilizó)"}</div>
          <div><b>CONSULTA</b> id_consulta = ${r.idConsulta} · canal LANDING · estado RECIBIDA</div>
          ${r.idContraparte ? `<div><b>CONSULTA_CONTRAPARTE</b> (${r.idConsulta}, ${r.idContraparte})</div>` : "<div>CONSULTA_CONTRAPARTE: sin contraparte</div>"}
          <div><b>NOTIFICACION</b> id_notificacion = ${r.idNotificacion} · CONFIRMACION_CONSULTA · PENDIENTE</div>
        </div>
        <button class="btn btn-sec" onclick="location.reload()">Enviar otra consulta</button>
      </div>`;
  } catch (e) {
    mostrarAlerta("mal", e.message);
    boton.disabled = false; boton.textContent = "Enviar consulta";
  }
});


cargarMaterias();
cargarSocios();
cargarCalificacion();
cargarCifras();
cargarTestimonios();
revelar();
