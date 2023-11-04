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
    id_alimentacion SERIAL NOT NULL PRIMARY KEY,
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
    (SELECT AVG(tanques.temperatura) FROM tanques JOIN peces USING(id_pez) WHERE peces.especie = 'cetáceo' ) AS AVG
    FROM peces JOIN tanques USING(id_pez)
    WHERE tanques.temperatura = 50 ;


---usando clausula with

WITH AVG AS (SELECT id_pez, AVG(tanques.temperatura) AS avg_temp FROM tanques JOIN peces USING(id_pez) WHERE peces.especie = 'cetáceo')

SELECT peces.nombre, peces.especie, avg_temp
    FROM peces JOIN tanques USING(id_pez) JOIN AVgit G USING(id_pez)
    WHERE tanques.temperatura = 50;


--usando FAV

SELECT peces.nombre, peces.especie, AVG(tanques.temperatura) OVER (PARTITION BY especie)
    FROM peces JOIN tanques USING(id_pez)
    WHERE tanques.temperatura = 50 ;

--
---B---
--

CREATE OR REPLACE FUNCTION alimentacion_valida () RETURNS TRIGGER
AS $$
    BEGIN
        IF NEW.especie = cetáceo AND NEW.tipo <> 'planton' THEN
            INSERT INTO alimentacion_denegada values(NEW.ID_alimentacion, 'Tipo de alimento inválido');
            RETURN NULL;
        END IF;

        IF NEW.especie = mamifero AND NEW.tipo <> 'peces pequeños y crustaceos' THEN
            INSERT INTO alimentacion_denegada values(NEW.ID_alimentacion, 'Tipo de alimento inválido');
            RETURN NULL;
        END IF;

        IF NEW.especie = tiburon AND NEW.tipo <> 'todo' THEN
            INSERT INTO alimentacion_denegada values(NEW.ID_alimentacion, 'Tipo de alimento inválido');
            RETURN NULL;
        END IF;
END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER validar_alimentacion BEFORE INSERT ON alimentacion FOR EACH ROW EXECUTE PROCEDURE alimentacion_valida();

--
---C---
--

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

--
---D---
---

CREATE ROLE cuidador_acuario;
CREATE ROLE administrador_acuario;

GRANT SELECT, INSERT ON peces, alimentacion TO cuidador_acuario;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA PUBLIC TO administrador_acuario
