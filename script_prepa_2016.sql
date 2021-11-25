
-- Preparation des données
ALTER TABLE varnum_senges.rpg53_2016
  ALTER COLUMN geom TYPE geometry(Geometry, 4326)
    USING ST_SetSRID(geom,4326);
DROP INDEX IF EXISTS rpg53_2016_idx;
CREATE INDEX rpg53_2016_idx ON varnum_senges.rpg53_2016 USING gist (geom);


UPDate varnum_senges. rpg53_2016
set geom = st_buffer(geom, -0.01);

--Preparation de l'environnement
Drop table IF EXISTS varnum_senges. test;
Drop table IF EXISTS varnum_senges. atlas;
Drop table IF EXISTS varnum_senges. min_env ;
Drop table IF EXISTS varnum_senges. ann_inter ;

DROP FUNCTION if EXISTS  varnum_senges.u_overlap_subb (bigint, geometry, character varying (25) );
DROP FUNCTION if EXISTS  varnum_senges.u_overlap_sub(bigint, geometry);
DROP FUNCTION if EXISTS  varnum_senges.u_overlap(geometry);
DROP FUNCTION if EXISTS  varnum_senges.first_step;
DROP FUNCTION if EXISTS  varnum_senges.min_env;
DROP FUNCTION if EXISTS  varnum_senges.ann_inter ;

DROP TYPE IF EXISTS varnum_senges.u_overlap_sub_typeb CASCADE ;
DROP TYPE IF EXISTS varnum_senges.u_overlap_sub_type CASCADE ;
DROP TYPE IF EXISTS varnum_senges.u_overlap_type CASCADE ;

CREATE TABLE varnum_senges. test(
	id serial PRIMARY KEY,
	geom geometry,
	geomtype character varying(50),
	step character varying(50),
	fid1 bigint,
	fid2 bigint,
	crossed bigint
);

CREATE TYPE varnum_senges.u_overlap_sub_type as (fid bigint, geom geometry);
	CREATE FUNCTION varnum_senges.u_overlap_sub(bigint,geometry) RETURNS varnum_senges.u_overlap_sub_type as
		$$ SELECT $1, $2	 $$
		LANGUAGE SQL ;

CREATE TYPE varnum_senges.u_overlap_type as (fid bigint,
											 p_geom geometry,
										   it_geom varnum_senges.u_overlap_sub_type[]
											);
	CREATE FUNCTION varnum_senges.u_overlap(geometry, int) RETURNS varnum_senges.u_overlap_type as
	$$
					SELECT $2::bigint, $1, array_agg(f.inter)
						FROM  (SELECT c2.geom ,  varnum_senges.u_overlap_sub(c2.fid, ST_Intersection($1, c2.geom))as inter
								FROM varnum_senges.rpg53_2016  as c2
								where ST_Overlaps($1, c2.geom)
-- 							    and (ST_GeometryType(st_intersection ($1, c2.geom)) = 'ST_Polygon'
-- 									or ST_GeometryType(st_intersection ($1, c2.geom)) = 'ST_MultiPolygon')
							 ) as f;
							 ;
	$$
	LANGUAGE SQL ;

-- Vérification des "overlaps" : opération la plus longue à éviter en ensembliste
-- Select varnum_senges.u_overlap(geom) from varnum_senges.rpg53_2016 ORDER BY surf_parc desc LIMIT 1000 ;

--____Début traitement_____

--corrections des non-valide
UPDATE 	varnum_senges. rpg53_2016 SET geom = ST_MakeValid(geom) where fid in (
select c1.fid from
	varnum_senges. rpg53_2016 as c1 where
	/* geomtype <> 'ST_Polygon' OR st_isSimple(geom) = 'False' OR */
	st_isValid(geom) = 'False'
	);


-- construction de l'atlas comportant les informations pour recréations des enveloppes mnimales et intersections
CREATE TABLE varnum_senges. atlas(
	id serial PRIMARY KEY,
	dic varnum_senges.u_overlap_type
);

