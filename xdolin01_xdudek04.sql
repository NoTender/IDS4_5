--IDS Projekt 3
-- xdudek04
-- xdolin01 

-- Odstraneni tabulek
DROP TABLE Druh CASCADE CONSTRAINTS;
DROP TABLE Zivocich CASCADE CONSTRAINTS;
DROP TABLE Mereni CASCADE CONSTRAINTS;
DROP TABLE Osetrovatel CASCADE CONSTRAINTS;
DROP TABLE Osetrovatel_oddeleni CASCADE CONSTRAINTS;
DROP TABLE Oddeleni CASCADE CONSTRAINTS;
DROP TABLE Druh_oddeleni CASCADE CONSTRAINTS;
DROP TABLE Samice CASCADE CONSTRAINTS;
DROP SEQUENCE zivocich_id_seq;
DROP INDEX ind_druh;
set serveroutput on;

-- Vytvoreni tabulek
CREATE TABLE Druh (
	id_druhu INTEGER PRIMARY KEY,
	druh NVARCHAR2(100),
	rod NVARCHAR2(100),
	celed NVARCHAR2(100),
	rad NVARCHAR2(100),
	trida NVARCHAR2(100)
);

CREATE TABLE Zivocich (
	id_zivocicha INTEGER PRIMARY KEY,
	id_druhu INTEGER NOT NULL,
	id_oddeleni INTEGER NOT NULL,
	jmeno NVARCHAR2(100),
	dat_narozeni DATE,
	dat_umrti DATE
);

CREATE TABLE Mereni (
	id_mereni INTEGER PRIMARY KEY,
	id_zivocicha INTEGER NOT NULL,
	rodne_cislo NVARCHAR2(10) NOT NULL,
	dat_mereni DATE,
	hmotnost FLOAT(10),
	vyska FLOAT(10),
	delka FLOAT(10)
);

CREATE TABLE Osetrovatel (
	rodne_cislo NVARCHAR2(10) PRIMARY KEY,
	jmeno NVARCHAR2(100),
	prijmeni NVARCHAR2(100),
	mesto NVARCHAR2(100),
	ulice NVARCHAR2(100),
	psc NVARCHAR2(10),
	telefon NVARCHAR2(20)
);

CREATE TABLE Osetrovatel_oddeleni (
	id_oddeleni INTEGER NOT NULL,
	rodne_cislo NVARCHAR2(10) NOT NULL
);

CREATE TABLE Oddeleni (
	id_oddeleni INTEGER PRIMARY KEY,
	typ_umisteni NVARCHAR2(100),
	nazev NVARCHAR2(100)
);

CREATE TABLE Druh_oddeleni (
	id_druhu INTEGER NOT	NULL,
	id_oddeleni INTEGER NOT NULL
);

CREATE TABLE Samice (
	id_zivocicha INTEGER NOT NULL,
	pocet_vrhu INTEGER
);

-- Integritni omezeni, cizi klice
ALTER TABLE Zivocich ADD(
	CONSTRAINT fk_zivocich_druh
		FOREIGN KEY (id_druhu)
		REFERENCES Druh,
	CONSTRAINT fk_zivocich_oddeleni
		FOREIGN KEY (id_oddeleni)
		REFERENCES Oddeleni
);

ALTER TABLE Mereni ADD(
	CONSTRAINT fk_mereni_zivocich
		FOREIGN KEY (id_zivocicha)
		REFERENCES Zivocich,
	CONSTRAINT fk_mereni_osetrovatel
		FOREIGN KEY (rodne_cislo)
		REFERENCES Osetrovatel
);

ALTER TABLE Osetrovatel_oddeleni ADD(
	CONSTRAINT pk_os_odd
		PRIMARY KEY (id_oddeleni, rodne_cislo),
	CONSTRAINT fk_os_odd_oddeleni
		FOREIGN KEY (id_oddeleni)
		REFERENCES Oddeleni,
	CONSTRAINT fk_os_odd_osetrovatel
		FOREIGN KEY (rodne_cislo)
		REFERENCES Osetrovatel
);

