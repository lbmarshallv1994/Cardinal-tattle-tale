DROP TABLE IF EXISTS non_audio_copies;
CREATE TEMP TABLE non_audio_copies AS
select bre.id as bib_id,ac.id as copy_id,bre.marc,string_agg(ac.barcode,$$,$$), crtr.id as creator_id, crtr.email as creator_email, edtr.id editor_id, edtr.email editor_email,  ac.circ_lib from biblio.record_entry bre, asset.copy ac, asset.call_number acn, asset.copy_location acl, actor.usr crtr, actor.usr edtr  where
bre.marc ~ $$<leader>......i$$ and
acl.id=ac.location and
crtr.id = ac.creator and
edtr.id = ac.editor and
bre.id=acn.record and
acn.id=ac.call_number and
not acn.deleted and
not ac.deleted and
not bre.deleted and
BRE.ID>0 AND
(
	lower(acn.label) !~* $$cass$$ and
	lower(acn.label) !~* $$aud$$ and
	lower(acn.label) !~* $$disc$$ and
	lower(acn.label) !~* $$mus$$ and
	lower(acn.label) !~* $$ cd$$ and
	lower(acn.label) !~* $$^cd$$ and
	lower(acn.label) !~* $$disk$$
)
and
(
	lower(acl.name) !~* $$cas$$ and
	lower(acl.name) !~* $$aud$$ and
	lower(acl.name) !~* $$disc$$ and
	lower(acl.name) !~* $$mus$$ and
	lower(acl.name) !~* $$ cd$$ and
	lower(acl.name) !~* $$^cd$$ and
	lower(acl.name) !~* $$disk$$
)
and
ac.circ_modifier not in ( $$AudioBooks$$,$$CD$$ )
group by bre.id,ac.id,bre.marc,crtr.id,edtr.id,ac.circ_lib;

select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral ( select non_audio_copies.*,aou.name from non_audio_copies join actor.org_unit aou on aou.id = circ_lib where copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) and (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id limit ?) as p on true
order by system_id;
