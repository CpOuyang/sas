%macro outcsv(dstname,
              outfile,
              bom=0,
              dlm="2c"x,
              encoding=utf8,
              header=0,
              quote_header=0,
              quote_character=0,
              quote_numeric=0) / minoperator;
%local dsid nvars variables types lens;
%local i j;
%local preserves;
%let dsid = %sysfunc(open(&dstname.));
%if not &dsid. %then %goto exit;
%let nvars = %sysfunc(attrn(&dsid., nvars));
%do i = 1 %to &nvars.;
    %let variables = &variables. %sysfunc(varname(&dsid., &i.));
    %let types = &types. %sysfunc(vartype(&dsid., &i.));
    %let lens = &lens. %sysfunc(varlen(&dsid., &i.));
    %*Record labels;
    %if %qsysfunc(varlabel(&dsid., &i.)) ne %then %do;
        %local _label&i.;
        %let _label&i. = %qsysfunc(varlabel(&dsid., &i.));
    %end;
%end;
%let dsid = %sysfunc(close(&dsid.));

%*TD Aster reads no BOM;
%let preserves = &preserves. %sysfunc(getoption(bomfile));
%if not &bom. %then options nobomfile%str(;);

data _null_;
set &dstname.;
file &outfile. lrecl=65536 encoding="&encoding." %if %bquote(&dlm.) ne %then dlm=&dlm.;;
%if &header. %then %do;
    if _n_ = 1 then do;
    %let i = 1;
    %do %while(%qscan(&variables., &i.) ne);
        %if 1 < &i. %then put &dlm. @%str(;);
%*        put """%scan(&variables., &i.)""" @;
        %if %symexist(_label&i.) %then %do;
            %if &quote_header. %then put """%nrbquote(&&_label&i..)""" @%str(;);
            %else put "%nrbquote(&&_label&i..)" @%str(;);
        %end;
        %else %do;
            %if &quote_header. %then put """%scan(&variables., &i.)""" @%str(;);
            %else put "%scan(&variables., &i.)" @%str(;);
        %end;
        %let i = %eval(&i. + 1);
    %end;
    put;
    end;
%end;

%let i = 1;
%do %while(%qscan(&variables., &i.) ne);
    %if 1 < &i. %then put &dlm. @%str(;);
    %if %lowcase(%scan(&types., &i.)) = c %then %do;
        %if &quote_character. %then put """" @%str(;);
        if not missing(%scan(&variables., &i.)) then put %scan(&variables., &i.) +(-1) @;
        %if &quote_character. %then put """" @%str(;);
    %end;
    %else %if %lowcase(%scan(&types., &i.)) = n %then %do;
        %if &quote_numeric. %then put """" @%str(;);
        if not missing(%scan(&variables., &i.)) then put %scan(&variables., &i.) +(-1) @;
        %if &quote_numeric. %then put """" @%str(;);
    %end;
    %let i = %eval(&i. + 1);
%end;

put;
run;

%*Restore options;
options &preserves.;
%exit:
%mend outcsv;
