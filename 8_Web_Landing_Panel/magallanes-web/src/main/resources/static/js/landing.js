// =====================================================================
// Landing Page (W01): carga datos de SQL Server y envía el formulario.
// GET  /api/publico/materias      → tabla MATERIA
// GET  /api/publico/socios        → EMPLEADO + ABOGADO + ABOGADO_MATERIA
// GET  /api/publico/calificacion  → AVG(ENCUESTA.calificacion)
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

// ---------- Áreas de práctica y combo «Materia»
async function cargarMaterias() {
  try {
    const materias = await api("api/publico/materias");
    $("areas-lista").innerHTML = materias.map((m) => `
      <article class="area">
        <span class="inicial">${escapar(m.nombre[0])}</span><h3>${escapar(m.nombre)}</h3>
        <p>${escapar(m.descripcion || "")}</p>
        <a onclick="elegirMateria(${m.idMateria})">Consultar →</a>
      </article>`).join("");
    $("idMateria").innerHTML = '<option value="">Seleccione…</option>' +
      materias.map((m) => `<option value="${m.idMateria}">${escapar(m.nombre)}</option>`).join("");
    $("pie-areas").innerHTML = materias.slice(0, 4).map((m) => `<a href="#areas">${escapar(m.nombre)}</a>`).join("");
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

// ---------- Socios
async function cargarSocios() {
  try {
    const socios = await api("api/publico/socios");
    $("socios-lista").innerHTML = socios.map((s) => `
      <article class="socio">
        <div class="av">${escapar(s.iniciales)}</div>
        <div><b>${escapar(s.nombre)}</b><small>${escapar(s.materias || "")}</small></div>
        <div class="col"><b>Colegiatura:</b> ${escapar(s.colegiatura)}</div>
      </article>`).join("");
  } catch (e) {
    $("socios-lista").innerHTML = "";
  }
}

// ---------- Calificación promedio (ENCUESTA)
async function cargarCalificacion() {
  try {
    const c = await api("api/publico/calificacion");
    if (c.promedio == null) return;
    $("promedio").textContent = Number(c.promedio).toFixed(1) + " / 5";
    const llenas = Math.round(c.promedio);
    $("estrellas").textContent = "★".repeat(llenas) + "☆".repeat(5 - llenas);
    $("satisf-texto").textContent = `Calificación promedio de ${c.respuestas} clientes al cerrar su caso (encuesta de satisfacción).`;
  } catch (e) { /* sin datos: se deja el texto por defecto */ }
}

// ---------- Contraparte: persona o empresa
document.querySelectorAll('input[name="cpTipo"]').forEach((r) => r.addEventListener("change", () => {
  const tipo = document.querySelector('input[name="cpTipo"]:checked').value;
  $("cp-natural").hidden = tipo !== "NATURAL";
  $("cp-juridica").hidden = tipo !== "JURIDICA";
}));

$("resumen").addEventListener("input", () => { $("contador").textContent = $("resumen").value.length + " / 500"; });

// ---------- Validación en el navegador (las mismas reglas valida el servidor y SQL Server)
function marcar(id, mensaje) {
  const campo = $(id).closest(".campo");
  campo.classList.add("error");
  campo.querySelector(".msg").textContent = mensaje;
}

function validar(d) {
  document.querySelectorAll(".campo.error").forEach((c) => c.classList.remove("error"));
  let ok = true;
  const mal = (id, m) => { marcar(id, m); ok = false; };
  if (!d.nombres) mal("nombres", "Ingrese sus nombres.");
  if (!d.apellidos) mal("apellidos", "Ingrese sus apellidos.");
  if (d.tipoDocumento === "DNI" && !/^\d{8}$/.test(d.nroDocumento)) mal("nroDocumento", "El DNI tiene 8 dígitos.");
  else if (!/^[A-Za-z0-9]{6,15}$/.test(d.nroDocumento)) mal("nroDocumento", "Número no válido.");
  if (!/^\+?\d{7,15}$/.test(d.telefono.replace(/\s/g, ""))) mal("telefono", "Ingrese un celular válido.");
  if (d.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(d.email)) mal("email", "Correo no válido.");
  if (!d.idMateria) mal("idMateria", "Seleccione la materia.");
  if (d.resumen.length < 15) mal("resumen", "Cuéntenos un poco más (mínimo 15 caracteres).");
  if (d.contraparteTipo === "NATURAL" && (!d.contraparteNombres || !d.contraparteApellidos)) {
    if (!d.contraparteNombres) mal("cpNombres", "Ingrese los nombres.");
    if (!d.contraparteApellidos) mal("cpApellidos", "Ingrese los apellidos.");
  }
  if (d.contraparteTipo === "JURIDICA" && !d.contraparteRazonSocial) mal("cpRazon", "Ingrese la razón social.");
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
    nombres: v("nombres"), apellidos: v("apellidos"), tipoDocumento: v("tipoDocumento"), nroDocumento: v("nroDocumento"),
    telefono: v("telefono"), email: v("email"), idMateria: v("idMateria") ? Number(v("idMateria")) : null, resumen: v("resumen"),
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
