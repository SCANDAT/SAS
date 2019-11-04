/*class dataset*/

proc means data=sashelp.class;
run;

proc means data=sashelp.class;
class sex;
run;


proc sgplot data=sashelp.class;
vbox height / category=age group=sex groupdisplay=cluster;
run;

proc sgplot data=sashelp.class;
vbox height / category=sex;
run;


proc format;
value $sex
	'F' = 'Female'
	'M' = 'Male'
;

proc sgplot data=sashelp.class;
format sex $sex.;
vbox height / category=sex;
run;

ods html style=blue;
proc sgplot data=sashelp.class;
format sex $sex.;
title "Height vs sex";
vbox height / category=sex;
run;

