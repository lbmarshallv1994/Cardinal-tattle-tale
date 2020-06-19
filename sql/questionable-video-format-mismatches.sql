DROP TABLE IF EXISTS vid_mis;
CREATE TEMP TABLE vid_mis AS
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL,(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID),crtr.id as creator_id, crtr.email as creator_email, edtr.id editor_id, edtr.email editor_email,AOU.NAME, ac.circ_lib
from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL, ACTOR.USR EDTR,ACTOR.USR CRTR where
AOU.ID=AC.CIRC_LIB AND
EDTR.ID = AC.EDITOR AND
CRTR.ID = AC.CREATOR AND
BRE.ID=ACN.RECORD AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT ACN.DELETED AND
NOT AC.DELETED AND
BRE.ID>0 AND
(
ACN.ID IN(SELECT ID FROM ASSET.CALL_NUMBER WHERE (LOWER(LABEL)~$$ dvd$$ OR LOWER(LABEL)~$$^dvd$$ OR LOWER(LABEL)~$$vhs$$ OR LOWER(LABEL)~$$video$$ OR LOWER(LABEL)~$$movie$$) )
OR
ACL.ID IN(SELECT ID FROM ASSET.COPY_LOCATION WHERE (LOWER(NAME)~$$ dvd$$ OR LOWER(NAME)~$$^dvd$$ OR LOWER(NAME)~$$vhs$$ OR LOWER(NAME)~$$video$$ OR LOWER(NAME)~$$movie$$) )
OR
lower(ac.circ_modifier) ~* $$ dvd$$ OR
lower(ac.circ_modifier) ~* $$^dvd$$ OR
lower(ac.circ_modifier) ~* $$movie$$ OR
lower(ac.circ_modifier) ~* $$vhs$$ OR
lower(ac.circ_modifier) ~* $$video$$
)
AND
BRE.ID IN
(
	SELECT A.ID FROM
	(
	SELECT STRING_AGG(VALUE,$$ $$) "FORMAT",ID from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ GROUP BY ID
	) AS A
	WHERE A."FORMAT"!~$$dvd$$ AND A."FORMAT"!~$$vhs$$ AND A."FORMAT"!~$$blu$$
	UNION
	SELECT ID FROM BIBLIO.RECORD_ENTRY WHERE ID NOT IN(SELECT ID from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$)
)
UNION
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL,(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID),crtr.id as creator_id, crtr.email as creator_email, edtr.id editor_id, edtr.email editor_email,AOU.NAME, circ_lib
from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL, ACTOR.USR EDTR,ACTOR.USR CRTR where
AOU.ID=AC.CIRC_LIB AND
EDTR.ID = AC.EDITOR AND
CRTR.ID = AC.CREATOR AND
BRE.ID=ACN.RECORD AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT ACN.DELETED AND
NOT AC.DELETED AND
BRE.ID>0 AND
(
	lower(acn.label) !~* $$ dvd$$ and
	lower(acn.label) !~* $$^dvd$$ and
	lower(acn.label) !~* $$movie$$ and
	lower(acn.label) !~* $$vhs$$ and
	lower(acn.label) !~* $$video$$
)
and
(
	lower(acl.name) !~* $$ dvd$$ and
	lower(acl.name) !~* $$^dvd$$ and
	lower(acl.name) !~* $$movie$$ and
	lower(acl.name) !~* $$vhs$$ and
	lower(acl.name) !~* $$video$$
)
and
(
	lower(ac.circ_modifier) !~* $$ dvd$$ and
	lower(ac.circ_modifier) !~* $$^dvd$$ and
	lower(ac.circ_modifier) !~* $$movie$$ and
	lower(ac.circ_modifier) !~* $$vhs$$ and
	lower(ac.circ_modifier) !~* $$video$$
)
AND
BRE.ID IN
(
	SELECT A.ID FROM
	(
	SELECT STRING_AGG(VALUE,$$ $$) "FORMAT",ID from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ GROUP BY ID
	) AS A
	WHERE A."FORMAT"~$$dvd$$ or A."FORMAT"~$$blu$$ or A."FORMAT"~$$vhs$$
)
order by 1;
select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral ( select vid_mis.* from vid_mis where copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) and (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id limit ?
) as p on true

order by system_id;