ALTER TABLE Druh_oddeleni ADD(
	CONSTRAINT pk_dr_odd
		PRIMARY KEY (id_druhu, id_oddeleni),
	CONSTRAINT fk_dr_odd_druh
		FOREIGN KEY (id_druhu)
		REFERENCES Druh,
	CONSTRAINT fk_dr_odd_oddeleni
		FOREIGN KEY (id_oddeleni)
		REFERENCES Oddeleni
);

ALTER TABLE Samice ADD(
	CONSTRAINT pk_sam
		PRIMARY KEY (id_zivocicha),
	CONSTRAINT fk_samice_zivocich
		FOREIGN KEY (id_zivocicha)
		REFERENCES Zivocich
);

-- Dalsi integritni omezeni
ALTER TABLE Zivocich
	ADD CONSTRAINT chck_datum_nar_umr
	CHECK (dat_narozeni <= dat_umrti);

-- TRIIGER 1 - Auto-inkrementace primarniho klice
CREATE SEQUENCE zivocich_id_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER auto_inc_zivocich 
BEFORE INSERT ON Zivocich
FOR EACH ROW

BEGIN
	IF (:new.id_zivocicha IS NULL) THEN
		SELECT zivocich_id_seq.nextval
		INTO :new.id_zivocicha
		FROM dual;
	END IF;
END;
/

-- TRIGGER 2
CREATE OR REPLACE TRIGGER overeni_rc BEFORE INSERT OR UPDATE ON Osetrovatel --trigger pro overeni rodneho cisla
FOR EACH ROW 
DECLARE 
	rok INTEGER; 
	mesic INTEGER; 
	den INTEGER;
	datum DATE;
BEGIN
	IF REGEXP_LIKE(:new.rodne_cislo, '^[0-9]{9,10}$') THEN  --overeni, zda obsahuje pouze 10 nebo 9 cislic
		den := CAST(SUBSTR(:new.rodne_cislo, 5, 2) AS INTEGER); --prevedeni dne, mesice a roku z rodneho cisla na cislo
		mesic := CAST(SUBSTR(:new.rodne_cislo, 3, 2) AS INTEGER);
		rok := CAST(SUBSTR(:new.rodne_cislo, 1, 2) AS INTEGER);

		IF (MOD(CAST(:new.rodne_cislo AS INTEGER),11) = 0) AND ((mesic BETWEEN 1 AND 12) OR (mesic BETWEEN 51 AND 62) OR (mesic BETWEEN 21 AND 32) OR (mesic BETWEEN 71 AND 82)) AND (den BETWEEN 1 AND 31) THEN -- naroky na delitelnost a rozsah hodnot
			
			IF (LENGTH(:new.rodne_cislo) = 9 AND SUBSTR(:new.rodne_cislo, 7, 3) = '000') THEN --devitimistne rodne cislo nesmi mit koncovku 000
				RAISE_APPLICATION_ERROR(-20055, 'Zadane rodne cislo '||:new.rodne_cislo||' je neplatne.');
			END IF;

			IF (mesic BETWEEN 51 AND 62) THEN
				mesic := mesic - 50;
			END IF;

			IF (mesic BETWEEN 21 AND 32) THEN
				mesic := mesic - 20;
			END IF;

			IF (mesic BETWEEN 71 AND 82) THEN
				mesic := mesic - 70;
			END IF;

			BEGIN --overeni platneho datumu v rodnem cislu
				datum := den||'.'||mesic||'.'||rok;
					EXCEPTION WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20055, 'Zadane rodne cislo '||:new.rodne_cislo||' je neplatne.');
			END;
		ELSE
			RAISE_APPLICATION_ERROR(-20055, 'Zadane rodne cislo '||:new.rodne_cislo||' je neplatne.');
		END IF;	    
	ELSE 
		RAISE_APPLICATION_ERROR(-20055, 'Zadane rodne cislo '||:new.rodne_cislo||' je neplatne.');
	END IF; 

END;
/

