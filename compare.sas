%macro compare(base,
               comp,
               by,
               result,
               include=,
               exclude=,
               pattern=,
               xpattern=,
               join=full) / minoperator;
%if %quote(&base.) eq or %quote(&comp.) eq or %quote(&by.) eq %then %do;
    %put ===Insufficient information: %nrstr(&base, &comp or &by) is not specified.===;
    %goto exit;
%end;
%if not %index(&base.,.) %then %let base = work.&base.;
%if not %index(&comp.,.) %then %let comp = work.&comp.;
%if not %index(&result.,.) %then %if &result. eq %then %let result = work.result_%sysfunc(translate(%cmpres(%sysfunc(datetime(),b8601dt.)),_,T)); %else %let result = work.&result.;

%local rc1 dsid1 vlist1 tname1 vlen1;
%local rc2 dsid2 vlist2 tname2 vlen2;
%local i j n;
%local vlist;
%let dsid1 = %sysfunc(open(&base.));
%let dsid2 = %sysfunc(open(&comp.));

%*Extract variables respectively;
%do i = 1 %to 2;
    %if not &&dsid&i.. %then %goto exit;
    %do j = 1 %to %sysfunc(attrn(&&dsid&i..,nvars));
        %*Despite the by-variables;
        %if %qlowcase(%sysfunc(varname(&&dsid&i..,&&j.))) in %qlowcase(&&by.) %then %goto ignore;
        %*Includes variables if sepcified;
        %if %quote(&include.) ne %then %if not (%qlowcase(%sysfunc(varname(&&dsid&i..,&&j.))) in %qlowcase(&&include.)) %then %goto ignore;
        %*Excludes variables if sepcified;
        %if %quote(&exclude.) ne %then %if %qlowcase(%sysfunc(varname(&&dsid&i..,&&j.))) in %qlowcase(&&exclude.) %then %goto ignore;
        %*Expected pattern if specified;
        %if not %sysfunc(prxmatch(/%nrbquote(&pattern.)/, %qlowcase(%sysfunc(varname(&&dsid&i..,&&j.))))) %then %goto ignore;
        %*Unexpected pattern if specified;
        %if %quote(&xpattern.) ne %then %if %sysfunc(prxmatch(/%nrbquote(&xpattern.)/, %qlowcase(%sysfunc(varname(&&dsid&i..,&&j.))))) %then %goto ignore;

        %*Extract the length of variables;
        %let vlen&i. = &&vlen&i.. %sysfunc(varlen(&&dsid&i..,&j.));
        %*Extract the name of variables;
        %let vlist&i. = %cmpres(%quote(&&vlist&i.. %sysfunc(varname(&&dsid&i..,&&j.))));
        %ignore:
    %end;
%end;

%if %quote(&vlist1.) eq or %quote(&vlist2.) eq %then %do;
    %put ==================================================;
    %put There are no comparing variables in &base. or &comp..;
    %put ==================================================;
    %goto exit;
%end;

%*Intersects variables of both sides;
%let i = 1;
%do %until(%qscan(&vlist1.,&i.) eq);
    %if %qlowcase(%scan(&vlist1.,&i.)) in %qlowcase(&vlist2.) %then
        %*Ensure the consistent type;
        %if %sysfunc(vartype(&dsid1.,%sysfunc(varnum(&dsid1.,%scan(&vlist1.,&i.))))) eq %sysfunc(vartype(&dsid2.,%sysfunc(varnum(&dsid2.,%scan(&vlist1.,&i.))))) %then %do;
            %let vlist = %cmpres(%quote(&vlist. %scan(&vlist1.,&i.)));
            %let n = %eval(&n.+1);
        %end;
    %let i = %eval(&i.+1);
%end;

%let rc1 = %sysfunc(close(&dsid1.));
%let rc2 = %sysfunc(close(&dsid2.));

%if %quote(&vlist.) eq %then %do;
    %put ==================================================;
    %put There are no variables in common going to be compared.;
    %put ==================================================;
    %goto exit;
%end;

%*Output report;
%let tname1 = work._tmptable1_;
%let tname2 = work._tmptable2_;
proc sort data=&base.(keep=&by. &vlist.) out=&tname1.; by &by.; run;
proc sort data=&comp.(keep=&by. &vlist.) out=&tname2.; by &by.; run;

data &result.;
merge
&tname1.(rename=(%let i = 1; %do %until(%qscan(&vlist.,&i.) eq); %scan(&vlist.,&i.)=_1_&i._ %let i = %eval(&i.+1); %end;) in=_in1_)
&tname2.(rename=(%let i = 1; %do %until(%qscan(&vlist.,&i.) eq); %scan(&vlist.,&i.)=_2_&i._ %let i = %eval(&i.+1); %end;) in=_in2_)
;
by &by.;
%if %lowcase(&join.)=left %then %str(if _in1_;);
%else %if %lowcase(&join.)=right %then %str(if _in2_;);
%else %if %lowcase(&join.)=full %then %str(if _in1_ or _in2_;);
%else %if %lowcase(&join.)=inner %then %str(if _in1_ and _in2_;);

%let dsid1 = %sysfunc(open(&tname1.));
%let dsid2 = %sysfunc(open(&tname2.));

length Var_Type $1. Var_Name $32. Base Comp $%sysfunc(max(32, %sysfunc(translate(&vlen1.,%str(,),%str( ))), %sysfunc(translate(&vlen2.,%str(,),%str( ))))).;

%let i = 1;
%do %until(%qscan(&vlist.,&i.) eq);
    var_type = "%sysfunc(vartype(&dsid1.,%sysfunc(varnum(&dsid1.,%scan(&vlist.,&i.)))))";
    var_name = "%scan(&vlist.,&i.)";
    %if %lowcase(%sysfunc(vartype(&dsid1.,%sysfunc(varnum(&dsid1.,%scan(&vlist.,&i.)))))) = n %then %do;
        base = cats(_1_&i._);
        comp = cats(_2_&i._);
    %end;
    %else %do;
        %*Leading blanks make difference;
        base = (_1_&i._);
        comp = (_2_&i._);
    %end;
    if base ne comp then output &result.;
    %let i = %eval(&i.+1);
%end;

%let rc1 = %sysfunc(close(&dsid1.));
%let rc2 = %sysfunc(close(&dsid2.));

keep &by. var_type var_name base comp;
run;

proc sql;
%if %sysfunc(exist(&tname1.)) %then drop table &tname1.;;
%if %sysfunc(exist(&tname2.)) %then drop table &tname2.;;
quit;

%put ==================================================;
%if &n. eq 1 %then %put There is &n. variable to be compared.;
%else %if &n. gt 1 %then %put There are &n. variables to be compared.;
%if &n. eq 1 %then %put It is: &vlist.;
%else %if &n. gt 1 %then %put They are: &vlist.;
%put ==================================================;
%exit:
%mend compare;
