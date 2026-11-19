// =====================================================================
// Botón «Mostrar / Ocultar campos BD» (común a TODAS las pantallas).
// Las etiquetas moradas  <span class="bd">tabla.columna</span>, los bloques técnicos
// (.bd-bloque: chips GRABA/CONSULTA, orden de la transacción) y las trazas de COMMIT
// (.bd-traza) se ven solo en «modo sustentación». El cliente ve la pantalla limpia.
// La elección se recuerda al cambiar de pantalla (localStorage del navegador).
// Se carga en el <head> para que la página no "parpadee" al abrir.
// =====================================================================
(function () {
  var CLAVE = "mm-ver-campos-bd";
  var ver = false;                                   // por defecto: oculto (vista del cliente)
  try { ver = localStorage.getItem(CLAVE) === "1"; } catch (e) { /* navegador sin almacenamiento */ }
  var raiz = document.documentElement;

  function aplicar() {
    raiz.classList.toggle("sin-bd", !ver);
    var b = document.getElementById("toggle-bd");
    if (b) {
      b.innerHTML = (ver ? "&#128065; Ocultar campos BD" : "&#128065; Mostrar campos BD");
      b.classList.toggle("activo", ver);
      b.setAttribute("aria-pressed", String(ver));
      b.title = "Muestra de qué tabla.columna de SQL Server sale cada campo (para el profesor)";
    }
  }
  aplicar();

  document.addEventListener("DOMContentLoaded", function () {
    var b = document.getElementById("toggle-bd");
    if (!b) {
      b = document.createElement("button");
      b.id = "toggle-bd"; b.type = "button"; b.className = "toggle-bd";
      document.body.appendChild(b);
    }
    b.addEventListener("click", function () {
      ver = !ver;
      try { localStorage.setItem(CLAVE, ver ? "1" : "0"); } catch (e) { /* sin almacenamiento: solo esta pantalla */ }
      aplicar();
    });
    aplicar();
  });
})();