-- repérage et enregistrement des intersections
	insert into varnum_senges. atlas (dic) (
		select (varnum_senges.u_overlap(geom, fid)) FROM (select geom, fid from varnum_senges.rpg53_2016 /* LIMIT 1000 */) a1
	-- 	select (varnum_senges.u_overlap(geom, fid)).* FROM (select geom, fid from varnum_senges.rpg53_2016 LIMIT 10) a1     --! Syntaxe de séparation des colones
		);

	-- Select (dic).fid from  varnum_senges.atlas;   -- syntaxe d'appel des colones de type composite
	Delete from  varnum_senges.atlas  where (dic).it_geom is null  ;  --supresssion des entrées sans intersections

--report des cas non problématiques
insert into varnum_senges.test (geom, geomtype, step, fid1 ) (
	Select c1.geom, ST_GeometryType(c1.geom), 'Report' , c1.fid
	from varnum_senges.rpg53_2016 as c1
	where c1.id not in (
		select (unnest((dic).it_geom)).fid from varnum_senges.atlas )
	)
;

-- construction des enveloppes minimales :
CREATE TABLE varnum_senges. min_env (id serial PRIMARY KEY, fid bigint, geom geometry);
	CREATE FUNCTION varnum_senges.min_env(varnum_senges.u_overlap_type) RETURNS  varnum_senges.u_overlap_sub_type as
		$body$
			DECLARE
			geo_construct geometry;
			compte int;
-- 			rec record ;
			rec  varnum_senges.u_overlap_sub_type ;
			Begin
				geo_construct = ($1).p_geom ;
				compte = ( select count (*) from (					-- on enregistre le nombre d'entrée dans les intersections pour traitement différencié
								select (unnest((dic).it_geom)).fid from varnum_senges.atlas where (dic).fid = ($1).fid )a1 );
		-- 					raise notice 'ite % loop1 à %', (t_row).fid, compte;
							if compte = 1
								then geo_construct = ST_Difference (geo_construct,  (unnest(($1).it_geom)).geom ) ;
								else
		-- 							raise notice 'cas compliqué %', (select (unnest((t_row).it_geom)).fid limit 1);
									for rec in select (unnest(($1).it_geom)).*
									loop
		-- 								raise notice 'ite % loop2', rec.fid;
										geo_construct = ST_Difference (geo_construct,  ST_Buffer(rec.geom, -0.001));
									end loop ;
							end if;
-- 			Select ($1).fid, geo_construct  Into rec;
-- 			return rec;
			return varnum_senges.u_overlap_sub(($1).fid, geo_construct );
			end;
		$body$
		LANGUAGE plpgSQL;

DROP INDEX IF EXISTS atlas_fid_idx;
CREATE INDEX atlas_fid_idx ON varnum_senges.atlas USING btree(id) WITH (fillfactor = 100);

insert into varnum_senges. min_env (fid, geom) (
	select (varnum_senges.min_env(dic)).*  from varnum_senges.atlas
) ;

delete from  varnum_senges. min_env where  geom is null or ST_AREA(geom)<1;

DROP INDEX IF EXISTS min_env_idx;
DROP INDEX IF EXISTS min_env_fid_idx ;

CREATE INDEX min_env_fid_idx ON varnum_senges.min_env USING btree(fid) WITH (fillfactor = 100);
CREATE INDEX  min_env_idx ON varnum_senges.min_env USING gist (geom);

