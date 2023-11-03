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
    (SELECT AVG(tanques.temperatura) FROM tanques JOIN peces USING(ID_tanque) WHERE peces.especie = 'cetáceo' ) AS AVG
    FROM peces JOIN tanques USING(ID_tanque)
    WHERE tanques.temperatura = 50 ;


---usando clausula with

WITH AVG AS (SELECT ID_tanque, AVG(tanques.temperatura) AS avg_temp FROM tanques JOIN peces USING(ID_tanque) WHERE peces.especie = 'cetáceo')

SELECT peces.nombre, peces.especie, avg_temp
    FROM peces JOIN tanques USING(ID_tanque) JOIN AVG USING(ID_tanque)
    WHERE tanques.temperatura = 50;


--usando FAV

SELECT peces.nombre, peces.especie, AVG(tanques.temperatura) OVER (PARTITION BY especie)
    FROM peces JOIN tanques USING(ID_tanque)
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

CREATE OR REPLACE FUNCTION generar_informe () RETURNS SETOF AS
$$

DECLARE

aux RECORD;
cur CURSOR FOR (SELECT peces.nombre, alimentacion.tipo, alimentacion.hora
    FROM peces JOIN tanques USIN(ID_tanque) JOIN alimentacion USING(ID_pez)
    WHERE tanque.nombre = 'Protección');

BEGIN

LOOP
    FETCH FROM cur INTO aux;
    EXIT WHEN NOT FOUND;
        RETURN NEXT aux;
END LOOP;

close cur;

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
