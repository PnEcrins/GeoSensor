

--Schema geosensor

CREATE SCHEMA IF NOT EXISTS geosensor;

CREATE TABLE geosensor.sensor(
   id_sensor serial NOT NULL,
   name VARCHAR(50),
   sensorType VARCHAR(200), --possibilities : capteur NDVI / capteur image / capteur LORA / capteur atmosphérique / capteur hydrologique
   manufacturer VARCHAR(50),
   brand VARCHAR(50),
   model VARCHAR(50),
   serialnumber VARCHAR(50),
   information VARCHAR(500),
   owner VARCHAR(50), --structure owner, ex : PNE / INRAE / IMT / CNRS ...
   plotcode VARCHAR(50),
   contactmail text,
   PRIMARY KEY(id_sensor)
);


CREATE TABLE geosensor.station(
   id_station serial NOT NULL,
   name VARCHAR(50),
   description VARCHAR(500),
   elevation FLOAT, --récupéré grâce au trigger qui repose sur un MNT (dem) dans le schéma ref_geo du serveur Lizmap du BRGM
   geom geometry(Point,2154),
   commune VARCHAR(100), --récupéré grâce au trigger qui repose sur les communes (l_area) dans le schéma ref_geo du serveur Lizmap du BRGM
   PRIMARY KEY(id_station)
);


CREATE TABLE geosensor.resourceType(
   id_resourceType serial NOT NULL,
   resourcetype VARCHAR(50),--possibilities : protocol / picture / information sheet ...
   PRIMARY KEY(id_resourceType)
);

CREATE TABLE geosensor.site(
   id_site serial NOT NULL,
   name VARCHAR(50),
   description VARCHAR(500),
   PRIMARY KEY(id_site)
);

CREATE TABLE geosensor.environment(
   id_environment serial NOT NULL,
   type_environment VARCHAR(50), --possibilities : vegetation / eau / atmosphere / sol
   PRIMARY KEY(id_environment)
);
	
CREATE TABLE geosensor.observedProperty(
   id_op serial NOT NULL,
   id_environment INT,
   type_property VARCHAR(50), --possibilities : temperature, luminosity, pressure, humidity, NDVI...
   unit VARCHAR(50), --name SHOULD follow the Unified Code for Unit of Measure (UCUM), ex : {"name":"degree Celsius","symbol":"°C","definition":"http://unitsofmeasure.org/ucum.html#para-30"}
   PRIMARY KEY(id_op),
   FOREIGN KEY(id_environment) REFERENCES geosensor.environment(id_environment)
);
	
CREATE TABLE geosensor.observation(
   id_observation serial NOT NULL,
   id_sensor INT,
   id_op INT,
   resultTime timestamp with time zone, --ISO 8601 Time string
   resultat FLOAT, 
   resultQuality VARCHAR(50), --possibilities : raw data / preliminary validation / quality-controlled data
   PRIMARY KEY(id_observation),
   FOREIGN KEY(id_op) REFERENCES geosensor.observedProperty(id_op)
   
);

CREATE TABLE geosensor.interventionType(
   id_interventionType serial NOT NULL,
   nom VARCHAR(50), --possibilities : calibration / sensor installation / sensor desinstallation / battery change / change site ...
   PRIMARY KEY(id_interventionType)
);

CREATE TABLE geosensor.intervention(
   id_intervention serial NOT NULL,
   id_sensor INT,
   date_intervention timestamp with time zone, --ISO 8601 Time string
   agent json, --ex : {"firstName":"Clotilde", "lastName":"SAGOT", "email":"clotilde.sagot@ecrins-parcnational.fr"}
   id_interventionType INT,
   description VARCHAR(500),
   PRIMARY KEY(id_intervention),
   FOREIGN KEY(id_sensor) REFERENCES geosensor.sensor(id_sensor),
   FOREIGN KEY(id_interventionType) REFERENCES geosensor.interventionType(id_interventionType)
);


CREATE TABLE geosensor.resources(
   id_resources serial NOT NULL,
   id_sensor INT,
   id_resourceType INT, 
   url VARCHAR(100),
   PRIMARY KEY(id_resources),
   FOREIGN KEY(id_sensor) REFERENCES geosensor.sensor(id_sensor),
   FOREIGN KEY(id_resourceType) REFERENCES geosensor.resourceType(id_resourceType)
);


CREATE TABLE geosensor.cor_station_sensor(
   id_sensor INT,
   id_station INT,
   dateBeg timestamp with time zone, --ISO 8601 Time string
   dateEnd timestamp with time zone, --ISO 8601 Time string
   coment VARCHAR(500),
   id_corsensta serial NOT NULL, -- should be PRIMARY KEY and placed as the first field of this table
   FOREIGN KEY(id_sensor) REFERENCES geosensor.sensor(id_sensor),
   FOREIGN KEY(id_station) REFERENCES geosensor.station(id_station)
);

--Fonctions pour les triggers permettant de récupérer le nom de la commune (=update_commune) et l'altitude (=update_alti) où se trouvent les stations

CREATE OR REPLACE FUNCTION geosensor.update_commune()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
 DECLARE
 geom_change boolean; --variable qui déterminera s'il faut mettre à jour le champ 'commune' de la table 'station'
BEGIN
 geom_change = false;
 IF(TG_OP ='UPDATE') THEN --si une station est mise à jour dans la table 'station' alors,
     SELECT INTO geom_change NOT ST_EQUALS(OLD.geom, NEW.geom); --sélectionne les stations qui ont changé de géométrie
 END IF;
 IF(TG_OP='INSERT' OR (TG_OP='UPDATE' AND geom_change)) THEN --si il y a création ou modification d'une station
    UPDATE geosensor.station  SET commune=ref_geo.l_areas.area_name --met à jour le champ 'commune' en te basant sur le champ 'area_name' 
   	FROM ref_geo.l_areas --de la table 'l_areas' du schéma ref_geo
 	WHERE ref_geo.l_areas.id_type=25 and ST_Within(geosensor.station.geom,ref_geo.l_areas.geom)--en prenant uniquement en compte les communes (id_type=25) ET fait ceci lorsqu'une station se trouve dans une commune de la table 'l_areas' 
 	and geosensor.station.id_station=new.id_station; --ET ne fait ceci que pour une station ajoutée ou modifiée
 END IF;
 RETURN NEW;
END;
$function$
;


CREATE TRIGGER update_commune AFTER -- met en place le trigger 'update_commune' APRES
insert or update of geom --la création d'une station ou la modification de son emplacement
on geosensor.station for each row execute procedure geosensor.update_commune(); --éxecute ce trigger pour chaque ligne de la table 'station'
