*examples with importicd2.sas;
*181008;
%inc "P:\Cblood\macros\importicd2.sas";

*example local;
options mprint symbolgen;
%importicd("P:\Cblood\macros\importicd_template2.xlsx", 7SE 8SE 10SE 7DK 8DK);

data test;
set import_icd;
drop group;
run;

data test2;
set test;
&groupif;
run;
data test2;
set test;
%unquote(&groupif);
run;


*example with rsubmit;
%inc "P:\Cblood\macros\logon.sas";
%signonflex();

%importicd("P:\Cblood\macros\importicd_template2.xlsx", 7SE 8SE 10SE 7DK 8DK,mode=local, diavar=diagnosis, icdvar=icd, countryvar=country);
proc datasets library=work nolist;
copy out=remwork;
     select import_icd;
run;
quit;

%syslput where=&where;

rsubmit;
proc sql;
create table test as 
select
	*
from import_icd (drop=group)
where %unquote(&where);
quit;
endrsubmit;

%syslput groupif=&groupif;

rsubmit;
data test2;
set test;
%unquote(&groupif);
run;
endrsubmit;


*only danish;
%importicd("P:\Cblood\macros\importicd_template2.xlsx", 7DK 8DK,mode=local, diavar=diagnosis, icdvar=icd, countryvar=country);

%syslput where=&where;

rsubmit;
proc sql;
create table test_dk as 
select
	*
from import_icd (drop=group)
where %unquote(&where);
quit;
endrsubmit;

%syslput groupif=&groupif;
rsubmit;
data test2_dk;
set test_dk;
%unquote(&groupif);
run;
endrsubmit;