-- Procedura vyuzivajici kurzor a promennou s datovym typem odkazujicim se na typ sloupce tabulky
-- Vstupnim parametrem je nazev mesta, procedura nasledne vypise vsechny osetrovatele z tohoto mesta a kdy se narodili.
CREATE OR REPLACE PROCEDURE zobraz_osetrovatele_z_mesta (pr_mesto Osetrovatel.mesto%TYPE) AS
BEGIN
	DECLARE
		jm NVARCHAR2(100);
		pr NVARCHAR2(100);
		rc NVARCHAR2(10);
		mesic INTEGER;
		rok INTEGER;

		CURSOR osetrovatel_z_mesta IS
			SELECT jmeno, prijmeni, rodne_cislo
			FROM Osetrovatel
			WHERE Osetrovatel.mesto = zobraz_osetrovatele_z_mesta.pr_mesto;

	BEGIN
		dbms_output.put_line('Datumy narozeni osetrovatelu z mesta '||zobraz_osetrovatele_z_mesta.pr_mesto||':');
		OPEN osetrovatel_z_mesta;
		LOOP
			FETCH osetrovatel_z_mesta INTO jm, pr, rc;
			EXIT WHEN osetrovatel_z_mesta%NOTFOUND;
			mesic := CAST(SUBSTR(rc, 3, 2) AS INTEGER);
			rok := CAST(SUBSTR(rc, 1, 2) AS INTEGER);
			IF ((rok < 54) AND (LENGTH(rc) = 10)) THEN
				rok := rok + 2000;
			ELSE
				rok := rok + 1900;
			END IF;
			IF (mesic BETWEEN 51 AND 62) THEN
				mesic := mesic - 50;
			END IF;

			IF (mesic BETWEEN 21 AND 32) THEN
				mesic := mesic - 20;
			END IF;
			IF (mesic BETWEEN 71 AND 82) THEN
				mesic := mesic - 70;
			END IF;
			dbms_output.put_line(jm||' '||pr||' se narodil(a) '||SUBSTR(rc, 5, 2)||'.'||mesic||'.'||rok);
		END LOOP;
		CLOSE osetrovatel_z_mesta;
	END;
END;
/

-- Procedura vyuzivajici vyvolani vyjimky
-- Procedura aktualizuje adresu osetrovatele na zaklade rodneho cisla. Pokud zadane rodne cislo neexistuje nebo je zadano jako null, skonci program vlastni
-- definovanou vyjimkou.
CREATE OR REPLACE PROCEDURE update_adresa (rc Osetrovatel.rodne_cislo%type, pr_mesto Osetrovatel.mesto%type, pr_ulice Osetrovatel.ulice%type, pr_psc Osetrovatel.psc%type) AS
BEGIN
	DECLARE
		exc_null EXCEPTION;
		exc_no_data_found EXCEPTION;
		cnt NUMBER;

	BEGIN
		IF (update_adresa.rc IS NULL) THEN
			RAISE exc_null;
		END IF;

		SELECT COUNT(*) INTO cnt FROM Osetrovatel WHERE Osetrovatel.rodne_cislo = update_adresa.rc;

		IF (cnt = 0) THEN
			RAISE exc_no_data_found;
		END IF;

		UPDATE Osetrovatel
		SET Osetrovatel.mesto=update_adresa.pr_mesto, Osetrovatel.ulice=update_adresa.pr_ulice, Osetrovatel.psc=update_adresa.pr_psc
		WHERE Osetrovatel.rodne_cislo=update_adresa.rc;

	EXCEPTION
		WHEN exc_null THEN RAISE_APPLICATION_ERROR(-20369, 'Zadano NULL misto rodneho cisla!');
		WHEN exc_no_data_found THEN RAISE_APPLICATION_ERROR(-20666, 'Zadane rodne cislo neexistuje!');
	END;

END;
/

-- Vlozeni dat
INSERT INTO Druh VALUES(0, 'Pruhohrbety', 'Kockodan', 'kockodanoviti', 'primati', 'savci');
INSERT INTO Druh VALUES(1, 'Bezoarova', 'Koza', 'turoviti', 'sudokopytnici', 'savci');
INSERT INTO Druh VALUES(2, 'Ararauna', 'Ara', 'papouskoviti', 'papousci', 'ptaci');
INSERT INTO Druh VALUES(3, 'Armatus', 'Stegosaurus', 'stegosauridae', 'ptakopanvi', 'plazi');

