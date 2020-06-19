DROP TABLE IF EXISTS dvd_mis;
DROP TABLE IF EXISTS icon_formats;
CREATE TEMP TABLE icon_formats AS
SELECT id,STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ GROUP BY ID HAVING count(id) = 1;

CREATE TEMP TABLE dvd_mis AS
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL as call_number_label,icon_formats."FORMAT",crtr.id as creator_id, crtr.email as creator_email, edtr.id editor_id, edtr.email editor_email,AOU.NAME, ac.circ_lib
from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL,ACTOR.USR EDTR,ACTOR.USR CRTR, icon_formats where
AOU.ID=AC.CIRC_LIB AND
EDTR.ID = AC.EDITOR AND
CRTR.ID = AC.CREATOR AND
BRE.ID=ACN.RECORD AND
BRE.ID=icon_formats.id AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT ACN.DELETED AND
NOT AC.DELETED AND
BRE.ID>0 AND
(
ACN.ID IN(SELECT ID FROM ASSET.CALL_NUMBER WHERE (LOWER(LABEL)~$$ dvd$$ OR LOWER(LABEL)~$$^dvd$$) )
OR
ACL.ID IN(SELECT ID FROM ASSET.COPY_LOCATION WHERE (LOWER(NAME)~$$ dvd$$ OR LOWER(NAME)~$$^dvd$$) )
OR
lower(ac.circ_modifier) ~* $$ dvd$$ OR
lower(ac.circ_modifier) ~* $$^dvd$$
)
AND
icon_formats."FORMAT"!~$$dvd$$
UNION
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL as call_number_label,icon_formats."FORMAT",crtr.id as creator_id, crtr.email as creator_email, edtr.id editor_id, edtr.email editor_email,AOU.NAME, ac.circ_lib
from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL, ACTOR.USR EDTR,ACTOR.USR CRTR, icon_formats where
AOU.ID=AC.CIRC_LIB AND
EDTR.ID = AC.EDITOR AND
CRTR.ID = AC.CREATOR AND
BRE.ID=ACN.RECORD AND
BRE.ID=icon_formats.id AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT ACN.DELETED AND
NOT AC.DELETED AND
BRE.ID>0 AND
(
	lower(acn.label) !~* $$ dvd$$ and
	lower(acn.label) !~* $$^dvd$$ and
	lower(acn.label) !~* $$movie$$ and
	lower(acn.label) !~* $$video$$
)
and
(
	lower(acl.name) !~* $$ dvd$$ and
	lower(acl.name) !~* $$^dvd$$ and
	lower(acl.name) !~* $$movie$$ and
	lower(acl.name) !~* $$video$$
)
and
(
	lower(ac.circ_modifier) !~* $$ dvd$$ and
	lower(ac.circ_modifier) !~* $$^dvd$$ and
	lower(ac.circ_modifier) !~* $$movie$$ and
	lower(ac.circ_modifier) !~* $$video$$
)
AND
icon_formats."FORMAT"~$$dvd$$

order by 1;

select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral ( select dvd_mis.*,aou.name from dvd_mis join actor.org_unit aou on aou.id = circ_lib where copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) and (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id  limit ?
) as p on true

order by system_id;