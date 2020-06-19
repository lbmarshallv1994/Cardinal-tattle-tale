DROP TABLE IF EXISTS lp_bibs;
CREATE TEMP TABLE lp_bibs AS
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL,(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID), AC.circ_lib,AOU.NAME,crtr.id, crtr.email

from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL, ACTOR.USR CRTR where

AOU.ID=AC.CIRC_LIB AND
CRTR.ID = AC.CREATOR AND
BRE.ID=ACN.RECORD AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT ACN.DELETED AND





NOT AC.DELETED AND

(
ACN.ID IN(SELECT ID FROM ASSET.CALL_NUMBER WHERE (LOWER(LABEL)!~$$ lp$$ AND LOWER(LABEL)!~$$^lp$$ AND LOWER(LABEL)!~$$large$$ AND LOWER(LABEL)!~$$lg$$ AND LOWER(LABEL)!~$$sight$$ AND LOWER(LABEL)!~$$s\.s\.$$) )AND

ACL.ID IN(SELECT ID FROM ASSET.COPY_LOCATION WHERE (LOWER(NAME)!~$$ lp$$ AND LOWER(NAME)!~$$^lp$$ AND LOWER(NAME)!~$$large$$ AND LOWER(NAME)!~$$lg$$ AND LOWER(NAME)!~$$sight$$ AND LOWER(NAME)!~$$s\.s\.$$) )
)
AND
BRE.ID IN
(
	SELECT A.ID FROM
	(
	SELECT STRING_AGG(VALUE,$$ $$) "FORMAT",ID from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ GROUP BY ID
	) AS A
	WHERE A."FORMAT"~$$lpbook$$
) AND
BRE.ID > 0
order by ac.edit_date desc;

select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral (
select * from lp_bibs 
where copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) and (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id
limit ?
) p on true
order by system_id;
