-- 04_guacamole_setup.sql
-- Creation des groupes, connexions et utilisateurs dans Guacamole
-- A executer apres 03_guacamole.sh
-- mysql -u root < 04_guacamole_setup.sql

USE guacamole_db;

-- Groupes de connexions par Tier
INSERT INTO guacamole_connection_group (connection_group_name, type)
VALUES
    ('Tier 0 - Admins Domaine', 'ORGANIZATIONAL'),
    ('Tier 1 - Admins Serveurs', 'ORGANIZATIONAL'),
    ('Tier 2 - Utilisateurs', 'ORGANIZATIONAL');

-- Connexions par Tier
-- Tier 0 : acces aux DCs
INSERT INTO guacamole_connection (connection_name, parent_id, protocol)
VALUES
    ('DC-01', (SELECT connection_group_id FROM guacamole_connection_group WHERE connection_group_name = 'Tier 0 - Admins Domaine'), 'rdp'),
    ('DC-02', (SELECT connection_group_id FROM guacamole_connection_group WHERE connection_group_name = 'Tier 0 - Admins Domaine'), 'rdp');

-- Parametres DC-01
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'hostname', '10.30.0.200' FROM guacamole_connection WHERE connection_name = 'DC-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'port', '3389' FROM guacamole_connection WHERE connection_name = 'DC-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'domain', 'lospollos.local' FROM guacamole_connection WHERE connection_name = 'DC-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'security', 'any' FROM guacamole_connection WHERE connection_name = 'DC-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'ignore-cert', 'true' FROM guacamole_connection WHERE connection_name = 'DC-01';

-- Parametres DC-02
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'hostname', '10.30.0.201' FROM guacamole_connection WHERE connection_name = 'DC-02';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'port', '3389' FROM guacamole_connection WHERE connection_name = 'DC-02';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'domain', 'lospollos.local' FROM guacamole_connection WHERE connection_name = 'DC-02';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'security', 'any' FROM guacamole_connection WHERE connection_name = 'DC-02';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'ignore-cert', 'true' FROM guacamole_connection WHERE connection_name = 'DC-02';

-- Tier 1 : acces au SIEM
INSERT INTO guacamole_connection (connection_name, parent_id, protocol)
VALUES ('SIEM', (SELECT connection_group_id FROM guacamole_connection_group WHERE connection_group_name = 'Tier 1 - Admins Serveurs'), 'ssh');

INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'hostname', '10.30.0.220' FROM guacamole_connection WHERE connection_name = 'SIEM';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'port', '22' FROM guacamole_connection WHERE connection_name = 'SIEM';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'username', 'debian' FROM guacamole_connection WHERE connection_name = 'SIEM';

-- Tier 2 : acces a la workstation
INSERT INTO guacamole_connection (connection_name, parent_id, protocol)
VALUES ('WS-T2-01', (SELECT connection_group_id FROM guacamole_connection_group WHERE connection_group_name = 'Tier 2 - Utilisateurs'), 'rdp');

INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'hostname', '10.30.0.210' FROM guacamole_connection WHERE connection_name = 'WS-T2-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'port', '3389' FROM guacamole_connection WHERE connection_name = 'WS-T2-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'domain', 'lospollos.local' FROM guacamole_connection WHERE connection_name = 'WS-T2-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'security', 'any' FROM guacamole_connection WHERE connection_name = 'WS-T2-01';
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, 'ignore-cert', 'true' FROM guacamole_connection WHERE connection_name = 'WS-T2-01';

-- Creation des utilisateurs Guacamole avec hash SHA-256
DROP PROCEDURE IF EXISTS create_user;
DELIMITER //
CREATE PROCEDURE create_user(IN p_username VARCHAR(256), IN p_password VARCHAR(256))
BEGIN
    DECLARE v_entity_id INT;
    DECLARE v_salt BINARY(32);
    SET v_salt = UNHEX(SHA2(UUID(), 256));
    INSERT INTO guacamole_entity (name, type) VALUES (p_username, 'USER');
    SET v_entity_id = LAST_INSERT_ID();
    INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date)
    VALUES (v_entity_id, UNHEX(SHA2(CONCAT(p_password, HEX(v_salt)), 256)), v_salt, NOW());
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS assign_connection;
DELIMITER //
CREATE PROCEDURE assign_connection(IN p_username VARCHAR(256), IN p_conn_name VARCHAR(256))
BEGIN
    DECLARE v_entity_id INT;
    DECLARE v_conn_id INT;
    SET v_entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = p_username AND type = 'USER');
    SET v_conn_id = (SELECT connection_id FROM guacamole_connection WHERE connection_name = p_conn_name);
    INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
    VALUES (v_entity_id, v_conn_id, 'READ')
    ON DUPLICATE KEY UPDATE permission = 'READ';
END //
DELIMITER ;

-- Tier 0
CALL create_user('w.white', 'Tier0@dmin123!');
CALL create_user('g.fring', 'Tier0@dmin123!');
CALL create_user('m.ehrmantraut', 'Tier0@dmin123!');
CALL assign_connection('w.white', 'DC-01');
CALL assign_connection('w.white', 'DC-02');
CALL assign_connection('g.fring', 'DC-01');
CALL assign_connection('g.fring', 'DC-02');
CALL assign_connection('m.ehrmantraut', 'DC-01');
CALL assign_connection('m.ehrmantraut', 'DC-02');

-- Tier 1
CALL create_user('j.pinkman', 'Tier1@dmin123!');
CALL create_user('s.goodman', 'Tier1@dmin123!');
CALL create_user('h.schrader', 'Tier1@dmin123!');
CALL create_user('l.rodarte', 'Tier1@dmin123!');
CALL assign_connection('j.pinkman', 'SIEM');
CALL assign_connection('s.goodman', 'SIEM');
CALL assign_connection('h.schrader', 'SIEM');
CALL assign_connection('l.rodarte', 'SIEM');

-- Tier 2
CALL create_user('s.white', 'Tier2User123!');
CALL create_user('m.schrader', 'Tier2User123!');
CALL create_user('t.salamanca', 'Tier2User123!');
CALL create_user('j.margolis', 'Tier2User123!');
CALL create_user('t.beneke', 'Tier2User123!');
CALL create_user('b.mayhew', 'Tier2User123!');
CALL create_user('s.pete', 'Tier2User123!');
CALL create_user('a.cantillo', 'Tier2User123!');
CALL create_user('c.ortega', 'Tier2User123!');
CALL create_user('h.babineaux', 'Tier2User123!');
CALL assign_connection('s.white', 'WS-T2-01');
CALL assign_connection('m.schrader', 'WS-T2-01');
CALL assign_connection('t.salamanca', 'WS-T2-01');
CALL assign_connection('j.margolis', 'WS-T2-01');
CALL assign_connection('t.beneke', 'WS-T2-01');
CALL assign_connection('b.mayhew', 'WS-T2-01');
CALL assign_connection('s.pete', 'WS-T2-01');
CALL assign_connection('a.cantillo', 'WS-T2-01');
CALL assign_connection('c.ortega', 'WS-T2-01');
CALL assign_connection('h.babineaux', 'WS-T2-01');

DROP PROCEDURE IF EXISTS create_user;
DROP PROCEDURE IF EXISTS assign_connection;

SELECT 'Setup Guacamole termine avec succes' AS status;
