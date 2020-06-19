DROP TABLE IF EXISTS audio_bibs;
CREATE TEMP TABLE audio_bibs AS
select bre.id as bib_id,ac.id as copy_id, ac.circ_lib from biblio.record_entry bre, actor.usr crtr, actor.usr edtr, asset.call_number acn, asset.copy ac
where 
bre.ID=acn.RECORD AND
acn.ID=ac.CALL_NUMBER AND

not bre.deleted and lower(marc) ~ $$<datafield tag="856" ind1="4" ind2="0">$$ and edtr.id = bre.editor and crtr.id = bre.creator	
and
(
	marc ~ $$tag="008">.......................[oqs]$$
	or
	marc ~ $$tag="006">......[oqs]$$
)
and
(
	marc ~ $$<leader>......i$$
);

select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral ( select audio_bibs.*,aou.name from audio_bibs join actor.org_unit aou on aou.id = circ_lib where copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) and (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id limit ?) as p on true;