-- Arbitrage des fusions des intersections : Minenv full mandatory !!!
	Drop table IF EXISTS varnum_senges. ann_inter ;
	DROP FUNCTION if EXISTS  varnum_senges.ann_inter ;
	CREATE TABLE varnum_senges. ann_inter (id serial PRIMARY KEY, step character varying (20), fid1 bigint, fid2 bigint, choix bigint, geom geometry);
	CREATE FUNCTION varnum_senges.ann_inter(bigint, geometry, bigint, geometry, geometry) RETURNS varnum_senges.u_overlap_sub_type as
		$body$
		declare
			parent geometry;
			tampon geometry;

		begin
			if (select count(*) from varnum_senges. ann_inter where fid1 = $3 and fid2 = $1) = 0  --évitement des doublons
			then
				if ST_area($5) < 0.5
					or ST_Geometrytype($5) not in ('ST_Polygon', 'ST_Multipolygon')
	-- 				or ( ST_Geometrytype(ST_Intersection (ST_ExteriorRing($5), $2)) = 'ST_Point' and ST_Geometrytype(ST_Intersection (ST_ExteriorRing($5), $4)) = 'ST_Point' )
	-- 				or ST_intersects($2, $5) = 'False'
	-- 				or ST_intersects($4, $5) = 'False'
				then
					tampon = ST_MakePolygon( ST_GeomFromText('LINESTRING(0 0, 0 0, 0 0, 0 0)'));  -- polygon null : 0103000000010000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
					insert into varnum_senges. ann_inter (step, fid1, fid2, choix)
									(Select 'Insuff_area', $1,$3, 0) ;
					return ($1, tampon);
				else
		-- 				ST_CollectionExtract(ST_Difference( $2, $4),2)   --extraction des lignes
					if ST_Length(	ST_Intersection (ST_ExteriorRing($5), $2) ) > ST_Length( ST_Intersection (ST_ExteriorRing($5), $4) )
					then
						if $1 in (select choix from varnum_senges. ann_inter)
						then
							parent = (select geom from varnum_senges. ann_inter where choix = $1 ) ;
							tampon = ST_MakePolygon(ST_ExteriorRing(ST_Union( parent ,$5))) ;
							delete from varnum_senges. ann_inter where choix = $1 ;
							insert into varnum_senges. ann_inter (step, fid1, fid2, choix, geom)
								(Select 'Recursiv', $1,$3,$1,tampon ) ;
						else
							tampon = ST_MakePolygon(ST_ExteriorRing(ST_Union( $2 ,$5))) ;
							insert into varnum_senges. ann_inter (step, fid1, fid2, choix, geom)
								(Select 'No_pbm', $1,$3,$1, tampon) ;
						end if;

						Return ($1, tampon )  ;
							Raise Notice 'choix a %', $1;
					else
						if $3 in (select choix from varnum_senges. ann_inter)
						then
							parent = (select geom from varnum_senges. ann_inter where choix = $3 ) ;
							tampon = ST_MakePolygon(ST_ExteriorRing(ST_Union( parent ,$5))) ;
							delete from varnum_senges. ann_inter where choix = $3 ;
							insert into varnum_senges. ann_inter (step, fid1, fid2, choix, geom)
								(select 'Recursiv', $1,$3,$3,tampon ) ;
						else
							tampon = ST_MakePolygon(ST_ExteriorRing(ST_Union( $4,$5))) ;
							insert into varnum_senges. ann_inter (step, fid1, fid2, choix, geom)
								(select 'No_pbm', $1,$3,$3, tampon) ;  --!!
						end if;

						Return ($3, tampon) ;
							Raise Notice 'choix b %', $3;
					end if;
				end if;
			else
				tampon = ST_MakePolygon( ST_GeomFromText('LINESTRING(0 0, 0 0, 0 0, 0 0)'));  -- polygon null : 0103000000010000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
				return ($1, tampon);
			end if;


		 end;
		 $body$
		LANGUAGE plpgSQL ;

	DO
		$BODY$

		Declare
			t_row   varnum_senges.u_overlap_type ;
			reponse varnum_senges.u_overlap_sub_type;
			rec varnum_senges.u_overlap_sub_type;
			compte int;
			var1 bigint;   -- fid1
			var2 geometry;	   -- min_env de fid1
			var3 bigint;   -- fid2
			var4 geometry;	   -- min_env de fid2
			var5 geometry;     -- intersectionS
		BEGIN
			For t_row in select (dic).* from varnum_senges.atlas
			loop
				var1 = (t_row).fid ;
				var2 = (Select geom from varnum_senges. min_env where fid=(t_row).fid );

				compte = ( select count (*) from (					-- on enregistre le nombre d'entrée dans les intersections pour traitement différencié
								select (unnest((dic).it_geom)).fid from varnum_senges.atlas where (dic).fid = (t_row).fid )a1 );
		-- 					raise notice 'ite % loop1 à %', (t_row).fid, compte;
					if compte = 1
					then
						var3 = (select (unnest((dic).it_geom)).fid from varnum_senges.atlas where (dic).fid = var1 );
						var4 = (Select geom from varnum_senges. min_env where fid = var3 );
