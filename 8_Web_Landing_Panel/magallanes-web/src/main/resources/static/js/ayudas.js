// =====================================================================
// AYUDAS AL ESCRIBIR en los formularios del panel (todas las pantallas).
// Para cada campo: ejemplo dentro del campo (placeholder), texto de ayuda debajo,
// sugerencias frecuentes (lista desplegable o botones) y contador con el máximo
// de caracteres que acepta la columna de SQL Server (maxlength = tamaño NVARCHAR).
// =====================================================================
(function () {
  const A = {
    // W06 · Cita
    fecha: { ayuda: "Lunes a sábado. Los feriados (tabla FERIADO) no tienen horarios." },
    // W07 · Propuesta
    honorarios: { ph: "Ej.: 3500.00", ayuda: "Monto total en soles, sin IGV. Escriba 0 si el caso es pro bono (gratuito).", sug: ["1500", "2500", "3500", "5000", "8000"] },
    cuotas: { ph: "Ej.: 3", ayuda: "Entre 1 y 24 cuotas." },
    litis: { ph: "Ej.: 10", ayuda: "% del monto que el cliente gane (honorario de éxito). 0 si no aplica." },
    // W08 · Contrato
    nro: { ph: "Ej.: CT-2026-012", ayuda: "Se propone el siguiente número; no se puede repetir.", max: 20 },
    "g-n": { ph: "Ej.: 3", ayuda: "Cuántas cuotas mensuales se generan." },
    "g-inicio": { ayuda: "Fecha en que vence la primera cuota; las demás, cada mes." },
    // W09 · Expediente
    codigo: { ph: "Ej.: EXP-2026-0009", ayuda: "Formato EXP-AAAA-NNNN. Se propone el siguiente número.", max: 20 },
    "nro-judicial": { ph: "Ej.: 01234-2026-0-1801-JR-CI-05", ayuda: "N.° del juzgado o carpeta fiscal. Si aún no se presenta la demanda, déjelo vacío.", max: 40 },
    descripcion: { ph: "Ej.: Demanda de desalojo por falta de pago de 4 meses de alquiler", ayuda: "Qué se pide y contra quién, en una o dos frases.", max: 500,
      sug: ["Demanda de desalojo por falta de pago", "Demanda de alimentos para hijo menor de edad", "Despido arbitrario: reposición y pago de beneficios sociales",
        "Defensa en investigación fiscal", "Cobro de deuda por obligación de dar suma de dinero", "Impugnación de multa administrativa"] },
    resumen: { ph: "Ej.: La inquilina dejó de pagar desde julio; hay contrato firmado y dos cartas notariales.", ayuda: "Relato libre con fechas, hechos y pruebas. Se guarda en MongoDB (expedientes).", max: 4000 },
    etiquetas: { ph: "Ej.: desalojo, falta de pago, urgente", ayuda: "Palabras clave para buscar el expediente, separadas por coma.",
      sug: ["desalojo", "alimentos", "despido", "divorcio", "cobranza", "urgente", "medida cautelar"], modo: "agregar" },
    // W11 · Escrito
    "e-titulo": { ph: "Ej.: Interpongo demanda de desalojo", ayuda: "Sumilla: lo que pide el escrito, en una línea.", max: 200,
      sug: ["Interpongo demanda", "Contesto demanda", "Absuelvo traslado", "Subsano observación", "Interpongo recurso de apelación",
        "Solicito copias certificadas", "Varío domicilio procesal", "Téngase presente"] },
    "e-texto": { ayuda: "Texto completo del escrito. Se guarda en MongoDB (archivos) con su número de versión.", max: 20000 },
    // W12 · Presentación
    "p-cargo": { ph: "Ej.: 2026-01234-0-1801", ayuda: "N.° del cargo de recepción o de la constancia de la Mesa de Partes Electrónica.", max: 40 },
    // W13 · Resolución y plazo
    "r-nro": { ph: "Ej.: Resolución N.° 3", ayuda: "Tal como figura en la cédula de notificación.", max: 30,
      sug: ["Resolución N.° 1", "Resolución N.° 2", "Resolución N.° 3", "Resolución N.° 4", "Resolución N.° 5"] },
    "r-sumilla": { ph: "Ej.: Admite a trámite la demanda y corre traslado por 5 días", ayuda: "Lo que decide el juez o la entidad, en una línea.", max: 300,
      sug: ["Admite a trámite la demanda y corre traslado", "Declara inadmisible la demanda y concede plazo para subsanar",
        "Cita a audiencia única", "Concede apelación con efecto suspensivo", "Declara fundada la demanda", "Declara infundada la demanda"] },
    "pl-desc": { ph: "Ej.: Absolver el traslado de la demanda", ayuda: "Qué hay que hacer antes del vencimiento.", max: 200,
      sug: ["Contestar la demanda", "Absolver el traslado", "Subsanar la observación", "Apelar la resolución", "Presentar alegatos",
        "Ofrecer medios probatorios", "Asistir a la audiencia"] },
    "pl-dias": { ph: "Ej.: 5", ayuda: "Los días que indica la resolución. Hábiles: sin sábados, domingos ni feriados." },
    "r-texto": { ayuda: "Texto de la resolución notificada. Se guarda en MongoDB (archivos).", max: 20000 },
    // W19 · Pago
    "g-monto": { ph: "Ej.: 1180.00", ayuda: "No puede ser mayor que el saldo del comprobante." },
    "g-op": { ph: "Ej.: 00123456", ayuda: "Código de Yape/Plin o N.° de voucher. Déjelo vacío si es en efectivo.", max: 40 },
    // W22 · Encuesta
    "s-com": { ph: "Ej.: Me explicaron cada paso del proceso y siempre sabía en qué etapa estaba.", ayuda: "Comentario del cliente (opcional).", max: 500 },
  };

  function aplicar() {
    Object.entries(A).forEach(([id, c]) => {
      const el = document.getElementById(id);
      if (!el || el.dataset.ayuda) return;
      el.dataset.ayuda = "1";
      if (c.ph && !/date|time/.test(el.type)) el.placeholder = c.ph;
      if (c.max && (el.maxLength < 0 || el.maxLength > c.max)) el.maxLength = c.max;
      const linea = document.createElement("div");
      linea.className = "ayuda";
      linea.innerHTML = `<span>${c.ayuda || ""}</span>${c.max ? `<span class="contador" data-de="${id}">0 / ${c.max}</span>` : ""}`;
      el.insertAdjacentElement("afterend", linea);
      if (c.max) {
        const cont = linea.querySelector(".contador");
        const act = () => { const n = el.value.length; cont.textContent = `${n} / ${c.max}`; cont.classList.toggle("lleno", n >= c.max * 0.9); };
        el.addEventListener("input", act); act();
      }
      if (c.sug) {
        if (el.tagName === "INPUT" && c.modo !== "agregar") {
          const dl = document.createElement("datalist"); dl.id = "dl-" + id;
          dl.innerHTML = c.sug.map((s) => `<option value="${s.replace(/"/g, "&quot;")}">`).join("");
          document.body.appendChild(dl); el.setAttribute("list", dl.id);
        } else {
          const chips = document.createElement("div"); chips.className = "sugerencias";
          chips.innerHTML = '<small>Sugerencias:</small>' + c.sug.map((s) => `<button type="button">${s}</button>`).join("");
          chips.querySelectorAll("button").forEach((b) => b.addEventListener("click", () => {
            if (c.modo === "agregar") {
              const partes = el.value.split(",").map((x) => x.trim()).filter(Boolean);
              if (!partes.includes(b.textContent)) partes.push(b.textContent);
              el.value = partes.join(", ");
            } else el.value = b.textContent;
            el.dispatchEvent(new Event("input")); el.focus();
          }));
          linea.insertAdjacentElement("afterend", chips);
        }
      }
    });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", aplicar); else aplicar();
  window.addEventListener("load", aplicar);
})();
