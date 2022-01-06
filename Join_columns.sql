alter table varnum_senges. test_20_17 add fid20 bigint ; 
alter table varnum_senges. test_20_17 add fid19 bigint;
alter table varnum_senges. test_20_17 add fid18 bigint;
alter table varnum_senges. test_20_17 add fid17 bigint;

select D.id, B.fid20 from varnum_senges. test_20_17 as D
inner join varnum_senges. test_20_19 as B on D.id1 = B.id
where D.id1 is not null order by D.id asc;

update varnum_senges. test_20_17 
set fid20 = B.fid20
from varnum_senges. test_20_19 as B
where varnum_senges. test_20_17 .id1 is not null and varnum_senges. test_20_17 .id1 = B.id ;


update varnum_senges. test_20_17 
set fid19 = B.fid19
from varnum_senges. test_20_19 as B
where varnum_senges. test_20_17 .id1 is not null and varnum_senges. test_20_17 .id1 = B.id ;

-- update varnum_senges. test_20_17 
-- set fid19 = B.fid19
-- from varnum_senges. test_20_17 as D inner join varnum_senges. test_20_19 as B on D.id1 = B.id
-- where D.id1 is not null;

update varnum_senges. test_20_17 
set fid18 = B.fid18
from varnum_senges. test_18_17 as B
where varnum_senges. test_20_17 .id2 is not null and varnum_senges. test_20_17 .id2 = B.id ;

-- update varnum_senges. test_20_17 
-- set fid18 = B.fid18
-- from varnum_senges. test_20_17 as D inner join varnum_senges. test_18_17 as B on D.id2 = B.id
-- where D.id2 is not null;

update varnum_senges. test_20_17 
set fid17 = B.fid17
from varnum_senges. test_18_17 as B
where varnum_senges. test_20_17 .id2 is not null and varnum_senges. test_20_17 .id2 = B.id ;

-- update varnum_senges. test_20_17 
-- set fid17 = B.fid17
-- from varnum_senges. test_20_17 as D inner join varnum_senges. test_18_17 as B on D.id2 = B.id 
-- where D.id2 is not null;


