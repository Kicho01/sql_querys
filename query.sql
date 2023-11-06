--
---DDL---
--
CREATE TABLE IF NOT EXISTS peces (
    id_pez SERIAL NOT NULL PRIMARY KEY,
    nombre VARCHAR,
    especie VARCHAR
);

CREATE TABLE IF NOT EXISTS tanques (
    id_tanque SERIAL NOT NULL PRIMARY KEY,
    id_pez INTEGER NOT NULL,
    capacidad INTEGER,
    temperatura INTEGER,
    nombre VARCHAR,
    FOREIGN KEY(id_pez) REFERENCES peces(id_pez)
);

CREATE TABLE IF NOT EXISTS cuidador (
    id_cuidador SERIAL NOT NULL PRIMARY KEY,
    nombre VARCHAR, 
    turno VARCHAR
);

CREATE TABLE IF NOT EXISTS alimentacion (
    id_alimentacion SERIAL UNIQUE NOT NULL PRIMARY KEY,
    id_pez INTEGER NOT NULL,
    tipo VARCHAR, 
    hora time,
    FOREIGN KEY(id_pez) REFERENCES peces(id_pez)
);

CREATE TABLE IF NOT EXISTS alimentacion_denegada (
    id_alimentacion_denegada SERIAL NOT NULL PRIMARY KEY,
    id_alimentacion INTEGER NOT NULL,
    razon VARCHAR,
    FOREIGN KEY(id_alimentacion) REFERENCES alimentacion(id_alimentacion)
);


--
-----A---
--
SELECT peces.nombre, peces.especie,
    (SELECT AVG(tanques.temperatura) FROM tanques JOIN peces USING(id_pez)) AS AVG
    FROM peces JOIN tanques USING(id_pez)
    WHERE tanques.temperatura = 9 ;


---usando clausula with

WITH promedio AS (SELECT AVG(tanques.temperatura) AS avg_temp FROM tanques JOIN peces USING(id_pez))

SELECT peces.nombre, peces.especie, avg_temp
    FROM peces JOIN tanques USING(id_pez), promedio
    WHERE tanques.temperatura = 9;


--usando FAV... aunque en este caso no se puede hacer por esta vía

SELECT peces.nombre, peces.especie, AVG(tanques.temperatura) OVER promedio
    FROM peces JOIN tanques USING(id_pez)
    WHERE tanques.temperatura = 9 
    WINDOW promedio AS (PARTITION BY tanques.id_pez)

--
---B---
--
insert into alimentacion (id_pez, tipo, hora) VALUES (20, 'gus', '09:20:10')
select * from alimentacion
select * from alimentacion_denegada

CREATE OR REPLACE FUNCTION alimentacion_valida () RETURNS TRIGGER
AS $$
    DECLARE
    especie_pez VARCHAR;
    BEGIN
        --se extrae la especie del pez segun el id insertado
		SELECT (SELECT peces.especie FROM peces WHERE peces.id_pez = NEW.id_pez) INTO especie_pez;

        IF (especie_pez = 'cetáceo' OR especie_pez = 'mamifero' OR especie_pez = 'Tiburon') THEN

            IF especie_pez = 'cetáceo' AND NEW.tipo <> 'planton' THEN
                INSERT INTO alimentacion_denegada (id_alimentacion, razon) VALUES(NEW.id_alimentacion, 'Tipo de alimento inválido');
                RETURN NULL;

            ELSIF especie_pez = 'mamifero' AND NEW.tipo <> 'peces pequeños y crustaceos' THEN
                INSERT INTO alimentacion_denegada (id_alimentacion, razon) VALUES(NEW.id_alimentacion, 'Tipo de alimento inválido');
                RETURN NULL;

            ELSIF especie_pez = 'Tiburon' AND NEW.tipo <> 'Todo' THEN
                INSERT INTO alimentacion_denegada (id_alimentacion, razon) VALUES(NEW.id_alimentacion, 'Tipo de alimento inválido');
                RETURN NULL;
            END IF;
        -- si no es un cetaceo, un mamifero o un tiburon se deniega el insert
        ELSE
            INSERT INTO alimentacion_denegada(id_alimentacion, razon) VALUES(NEW.id_alimentacion, 'Tipo de alimento inválido');
            RETURN NULL;
        END IF;
        -- si es valido el insert se registra
		RETURN NEW;
    END;
$$
LANGUAGE 'plpgsql';


CREATE OR REPLACE validar_alimentacion TRIGGER BEFORE INSERT ON alimentacion FOR EACH ROW EXECUTE PROCEDURE alimentacion_valida();

--
---C---
--

-- para probar la funcion SELECT * from generar_informe() as (nombre VARCHAR, tipo VARCHAR, hora time);

CREATE OR REPLACE FUNCTION generar_informe () RETURNS SETOF RECORD AS
$$

DECLARE
    -- crear variables auxiliares para trabajar con el cursor y comparar si esta repetida la alimentacion
    aux_cursor RECORD;
    aux_to_compare RECORD;
    -- crear el cursor
    cur CURSOR FOR (SELECT peces.nombre, alimentacion.tipo, alimentacion.hora
        FROM tanques JOIN peces USING(id_pez) JOIN alimentacion USING(id_pez)
        WHERE tanques.nombre = 'Protección' ORDER BY alimentacion.tipo, alimentacion.hora )
		FOR UPDATE;

BEGIN
    -- se abre el cursor
    OPEN cur;
    -- se avanza un paso en el cursor para poder inicializar aux_to_compare
	FETCH FROM cur INTO aux_cursor;
	aux_to_compare := aux_cursor;
	RETURN NEXT aux_cursor;
    LOOP
        FETCH FROM cur INTO aux_cursor;
        EXIT WHEN NOT FOUND;
        -- se realiza la comparacion para eliminar repeticiones
		IF aux_cursor.tipo <> aux_to_compare.tipo AND aux_cursor.hora <> aux_to_compare.hora THEN
			aux_to_compare := aux_cursor;
			RETURN NEXT aux_cursor;
		ELSE 
         -- se elimina de la tabla alimentacion la fila correspondiente
			DELETE FROM alimentacion WHERE CURRENT OF cur;
		END IF;
    END LOOP;

    CLOSE cur;

END;
$$
LANGUAGE 'plpgsql';

---
---D---
---

-- crear los roles
CREATE ROLE cuidador_acuario;
CREATE ROLE administrador_acuario;

-- dar permisos
GRANT SELECT, INSERT ON peces, alimentacion TO cuidador_acuario;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA PUBLIC TO administrador_acuario

--eliminar rol
DROP ROLE administrador_acuario;
