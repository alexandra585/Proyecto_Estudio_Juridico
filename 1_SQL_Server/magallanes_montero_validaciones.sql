-- =====================================================================
-- VALIDACIONES DE FORMATO (CHECK) · PERSONA, EMPLEADO, CONSULTA y CASO
-- Base: magallanes_montero_prueba36 · Ejecutar en SSMS con F5 (se puede ejecutar varias veces).
--
-- Reglas (Perú):
--   DNI 8 dígitos · RUC 11 dígitos que empiezan con 10 o 20 · CE 9 a 12 dígitos · Pasaporte 6 a 12 letras/números
--   Celular: exactamente 9 dígitos que empiezan con 9
--   Nombres y apellidos: solo letras (con tildes y ñ), espacios, apóstrofo y guion; mínimo 2 caracteres
--   Correo: nombre@dominio.ext sin espacios · Razón social: mínimo 3 caracteres
--   Relato de la consulta: mínimo 15 caracteres · Código interno del caso: EXP-AAAA-NNNN
--
-- SQL Server no tiene expresiones regulares en CHECK: se usa LIKE con clases de caracteres.
--   nro_documento NOT LIKE '%[^0-9]%'  → «no contiene ningún carácter que NO sea dígito» = solo dígitos.
--
-- Cada regla primero CUENTA las filas que ya existen y no la cumplen:
--   0 filas  → ALTER TABLE ... WITH CHECK   (la regla se aplica a todo y SQL Server la marca como confiable)
--   1 o más  → ALTER TABLE ... WITH NOCHECK (la regla se aplica a los datos NUEVOS; las filas antiguas se listan al final
--              para corregirlas, y luego se vuelve a ejecutar este script)
-- =====================================================================
USE magallanes_montero_prueba36;
GO

DECLARE @reglas TABLE (orden INT IDENTITY, tabla SYSNAME, nombre SYSNAME, expresion NVARCHAR(MAX), descripcion NVARCHAR(200));

INSERT INTO @reglas (tabla, nombre, expresion, descripcion) VALUES
(N'persona', N'ck_persona_nro_documento_formato', N'nro_documento IS NULL
   OR (tipo_documento = ''DNI''       AND LEN(nro_documento) = 8  AND nro_documento NOT LIKE ''%[^0-9]%'')
   OR (tipo_documento = ''RUC''       AND LEN(nro_documento) = 11 AND nro_documento NOT LIKE ''%[^0-9]%'' AND LEFT(nro_documento, 2) IN (''10'', ''20''))
   OR (tipo_documento = ''CE''        AND LEN(nro_documento) BETWEEN 9 AND 12 AND nro_documento NOT LIKE ''%[^0-9]%'')
   OR (tipo_documento = ''PASAPORTE'' AND LEN(nro_documento) BETWEEN 6 AND 12 AND nro_documento NOT LIKE ''%[^A-Za-z0-9]%'')',
   N'DNI 8 dígitos · RUC 11 (10/20) · CE 9-12 dígitos · Pasaporte 6-12 letras/números'),
(N'persona', N'ck_persona_telefono_formato', N'telefono IS NULL
   OR (LEN(telefono) = 9 AND telefono LIKE ''9%'' AND telefono NOT LIKE ''%[^0-9]%'')',
   N'Celular: exactamente 9 dígitos empezando en 9'),
(N'persona', N'ck_persona_email_formato', N'email IS NULL
   OR (email LIKE ''%_@_%._%'' AND email NOT LIKE ''% %'' AND email NOT LIKE ''%@%@%'' AND email NOT LIKE ''%..%'')',
   N'Correo con formato nombre@dominio.ext'),
