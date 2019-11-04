* file:   importicd.sas                      ;
* Author: Jingcheng Zhao jingcheng.zhao@ki.se 180829 ;
* Based on the concept by Ammar Majeed;
* Codereview by Gustaf Edgren 180830;

* This is a tool for extracting and grouping outcomes from SCANDAT2 based on an excel file.;
* This macro requires the use of the excelfile template importicd_template.xlsx
* It allows differentiation between SE and DK ICD-codes.;

* It generates the following;
* 			groupname.			- a SAS format with the group name for the corresponding group number;
*			groupdescription.	- a SAS format with the group description for the corresponding group number;
*			&where 				- a global SAS macro variable to be used in a proc SQL statement (example below);
*			&groupif			- a global SAS macro variable to be used in a data step (example below);
*			import_icd			- SAS dataset with all the ICD codes, including country and ICD-version vars;


* A further example is included below.
* Dependencies: modified versions of CODEPICKER by Klaus Rostgaard.

*---------------------------------------*
|  				%importicd		        |
*---------------------------------------*;


%macro importicd(filepath				/*filepath of excelfile based on importicd_template.xlsx. E.g. "C:/documents/excel.xlsx") */
				,icdtypes				/*icdtypes - format is e.g. 7SE for Swedish ICD7, or 8DK for Danish ICD8. Needs corresponding excelsheet with 'ICD' prefix* (included in template)*/
				,output=import_icd		/*name of the output file*/
				,formatname=group		/*name of the SAS formats name and description*/
				,mode=passthrough		/*modes can be 'passthrough' or 'local'. If 'passthrough' the &where clause will use "substring()", whereas 'local' uses 'substr()*/
				,diavar=b.diagnosis		/*name of the diagnosis variable in the proc.sql statement*/
				,countryvar=a.country 	/*name of the country variable in the proc.sql statement*/
				,icdvar=b.icd			/*name of the icd variable in the proc.sql statement*/
				);
%symdel where groupif;
%global where groupif;
/*import INDEX and make SAS formats*/
proc import datafile = &filepath
	 out  =  import_group (keep=group group_name description where=(missing(group)=0))
	 dbms  =  xlsx
	 replace
	 ;
	 sheet  =  "INDEX";
	run;

data fmt1(keep=fmtname start label);
	set import_group(rename=(group=start group_name=label));
	fmtname="&formatname.name";
run; 
proc format cntlin=fmt1;
run;

data fmt2(keep=fmtname start label);
	set import_group(rename=(group=start description=label));
	fmtname="&formatname.description";
run; 
proc format cntlin=fmt2;
run;

proc datasets lib=work nolist;
   delete import_group fmt1 fmt2;
run;

/*import ICD sheets*/
%let icd=%scan(&icdtypes,1,' ');
%let k=1;
%do %while(%length(&icd) ne 0);
	proc import datafile = &filepath
	 out  =  import_TEMP_&icd (keep=group diagnosis where=(missing(group)=0))
	 dbms  =  xlsx
	 replace
	 ;
	 sheet  =  "ICD&icd";
	run;

/*country and icd versions*/
%if %eval(%index(&icd,SE)>0) %then %let country=country%str(=)"S"%str(;); 
%if %eval(%index(&icd,DK)>0) %then %let country=country%str(=)"D"%str(;); 
%let icdversion=%substr(&icd,1,1);
%if &icdversion=1 %then %let icdversion=%substr(&icd,1,2);
%let icdversion2= icd%str(=)&icdversion%str(;);
%if &k=1 %then %let datasets=import_TEMP_&icd;
%if &k ne 1 %then %let datasets=&output._1 import_TEMP_&icd;

data import_TEMP_&icd;
length diagnosis $ 8;
set import_TEMP_&icd;
informat diagnosis $char8.;
format diagnosis $char8.;
&country
&icdversion2
if group=9999 then delete;
run;


data &output._1;
set &datasets;
informat diagnosis $char8.;
format diagnosis $char8.;
if group=9999 then delete;
run;

/*create where clause*/
/*create macrovariable alldiagnosis with all diagnosis in the set*/
proc sql noprint;
select 
	diagnosis into: alldiagnosis separated by ' ' 
from import_TEMP_&icd;
quit;

%if &k ne 1 %then %let where=&where or; %else %let where=&where;

/*mode local*/
%if %scan(&mode,1,1)=local %then %do;
	%if %eval(%index(&icd,SE)>0) %then %let where=&where (&countryvar=%str(%')S%str(%') and (&icdvar=&icdversion and %fetchicd_local(%quote(&alldiagnosis),diavar=&diavar)));
	%if %eval(%index(&icd,DK)>0) %then %let where=&where (&countryvar=%str(%')D%str(%') and (&icdvar=&icdversion and %fetchicd_local(%quote(&alldiagnosis),diavar=&diavar)));
