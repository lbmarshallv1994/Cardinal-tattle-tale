DROP TABLE IF EXISTS audio_copies;
CREATE TEMP TABLE audio_copies AS
select bre.id as bib_id, ac.id as copy_id,bre.marc,string_agg(ac.barcode,$$,$$),crtr.id as creator_id, crtr.email as creator_email, edtr.id editor_id, edtr.email editor_email,  ac.circ_lib from biblio.record_entry bre, asset.copy ac, asset.call_number acn, asset.copy_location acl, actor.usr crtr, actor.usr edtr where

acl.id=ac.location and
crtr.id = ac.creator and
edtr.id = ac.editor and
bre.id=acn.record and
acn.id=ac.call_number and
not acn.deleted and
not ac.deleted and
not bre.deleted and
(
	lower(acn.label) ~* $$cass$$ or
	lower(acn.label) ~* $$aud$$ or
	lower(acn.label) ~* $$disc$$ or
	lower(acn.label) ~* $$mus$$ or
	lower(acn.label) ~* $$ cd$$ or
	lower(acn.label) ~* $$^cd$$ or
	lower(acn.label) ~* $$disk$$
or
	lower(acl.name) ~* $$cas$$ or
	lower(acl.name) ~* $$aud$$ or
	lower(acl.name) ~* $$disc$$ or
	lower(acl.name) ~* $$mus$$ or
	lower(acl.name) ~* $$ cd$$ or
	lower(acl.name) ~* $$^cd$$ or
	lower(acl.name) ~* $$disk$$
)
and
ac.circ_modifier in ( $$AudioBooks$$,$$CD$$ ) and
(
(

(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$music$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$casaudiobook$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$casmusic$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$cassette$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$cd$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$cdaudiobook$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$cdmusic$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$playaway$$ and
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) !~ $$kit$$
)
OR
(SELECT STRING_AGG(VALUE,$$ $$) "FORMAT" from METABIB.RECORD_ATTR_FLAT WHERE ATTR=$$icon_format$$ AND ID=BRE.ID GROUP BY ID) IS NULL
)
group by bre.id,ac.id,bre.marc,creator_id,editor_id, ac.circ_lib;

select * from (select id as system_id from actor.org_unit where parent_ou = 1) as systems
join lateral ( select audio_copies.*,aou.name from audio_copies join actor.org_unit aou on aou.id = circ_lib where (select id from actor.org_unit_ancestor_at_depth(circ_lib, 1)) = system_id and copy_id not in (select target_copy from tattler.ignore_list where org_unit = system_id and report_name = ?) limit ?) as p on true order by system_id;
