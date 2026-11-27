// =====================================================================
// FICHA DEL EXPEDIENTE (la usan el panel «Escritos y resoluciones» y el portal del cliente «Mi caso»)
// Datos: GET /api/panel/t3/casos/{id}/ficha  ·  GET /api/portal/casos/{id}  (vista del cliente, sin datos internos)
// =====================================================================
(function () {
  const e = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const s = (n) => "S/ " + Number(n || 0).toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const fechaCorta = (iso) => { if (!iso) return ""; const [a, m, d] = iso.slice(0, 10).split("-"); return `${d}/${m}/${a}`; };
  const ICON = { ETAPA: "◆", PRESENTACION: "↗", RESOLUCION: "⚖", AUDIENCIA: "🗓", ESCRITO: "✎", PLAZO: "✓" };

  function semaforo(p) {
    if (p.estado === "CUMPLIDO") return { c: "ok", t: "Cumplido " + (p.cumplido || "") };
    if (p.estado === "VENCIDO") return { c: "rojo", t: `Vencido hace ${Math.abs(p.dias_restantes)} día(s)` };
    if (p.dias_restantes <= 2) return { c: "rojo", t: p.dias_restantes === 0 ? "Vence HOY" : `Vence en ${p.dias_restantes} día(s)` };
    if (p.dias_restantes <= 5) return { c: "ambar", t: `Vence en ${p.dias_restantes} días` };
    return { c: "verde", t: `Vence en ${p.dias_restantes} días` };
  }

  window.renderFicha = function (el, d, opc = {}) {
    const cli = !!opc.cliente, c = d.caso;
    const visibles = d.etapas.filter((x) => x.estado !== "PENDIENTE" || x.orden > Math.max(0, ...d.etapas.filter((y) => y.estado !== "PENDIENTE").map((y) => y.orden)));
    const hechas = d.etapas.filter((x) => ["HECHA", "ACTUAL", "PREVIA", "OMITIDA"].includes(x.estado)).length;
    const actual = d.etapas.find((x) => x.estado === "ACTUAL");
    const proxAud = d.audiencias.filter((a) => a.proxima).sort((a, b) => a.dias - b.dias);
    const plazosAbiertos = d.plazos.filter((p) => cli ? p.estado === "PENDIENTE" : p.estado !== "CUMPLIDO");   // el cliente ve solo las próximas fechas

    el.innerHTML = `
    <div class="fx-cab">
      <div>
        <div class="fx-cod">${e(c.codigo_interno)} ${c.nro_expediente_judicial ? `<span>· Exp. ${e(c.nro_expediente_judicial)}</span>` : ""}</div>
        <h2 class="fx-tit">${e(c.descripcion)}</h2>
        <div class="fx-meta"><span>${e(c.materia)}</span>${cli ? "" : `<span>Cliente: <b>${e(c.cliente)}</b></span>`}<span>Abogado: <b>${e(c.abogado)}</b></span>
          <span>Abierto el ${e(c.apertura)} · ${c.dias} días</span>${c.es_alta_complejidad ? '<span class="fx-chip rojo">Alta complejidad</span>' : ""}</div>
      </div>
      <div class="fx-estado ${c.estado === "ACTIVO" ? "activo" : ""}">${e(c.estado === "ACTIVO" ? "En trámite" : c.estado === "CERRADO" ? "Concluido" : c.estado)}</div>
    </div>

    <div class="fx-etapas" aria-label="Etapas del proceso">
      ${visibles.map((x) => `<div class="fx-etapa ${x.estado.toLowerCase()}" title="${e(x.nombre)}${x.estado === "PREVIA" ? " · antes de que el estudio tomara el caso" : x.estado === "OMITIDA" ? " · no se realizó en este caso" : x.inicio ? " · desde " + e(x.inicio) : ""}">
        <span class="fx-pto">${x.estado === "HECHA" ? "✓" : x.estado === "OMITIDA" ? "–" : x.orden}</span><span class="fx-enom">${e(x.nombre)}</span>
        ${x.inicio ? `<small>${e(x.inicio)}</small>` : ""}</div>`).join("")}
    </div>
    <div class="fx-avance"><div style="width:${Math.round(100 * hechas / Math.max(1, d.etapas.length))}%"></div></div>
    <p class="fx-ayuda">${actual ? `Etapa actual: <b>${e(actual.nombre)}</b> (desde el ${e(actual.inicio)}).` : c.estado === "CERRADO" ? "El caso concluyó." : ""}
      ${cli ? "" : '<span class="bd">caso_etapa ⋈ etapa_procesal (fecha_fin NULL = etapa actual)</span>'}</p>

    <div class="fx-grid">
      <section class="fx-caja">
        <h3>${cli ? "Próximas fechas" : "Semáforo de plazos"} ${cli ? "" : '<span class="bd">vw_plazo_estado</span>'}</h3>
        ${proxAud.map((a) => `<div class="fx-plazo azul"><b>Audiencia ${e(a.tipo_audiencia.toLowerCase())}</b><span>${e(a.fecha)} · ${e(a.modalidad.toLowerCase())} · ${e(a.entidad)}</span>
            <em>${a.dias === 0 ? "HOY" : a.dias === 1 ? "Mañana" : "En " + a.dias + " días"}</em></div>`).join("")}
        ${(cli ? plazosAbiertos : d.plazos).slice(0, cli ? 4 : 8).map((p) => { const m = cli ? { c: "azul", t: p.dias_restantes === 0 ? "Hoy" : "En " + p.dias_restantes + " días" } : semaforo(p); return `<div class="fx-plazo ${m.c}">
            <b>${e(p.descripcion)}</b><span>Vence ${e(p.vence)}${cli ? "" : " · " + e(p.responsable)}</span><em>${e(m.t)}</em></div>`; }).join("")}
        ${!proxAud.length && !(cli ? plazosAbiertos : d.plazos).length ? '<div class="fx-vacio">No hay fechas pendientes.</div>' : ""}
      </section>
      <section class="fx-caja">
        <h3>Partes del proceso ${cli ? "" : '<span class="bd">caso_parte ⋈ rol_procesal</span>'}</h3>
        ${d.partes.map((p) => `<div class="fx-parte"><span class="fx-chip ${p.tipo_parte === "CLIENTE" ? "verde" : p.tipo_parte === "CONTRAPARTE" ? "rojo" : ""}">${e(p.tipo_parte)}</span>
            <div><b>${e(p.nombre)}</b><small>${e(p.rol)}${p.abogado_externo ? " · abogado: " + e(p.abogado_externo) : ""}</small></div></div>`).join("") || '<div class="fx-vacio">Sin partes registradas.</div>'}
        ${cli && c.abogado_email ? `<div class="fx-contacto">Su abogado: <b>${e(c.abogado)}</b><br><a href="mailto:${e(c.abogado_email)}">${e(c.abogado_email)}</a>${c.abogado_telefono ? ` · <a href="tel:${e(c.abogado_telefono)}">${e(c.abogado_telefono)}</a>` : ""}</div>` : ""}
      </section>
    </div>

    <div class="fx-grid">
      <section class="fx-caja">
        <h3>Línea de tiempo ${cli ? "" : '<span class="bd">caso_etapa ∪ presentacion ∪ resolucion ∪ audiencia ∪ documento_legal ∪ plazo</span>'}</h3>
        <ol class="fx-linea">${d.linea.slice(0, cli ? 12 : 20).map((x) => `<li class="t-${x.tipo.toLowerCase()}"><span class="fx-ico">${ICON[x.tipo] || "•"}</span>
          <div><small>${fechaCorta(x.fecha)}</small><b>${e(x.titulo)}</b>${x.detalle ? `<span>${e(x.detalle)}</span>` : ""}</div></li>`).join("") || '<li class="fx-vacio">Sin movimientos.</li>'}</ol>
      </section>
      <section class="fx-caja">
        <h3>Documentos ${cli ? "" : '<span class="bd">documento_legal + MongoDB archivos.versiones</span>'}</h3>
        ${d.documentos.map((x) => `<div class="fx-doc">
            <div class="fx-doc-ico">${x.tipo_documento === "DEMANDA" ? "⚖" : "📄"}</div>
            <div class="fx-doc-txt"><b>${e(x.titulo)}</b>
              <small>${e(x.tipo_documento)} · ${x.presentado ? "presentado el " + e(x.presentado) : "creado el " + e(x.creado)}${cli ? "" : " · " + e(x.redactor)}${x.elaborado_con_ia && !cli ? " · borrador con IA" : ""}</small>
              ${x.versiones && x.versiones.length && !cli ? `<details><summary>${x.versiones.length} versión(es) en MongoDB</summary>${x.versiones.map((v) =>
                `<div class="fx-ver">v${e(v.v)} · ${e(v.autor)} · ${v.fecha ? new Date(v.fecha).toLocaleDateString("es-PE") : ""}${v.origen ? " · " + e(v.origen) : ""}${v.observaciones ? " — " + e(v.observaciones) : ""}</div>`).join("")}</details>` : ""}
            </div>
            <div class="fx-doc-acc"><span class="estado e-${e(x.estado)}">${e(x.estado)}</span>
            ${"" /* [OCULTO PARA LA SUSTENTACIÓN · el documento se revisa en MongoDB Atlas] !cli && x.archivo_mongo_id ? `<button class="btn btn-sec btn-mini" type="button" onclick="verMongo('../api/panel/t3/archivos/${e(String(x.archivo_mongo_id).trim())}')">JSON</button>` : "" */}</div>
          </div>`).join("") || '<div class="fx-vacio">Aún no hay documentos.</div>'}
      </section>
    </div>

    ${d.cuotas && d.cuotas.length ? `<section class="fx-caja">
      <h3>Pagos del contrato ${cli ? "" : '<span class="bd">vw_cuota_estado</span>'}</h3>
      <div class="fx-cuotas">${d.cuotas.map((q) => `<div class="fx-cuota q-${e(q.estado)}"><b>${e(q.concepto.replace("_", " "))} ${q.nro_cuota}</b><span>${s(q.monto)}</span><small>${e(q.vence)} · ${e(q.estado.replace("_", " "))}</small></div>`).join("")}</div>
    </section>` : ""}

    ${!cli && d.bitacora && d.bitacora.length ? `<details class="fx-caja fx-bit"><summary><b>Bitácora interna</b> (${d.bitacora.length} últimos movimientos) <span class="bd">MongoDB · expedientes.bitacora</span></summary>
      ${d.bitacora.map((b) => `<div class="fx-ver">${e(new Date(b.fecha).toString() !== "Invalid Date" ? new Date(b.fecha).toLocaleString("es-PE") : b.fecha)} · <b>${e(b.evento)}</b> ${b.usuario ? "· " + e(b.usuario) : ""}</div>`).join("")}
      ${d.etiquetas ? `<div style="margin-top:8px">${d.etiquetas.map((t) => `<span class="fx-chip">#${e(t)}</span>`).join(" ")}</div>` : ""}
    </details>` : ""}`;
  };
})();
