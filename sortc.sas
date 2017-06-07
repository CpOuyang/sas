%macro sortc(string, sep=%str( ));
%*An "independent" version.;
%if %nrbquote(&string.) eq %then %goto exit;
%local i ans tmp;
%let i = 1;
%do %while(%scan(%nrbquote(&string.), &i., %nrbquote(&sep.)) ne);
    %local tmp&i.;
    %let tmp&i. = %qscan(%nrbquote(&string.), &i., %nrbquote(&sep.));
    %let tmp = &tmp. tmp&i.;
    %let i = %eval(&i.+1);
%end;
%syscall sortc(%sysfunc(translate(&tmp., %str(,), %str( ))));
%let i = 1;
%do %while(%scan(%nrbquote(&string.), &i., %nrbquote(&sep.)) ne);
    %if &i. = 1 %then %let ans = %nrbquote(&&tmp&i..);
    %else %let ans = &ans.%nrbquote(&sep.)%nrbquote(&&tmp&i..);
    %let i = %eval(&i.+1);
%end;
%cmpres(&ans.)
%exit:
%mend sortc;