-- 						if ST_Geometrytype(var4) not in('ST_Polygon', 'ST_MultiPolygon') then raise notice 'pas de min env correspondante %', var1;
-- 						end if;
						var5 = (select (unnest((dic).it_geom)).geom from varnum_senges.atlas where (dic).fid = var1 );

						reponse = ( select
							varnum_senges.ann_inter(var1, var2, var3, var4, var5) );
						-- raise notice 'cas simple  : %',reponse;

					else
						-- raise notice 'cas compliqué % pour %', (select (t_row).fid ), compte;
						for rec in (select (unnest((t_row).it_geom)).* )
						loop
		-- 					raise notice 'ite % loop2', rec.fid;
							var3 = rec.fid ;
							var4 = (Select geom from varnum_senges. min_env where fid = var3 );
							var5 = rec.geom;
							reponse = ( select
								varnum_senges.ann_inter(var1, var2, var3, var4, var5) );
						end loop ;
					end if;
			end loop;
		end ;
		$BODY$;

DROP INDEX IF EXISTS ann_inter_idx;
DROP INDEX IF EXISTS ann_inter_fid_idx ;

CREATE INDEX  ann_inter_fid_idx ON varnum_senges. ann_inter USING btree(choix) WITH (fillfactor = 100);
CREATE INDEX ann_inter_idx ON varnum_senges. ann_inter USING gist (geom);

-- Reconstruction de la couche traitée
insert into varnum_senges.test (geom, geomtype, step, fid1 ) (
	Select c1.geom, ST_GeometryType(c1.geom), 'reconstruit' , c1.choix
	from varnum_senges.ann_inter as c1
	where c1.geom is not null
	)
;

insert into varnum_senges.test (geom, geomtype, step, fid1 ) (
	Select c1.geom, ST_GeometryType(c1.geom), 'left_min_env' , c1.fid
	from varnum_senges.min_env as c1
	where c1.fid not in (select fid1 from  varnum_senges.test)
	)
;

-- mise en qualité de la couche finie

insert into varnum_senges.test (geom, geomtype, step, fid1 ) (
	WITH dump AS (
		SELECT  (ST_DUMP(sub.geom)).geom AS geometry, ST_GeometryType((ST_DUMP(sub.geom)).geom) As geomtype, sub.step as step, sub.fid1 as fid1        --columns from your multipolygon table
		FROM varnum_senges. test as sub where ST_Geometrytype(geom) = 'ST_MultiPolygon'
	)

	SELECT  geometry::geometry(Polygon,4326), geomtype, step, fid1    --type cast using SRID from multipolygon
	  FROM dump
	);

delete from varnum_senges.test where ST_Geometrytype(geom) = 'ST_MultiPolygon'  ;
-- spe TxT : pas de polygon de moins de 10m²
delete from varnum_senges.test where ST_AREA(geom)<10;

-- probleme de MultiLine String
-- 	select geom, geomtype, step, fid1 from varnum_senges. test where fid1 in
-- 	(SELECT /* (ST_DUMP(sub.geom)).geom AS geometry, ST_GeometryType((ST_DUMP(sub.geom)).geom) As geomtype, sub.step as step, */sub.fid1 as fid1        --columns from your multipolygon table
-- 		FROM varnum_senges. test as sub where ST_Geometrytype(geom) = 'ST_MultiLineString'       )

DROP INDEX IF EXISTS _16_fid_idx;
DROP INDEX IF EXISTS _16_idx ;

CREATE INDEX _16_fid_idx ON varnum_senges.test USING btree(fid1) WITH (fillfactor = 100);
CREATE INDEX _16_idx ON varnum_senges.test USING gist (geom);
ALTER TABLE varnum_senges.test
  ALTER COLUMN geom TYPE geometry(POLYGON, 2154)
    USING ST_SetSRID(geom,2154);

--Gestion des dernieres approximations
ALTER TABLE varnum_senges. test ALTER COLUMN geom SET DATA TYPE geometry;

UPDate varnum_senges. test
set geom = st_buffer(geom, -0.001);

ALTER TABLE varnum_senges. test ALTER COLUMN geom
SET DATA TYPE geometry(MultiPolygon) USING ST_Multi(geom);
--
-- ALTER TABLE varnum_senges. test
-- Rename to varnum_senges. RPG_2016_56c;
