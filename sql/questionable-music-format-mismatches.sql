DROP TABLE IF EXISTS mus_mis;
CREATE TEMP TABLE mus_mis AS
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL,(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID),AC.CIRC_LIB,AOU.NAME
from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL where
AOU.ID=AC.CIRC_LIB AND
BRE.ID=ACN.RECORD AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT ACN.DELETED AND
NOT AC.DELETED AND
BRE.ID>0 AND
(
ACN.ID IN(SELECT ID FROM ASSET.CALL_NUMBER WHERE (LOWER(LABEL)~$$music$$ OR LOWER(LABEL)~$$^folk$$ OR LOWER(LABEL)~$$ folk$$ OR LOWER(LABEL)~$$classical$$) AND LOWER(LABEL)!~$$folktale$$ )
OR
ACL.ID IN(SELECT ID FROM ASSET.COPY_LOCATION WHERE (LOWER(NAME)~$$music$$) )
OR
lower(ac.circ_modifier) ~* $$music$$
)
AND
BRE.ID IN
(
	SELECT A.ID FROM
	(
	SELECT STRING_AGG(VALUE,$$ $$) "FORMAT",ID from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ GROUP BY ID
	) AS A
	WHERE A."FORMAT"!~$$music$$
	UNION
	SELECT ID FROM BIBLIO.RECORD_ENTRY WHERE ID NOT IN(SELECT ID from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$)
)
UNION
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL,(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID),AC.CIRC_LIB,AOU.NAME
from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL where
AOU.ID=AC.CIRC_LIB AND
BRE.ID=ACN.RECORD AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT ACN.DELETED AND
NOT AC.DELETED AND
BRE.ID>0 AND
(
	lower(acn.label) !~* $$music$$ and
	lower(acn.label) !~* $$ folk$$ and
	lower(acn.label) !~* $$^folk$$ and
	lower(acn.label) !~* $$readalong$$ and
	lower(acn.label) !~* $$singalong$$ and
	lower(acn.label) !~* $$classical$$
	
)
and
(
	lower(acl.name) !~* $$music$$ and
	lower(acl.name) !~* $$singalong$$ and
	lower(acl.name) !~* $$readalong$$
)
and
(
	lower(ac.circ_modifier) !~* $$music$$ and
	lower(ac.circ_modifier) !~* $$cd$$
)
AND
BRE.ID IN
(
	SELECT A.ID FROM
	(
	SELECT STRING_AGG(VALUE,$$ $$) "FORMAT",ID from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ GROUP BY ID
	) AS A
	WHERE A."FORMAT"~$$music$$
)
order by 1;
select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral (select * from mus_mis where copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) and (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id limit ?
) p on true

order by system_id;