INSERT INTO Oddeleni VALUES(0, 'terarium', 'Terarium A');
INSERT INTO Oddeleni VALUES(1, 'vybeh', 'Vybeh A');
INSERT INTO Oddeleni VALUES(2, 'klec', 'Klec A');

INSERT INTO Osetrovatel VALUES('9154193356', 'Jindrich', 'Dudek', 'Policka', 'Kozlova', '79022', '777555666');
INSERT INTO Osetrovatel VALUES('9512235062', 'Milos', 'Dolinsky', 'Vidnava', 'Besthovni', '79055', '789444555');
INSERT INTO Osetrovatel VALUES('9001089075', 'Joey', 'Shabadoo', 'Brno', 'Purkynova', '79021', '584845654');

INSERT INTO Zivocich VALUES(NULL, 0, 0, 'Chose', TO_DATE('02.02.2015', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 0, 1, 'Luda', TO_DATE('02.02.1933', 'dd.mm.yyyy'), TO_DATE('04.05.1950', 'dd.mm.yyyy'));
INSERT INTO Zivocich VALUES(NULL, 1, 0, 'Liza', TO_DATE('04.12.2004', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 2, 2, 'Citrus', TO_DATE('15.03.2012', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 3, 1, 'Karel', TO_DATE('01.01.2000', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 0, 1, 'Edmund', TO_DATE('02.02.2015', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 0, 1, 'Lojza', TO_DATE('02.02.2015', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 0, 2, 'Clint', TO_DATE('02.02.2015', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 0, 2, 'JoshRobertson', TO_DATE('02.02.2015', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 1, 0, 'Giza', TO_DATE('04.12.2004', 'dd.mm.yyyy'), NULL);
INSERT INTO Zivocich VALUES(NULL, 1, 0, 'Bezina', TO_DATE('04.12.2004', 'dd.mm.yyyy'), NULL);

INSERT INTO Samice VALUES(3, 42);

INSERT INTO Mereni VALUES(0, 1, '9154193356', TO_DATE('04.02.2015', 'dd.mm.yyyy'), 20.2, 50.1, 150.1);
INSERT INTO Mereni VALUES(1, 1, '9512235062', TO_DATE('13.07.2015', 'dd.mm.yyyy'), 18.21, 52.0, 142.2);
INSERT INTO Mereni VALUES(2, 3, '9512235062', TO_DATE('05.02.2015', 'dd.mm.yyyy'), 5.0, 31.6, 50.3);
INSERT INTO Mereni VALUES(3, 5, '9154193356', TO_DATE('28.09.2001', 'dd.mm.yyyy'), 1924.49, 5.2, 502.3);

INSERT INTO Osetrovatel_oddeleni VALUES(0, '9001089075');
INSERT INTO Osetrovatel_oddeleni VALUES(1, '9001089075');
INSERT INTO Osetrovatel_oddeleni VALUES(1, '9512235062');
INSERT INTO Osetrovatel_oddeleni VALUES(0, '9512235062');
INSERT INTO Osetrovatel_oddeleni VALUES(2, '9512235062');

INSERT INTO Druh_oddeleni VALUES(0, 0);
INSERT INTO Druh_oddeleni VALUES(1, 1);
INSERT INTO Druh_oddeleni VALUES(2, 0);
INSERT INTO Druh_oddeleni VALUES(3, 2);
INSERT INTO Druh_oddeleni VALUES(0, 1);

CALL zobraz_osetrovatele_z_mesta('Policka'); -- Ukazka 1. procedury

CALL update_adresa(NULL, 'New York', 'Skacelova', '79999'); -- Ukazka 2. procedury -> vypise chybu na zaklade vyjimky
CALL update_adresa('999999999', 'New York', 'Skacelova', '79999'); -- Ukazka 2. procedury -> vypise chybu na zaklade vyjimky
CALL update_adresa('9001089075', 'New York', 'Skacelova', '79999'); -- Ukazka 2. procedury -> zaznam se upravi

EXPLAIN PLAN FOR
	SELECT D.id_druhu, D.rod, COUNT(*) pocet
	FROM Druh D, Zivocich Z
	WHERE D.id_druhu = Z.id_druhu AND D.trida = 'savci'
	GROUP BY D.id_druhu, D.rod;

SELECT PLAN_TABLE_OUTPUT FROM TABLE(dbms_xplan.display);

CREATE INDEX ind_druh ON Druh (id_druhu, trida, rod);

EXPLAIN PLAN FOR
	FROM Druh D, Zivocich Z
	WHERE D.id_druhu = Z.id_druhu AND D.trida = 'savci'
	GROUP BY D.id_druhu, D.rod;

SELECT PLAN_TABLE_OUTPUT FROM TABLE(dbms_xplan.display);
-- SQL dotazy
/*
-- **Dva dotazy vyuzivajici spojeni dvou tabulek**
-- Dotaz vypise vsechny mereni, ktere provedl osetrovatel jmenem Jindrich a prijmenim Dudek
SELECT M.id_mereni, M.id_zivocicha, M.dat_mereni, M.hmotnost, M.vyska, M.delka
FROM Mereni M, Osetrovatel O
WHERE M.rodne_cislo = O.rodne_cislo AND O.prijmeni = 'Dudek' AND O.jmeno = 'Jindrich';
-- Dotaz vypise vsechny konkretni zivocichy, kteri spadaji pod rod Kockodan
SELECT Z.id_zivocicha, Z.id_oddeleni, Z.jmeno, Z.dat_narozeni, Z.dat_umrti
FROM Zivocich Z, Druh D
WHERE Z.id_druhu = D.id_druhu AND D.rod = 'Kockodan';

-- **Dotaz vyuzivajici spojeni tri tabulek
-- Dotaz vypise vsechny zivocichy rodu Stegosaurus zijici ve vybehu
SELECT Z.id_zivocicha, Z.id_oddeleni, Z.jmeno, Z.dat_narozeni, Z.dat_umrti
FROM Zivocich Z, Oddeleni O, Druh D
WHERE Z.id_druhu = D.id_druhu AND Z.id_oddeleni = O.id_oddeleni AND O.typ_umisteni = 'vybeh' AND D.rod = 'Stegosaurus';

-- **Dotaz s klauzuli  GROUP BY a agregacni funkci
-- Dotaz vypise, kolik zvirat obsahuji jednotlive oddeleni
SELECT O.id_oddeleni, O.nazev, COUNT(*) pocet
FROM Oddeleni O, Zivocich Z
WHERE O.id_oddeleni = Z.id_oddeleni
GROUP BY O.id_oddeleni, O.nazev;
-- Dotaz vypise, kolik mereni provedli jednotlivi osetrovatele (Nezobrazi osetrovatele, kteri neprovedli zadne mereni)
SELECT O.rodne_cislo, O.jmeno, O.prijmeni, COUNT(*) pocet
FROM Osetrovatel O, Mereni M
WHERE O.rodne_cislo = M.rodne_cislo
GROUP BY O.rodne_cislo, O.jmeno, O.prijmeni;

-- **Dotaz s predikatem IN s vnorenym selectem
-- Dotaz vypise zivocichy, kteri podstoupili v roce 2015 mereni
SELECT *
FROM Zivocich
WHERE id_zivocicha IN
	(SELECT id_zivocicha
	FROM Mereni
	WHERE dat_mereni BETWEEN '01.01.2015' AND '31.12.2015');

-- **Dotaz obsahujici predikat EXISTS
-- Dotaz vypise vsechny osetrovatele, kteri nekdy provedli nejake mereni a zaroven maji na starosti nejake oddeleni
SELECT DISTINCT O.*
FROM Osetrovatel O, Mereni M
WHERE O.rodne_cislo = M.rodne_cislo AND
EXISTS (SELECT *
	FROM Oddeleni D, Osetrovatel_oddeleni OD
	WHERE O.rodne_cislo = OD.rodne_cislo AND OD.id_oddeleni = D.id_oddeleni);
	*/