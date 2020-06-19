DROP TABLE IF EXISTS del_bibs;
CREATE TEMP TABLE del_bibs AS
select BRE.id as bib_id,AC.id as copy_id,ACN.LABEL,(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID),AOU.NAME, circ_lib, DELUSR.id as deletor_id, DELUSR.email as deletor_email
from biblio.record_entry BRE, ASSET.COPY AC, ACTOR.ORG_UNIT AOU,ASSET.CALL_NUMBER ACN,ASSET.COPY_LOCATION ACL, ACTOR.USR DELUSR where
AOU.ID=AC.CIRC_LIB AND
BRE.ID=ACN.RECORD AND
DELUSR.ID = BRE.EDITOR AND
ACN.ID=AC.CALL_NUMBER AND
ACL.ID=AC.LOCATION AND
NOT BRE.DELETED AND
BRE.EDITOR != 1 AND 
BRE.ID > 0 AND
NOT AC.DELETED AND
lower(BRE.marc) ~ $$<datafield tag="856" ind1="4" ind2="0">$$ AND
BRE.id in
(
select record from asset.call_number where not deleted and id in(select call_number from asset.copy where not deleted)
)
and
(
	BRE.marc ~ $$tag="008">.......................[oqs]$$
	or
	BRE.marc ~ $$tag="006">......[oqs]$$
)
and
(
	BRE.marc ~ $$<leader>......[at]$$
)
and
(
	BRE.marc ~ $$<leader>.......[acdm]$$
);

select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral ( select * from del_bibs where copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) and (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id limit ?
) as p on true

order by system_id;