%end;
%else %do;
/*mode passthrough=default)*/
	%if %eval(%index(&icd,SE)>0) %then %let where=&where (&countryvar=%str(%')S%str(%') and (&icdvar=&icdversion and %fetchicd(%quote(&alldiagnosis),diavar=&diavar)));
	%if %eval(%index(&icd,DK)>0) %then %let where=&where (&countryvar=%str(%')D%str(%') and (&icdvar=&icdversion and %fetchicd(%quote(&alldiagnosis),diavar=&diavar)));
%end;

/*delete temporary datasets*/
proc datasets lib=work nolist;
   delete import_TEMP_&icd;
run;
quit;

%let k=%eval(&k+1);
%let icd=%scan(&icdtypes,&k,' ');
%end;

/*create groupif clause*/
/*create macro variables*/
proc sql noprint;
select 
		diagnosis,
		country,
		icd,
		group 

into	:gi_diagnosis separated by ' ', 
		:gi_country separated by ' ',
		:gi_icd separated by ' ',
		:gi_group separated by ' '
from &output._1;
quit;

%let gi_diagnosis1=%scan(%quote(&gi_diagnosis),1,' ');
%let gi_country1=%scan(&gi_country,1,' ');
%let gi_icd1=%scan(&gi_icd,1,' ');
%let gi_group1=%scan(&gi_group,1,' ');
%let k=1;
%do %while(%length(&gi_diagnosis1) ne 0);

*the actual statement;
%let groupif=&groupif if country%str(=)%str(%")&gi_country1%str(%") and icd%str(=)&gi_icd1 and %imacro(diagnosis,%bquote(&gi_diagnosis1)) then group%str(=)&gi_group1%str(;);

*restart loop;
%let k=%eval(&k+1);
%let gi_diagnosis1=%scan(%quote(&gi_diagnosis),&k,' ');
%let gi_country1=%scan(&gi_country,&k,' ');
%let gi_icd1=%scan(&gi_icd,&k,' ');
%let gi_group1=%scan(&gi_group,&k,' ');
%end;


/*change dataset name so that it doesn't concatenate when running the program again*/
data &output;
set &output._1;
run;

proc datasets lib=work nolist;
	delete &output._1;
run;
quit;
%mend;

/*EXAMPLE*/
/*

options mprint symbolgen;
%importicd("P:\Cblood\macros\importicd_template2.xlsx", 7SE 8SE 10SE 7DK 8DK,mode=local diavar=diagnosis);

data test;
set import_icd;
drop group;
run;

data test2;
set test;
%unquote(&groupif)
run;

*Example with rsubmit

%inc "P:\Cblood\macros\logon.sas";
%signonflex();

rsubmit;
proc sql



*/

*---------------------------------------*
|  				dependencies	        |
*---------------------------------------*;
/*Imacro is essentially the same as CODEPICKER, but uses 'q' instead of 'i', so that it can be used together with other macros that use 'i'*/
%macro imacro(diavar,spec);
%let pattern=%scan(&spec,1,' ');
%let q=1;
%do %while(%length(&pattern) ne 0);
 %let lpattern=%length(&pattern);
 %if &q = 1 %then %let ilist=(;
 %else %let ilist=&ilist or ;
 %let ilist=&ilist (substr(&diavar,1,&lpattern)=%str(%")&pattern%str(%"));
 %let q=%eval(&q+1);
 %let pattern=%scan(&spec,&q,' ') ;
%end;
%let ilist=&ilist) ;
&ilist%mend;

/*Fetchicd is essentially CODEPICKER but adapted for passthrough SQL*/
%macro fetchicd(spec,diavar);
%let pattern=%scan(&spec,1,' ');
%let q=1;
%do %while(%length(&pattern) ne 0);
 %let lpattern=%length(&pattern);
 %if &q = 1 %then %let ilist= (;
 %else %let ilist=&ilist or ;
 %let ilist=&ilist (substring(&diavar,1,&lpattern)=%str(%')&pattern%str(%'));
 %let q=%eval(&q+1);
 %let pattern=%scan(&spec,&q,' ') ;
%end;
%let ilist=&ilist) ;
&ilist
%mend;


/*Fetchicd_local is essentially CODEPICKER but adapted for proc SQL*/
%macro fetchicd_local(spec,diavar);
%let pattern=%scan(&spec,1,' ');
%let q=1;
%do %while(%length(&pattern) ne 0);
 %let lpattern=%length(&pattern);
 %if &q = 1 %then %let ilist= (;
 %else %let ilist=&ilist or ;
 %let ilist=&ilist (substr(&diavar,1,&lpattern)=%str(%')&pattern%str(%'));
 %let q=%eval(&q+1);
 %let pattern=%scan(&spec,&q,' ') ;
%end;
%let ilist=&ilist) ;
&ilist
%mend;