(N'persona', N'ck_persona_nombres_formato', N'nombres IS NULL
   OR (LEN(LTRIM(RTRIM(nombres))) >= 2 AND nombres NOT LIKE N''%[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'''' -]%'')',
   N'Nombres: solo letras, espacios, apóstrofo y guion (mín. 2)'),
(N'persona', N'ck_persona_apellidos_formato', N'apellidos IS NULL
   OR (LEN(LTRIM(RTRIM(apellidos))) >= 2 AND apellidos NOT LIKE N''%[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'''' -]%'')',
   N'Apellidos: solo letras, espacios, apóstrofo y guion (mín. 2)'),
(N'persona', N'ck_persona_razon_social_longitud', N'razon_social IS NULL OR LEN(LTRIM(RTRIM(razon_social))) >= 3',
   N'Razón social: mínimo 3 caracteres'),
(N'empleado', N'ck_empleado_dni_formato', N'dni NOT LIKE ''%[^0-9]%''', N'DNI del empleado: 8 dígitos'),
(N'empleado', N'ck_empleado_telefono_formato', N'telefono IS NULL
   OR (LEN(telefono) = 9 AND telefono LIKE ''9%'' AND telefono NOT LIKE ''%[^0-9]%'')',
   N'Celular del empleado: 9 dígitos empezando en 9'),
(N'empleado', N'ck_empleado_email_formato', N'email LIKE ''%_@_%._%'' AND email NOT LIKE ''% %'' AND email NOT LIKE ''%@%@%''',
   N'Correo del empleado con formato válido'),
(N'empleado', N'ck_empleado_nombres_formato', N'LEN(LTRIM(RTRIM(nombres))) >= 2 AND nombres NOT LIKE N''%[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'''' -]%''
   AND LEN(LTRIM(RTRIM(apellidos))) >= 2 AND apellidos NOT LIKE N''%[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'''' -]%''',
   N'Nombres y apellidos del empleado: solo letras'),
(N'consulta', N'ck_consulta_resumen_minimo', N'LEN(LTRIM(RTRIM(resumen))) >= 15', N'Relato de la consulta: mínimo 15 caracteres'),
(N'caso', N'ck_caso_codigo_interno_formato', N'codigo_interno LIKE ''EXP-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]''',
   N'Código interno: EXP-AAAA-NNNN');

DECLARE @resultado TABLE (tabla SYSNAME, regla SYSNAME, descripcion NVARCHAR(200), filas_que_no_cumplen INT, aplicada_como NVARCHAR(40));
DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @reglas), @tabla SYSNAME, @nombre SYSNAME, @expr NVARCHAR(MAX),
        @desc NVARCHAR(200), @sql NVARCHAR(MAX), @malas INT;

WHILE @i <= @n
BEGIN
    SELECT @tabla = tabla, @nombre = nombre, @expr = expresion, @desc = descripcion FROM @reglas WHERE orden = @i;

    IF OBJECT_ID(N'dbo.' + @nombre, N'C') IS NOT NULL                       -- si ya existe, se reemplaza
        EXEC (N'ALTER TABLE dbo.' + @tabla + N' DROP CONSTRAINT ' + @nombre);

    SET @sql = N'SELECT @c = COUNT(*) FROM dbo.' + @tabla + N' WHERE NOT (' + @expr + N')';
    EXEC sp_executesql @sql, N'@c INT OUTPUT', @c = @malas OUTPUT;

    SET @sql = N'ALTER TABLE dbo.' + @tabla + CASE WHEN @malas = 0 THEN N' WITH CHECK' ELSE N' WITH NOCHECK' END
             + N' ADD CONSTRAINT ' + @nombre + N' CHECK (' + @expr + N')';
    EXEC (@sql);

    INSERT INTO @resultado VALUES (@tabla, @nombre, @desc, @malas,
        CASE WHEN @malas = 0 THEN N'WITH CHECK (todas las filas)' ELSE N'WITH NOCHECK (solo datos nuevos)' END);
    SET @i += 1;
END;

SELECT * FROM @resultado ORDER BY tabla, regla;
GO

-- Filas antiguas que no cumplen (para corregirlas a mano y volver a ejecutar el script)
SELECT 'persona' AS tabla, id_persona AS id, tipo_documento, nro_documento, nombres, apellidos, razon_social, telefono, email
FROM dbo.persona
WHERE NOT (nro_documento IS NULL
   OR (tipo_documento = 'DNI'       AND LEN(nro_documento) = 8  AND nro_documento NOT LIKE '%[^0-9]%')
   OR (tipo_documento = 'RUC'       AND LEN(nro_documento) = 11 AND nro_documento NOT LIKE '%[^0-9]%' AND LEFT(nro_documento, 2) IN ('10', '20'))
   OR (tipo_documento = 'CE'        AND LEN(nro_documento) BETWEEN 9 AND 12 AND nro_documento NOT LIKE '%[^0-9]%')
   OR (tipo_documento = 'PASAPORTE' AND LEN(nro_documento) BETWEEN 6 AND 12 AND nro_documento NOT LIKE '%[^A-Za-z0-9]%'))
   OR NOT (telefono IS NULL
   OR (LEN(telefono) = 9 AND telefono LIKE '9%' AND telefono NOT LIKE '%[^0-9]%'))
   OR NOT (nombres IS NULL OR (LEN(LTRIM(RTRIM(nombres))) >= 2 AND nombres NOT LIKE N'%[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'' -]%'))
   OR NOT (apellidos IS NULL OR (LEN(LTRIM(RTRIM(apellidos))) >= 2 AND apellidos NOT LIKE N'%[^a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'' -]%'))
   OR NOT (email IS NULL OR (email LIKE '%_@_%._%' AND email NOT LIKE '% %' AND email NOT LIKE '%@%@%' AND email NOT LIKE '%..%'));
GO

-- Prueba (con ROLLBACK, no cambia nada): este INSERT debe FALLAR por ck_persona_nro_documento_formato
BEGIN TRAN;
BEGIN TRY
    INSERT INTO dbo.persona (tipo_persona, tipo_documento, nro_documento, nombres, apellidos, telefono)
    VALUES ('NATURAL', 'DNI', '12AB5678', N'Prueba', N'Validación', '987654321');
    PRINT 'ERROR: el CHECK no detuvo el DNI con letras';
END TRY
BEGIN CATCH
    PRINT 'OK, SQL Server rechazó el DNI con letras: ' + ERROR_MESSAGE();
END CATCH;
ROLLBACK;
GO
