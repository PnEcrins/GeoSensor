--Fonctions pour les triggers de maj des données issues de la geometrie des communes

CREATE OR REPLACE FUNCTION geosensor.update_commune()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
 DECLARE
 geom_change boolean; 
BEGIN
 geom_change = false;
 IF(TG_OP ='UPDATE') THEN
     SELECT INTO geom_change NOT ST_EQUALS(OLD.geom, NEW.geom);
 END IF;
 IF(TG_OP='INSERT' OR (TG_OP='UPDATE' AND geom_change)) THEN
    UPDATE geosensor.station  SET commune=ref_geo.l_areas.area_name 
   	FROM ref_geo.l_areas 
 	WHERE ref_geo.l_areas.id_type=25 and ST_Within(geosensor.station.geom,ref_geo.l_areas.geom)
 	and geosensor.station.id_station=new.id_station;
 END IF;
 RETURN NEW;
END;
$function$
;


--Schema geosensor

CREATE SCHEMA IF NOT EXISTS geosensor;

CREATE TABLE geosensor.sensor(
   id_sensor serial NOT NULL,
   name VARCHAR(50),
   sensorType VARCHAR(200), --possibilities : environmental sensor / camera trap ...
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
   elevation FLOAT,
   geom geometry(Point,2154),
   commune VARCHAR(100),
   PRIMARY KEY(id_station)
);

CREATE TRIGGER update_geom AFTER
insert or update of geom
on geosensor.station for each row execute procedure geosensor.update_commune();


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
   type_environment VARCHAR(50),
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
   resultat FLOAT, --result is an SQL word
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
   id_corsensta serial NOT NULL,
   FOREIGN KEY(id_sensor) REFERENCES geosensor.sensor(id_sensor),
   FOREIGN KEY(id_station) REFERENCES geosensor.station(id_station)
);
