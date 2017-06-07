%macro get_varname(dstname,
                   type=,
                   pattern=,
                   xpattern=,
                   exclude=,
                   since=,
                   until=,
                   mod=1024,
                   segment=0) / minoperator;
%*This macro is design to restrieve variable names of a certain dataset in which conditions must stand at the SAME time;
%*&type. = %str( )|all|n|c|num|char|numeric(s)|character(s);
%*However, this macro has tried to overcome the excessive amount of variables in big data but in vain.;
%*This results from the fuxking damn bug of the limitation of 65,534 of any macro variable in the final output step, not my limited talent.;
%*To compromise, we designed &mod and &segment macro variables to indicate the returning segments of all variables (if necessary).;
%local dsid nvars varname i j;
%let dsid = %sysfunc(open(&dstname.));
%if not &dsid. %then %goto exit;
%let nvars = %sysfunc(attrn(&dsid., nvars));
%if not &nvars. %then %goto exit;
%do i = 1 %to %sysfunc(ceil(%sysevalf(&nvars. / &mod.)));
    %local varnames&i.;
%end;

%do i = 1 %to &nvars.;
    %let varname = %sysfunc(varname(&dsid., &i.));
    %*Note that IN operator cannot be used on expressions including blanks, hence the leading and trailing underscores are necessary;
    %if not (%bquote(&type.) eq or %qlowcase(&type.) eq all
        or %qlowcase(_&type._) in _n_ _num_ _numeric_ _numerics_ and %lowcase(%sysfunc(vartype(&dsid., &i.))) eq n
        or %qlowcase(_&type._) in _c_ _char_ _character_ _characters_ and %lowcase(%sysfunc(vartype(&dsid., &i.))) eq c) %then %goto ignore;
    %if not (%sysfunc(prxmatch(/%qlowcase(&pattern.)/, %qlowcase(&varname.)))) %then %goto ignore;
    %if not (%bquote(&xpattern.) eq or not %sysfunc(prxmatch(/%qlowcase(&xpattern.)/, %qlowcase(&varname.)))) %then %goto ignore;
    %if not (%bquote(&exclude.) eq or not (%qlowcase(&varname.) in %qlowcase(&exclude.) ...)) %then %goto ignore;
    %if %bquote(&since.) ne %then %if not (%sysfunc(varnum(&dsid., %scan(%bquote(&since.), 1, %str( )))) le %sysfunc(varnum(&dsid., &varname.))) %then %goto ignore;
    %if %bquote(&until.) ne %then %if not (%sysfunc(varnum(&dsid., &varname.)) le %sysfunc(varnum(&dsid., %scan(%bquote(&until.), 1, %str( ))))) %then %goto ignore;
    %queue:
    %let j = %eval(%sysfunc(int(%eval(&i. - 1) / &mod.)) + 1);
    %if %bquote(&&varnames&j..) eq %then %let varnames&j. = &varname.;
    %else %let varnames&j. = &&varnames&j.. &varname.;
    %ignore:
%end;
%let i = %sysfunc(close(&dsid.));
%do i = 1 %to %sysfunc(ceil(%sysevalf(&nvars. / &mod.)));
    %if &i. in &segment. or &segment. = 0 %then %cmpres(&&varnames&i..);
%end;
%exit:
%mend get_varname;
