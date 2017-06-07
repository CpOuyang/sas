%macro paste(string1, string2, innersep=, outersep=%str( ));
%*Inherit from base::paste of R but not exactly the same (in repeatness);
%*&innersep. indicates the seperator joining components, while &outersep. indicates the output answer.;
%*Also, restrict the seperators of sting1/string2 to blanks.;
%local ilen ilen1 ilen2 ans;
%do i = 1 %to 2;
    %if %bquote(&&string&i..) eq %then %let ilen&i. = 0;
    %else %do %while(%qscan(%nrbquote(&&string&i..), %eval(&&ilen&i..+1), %str( )) ne); %let ilen&i. = %eval(&&ilen&i..+1); %end;
%end;
%if &ilen1. < &ilen2. %then %let ilen = &ilen2.; %else %let ilen = &ilen1.;

%if &ilen. %then %do i = 1 %to &ilen.;
    %if &i. = 1 %then %let ans = %qscan(%nrbquote(&string1.),
         %sysfunc(ifn(%sysfunc(mod(&i.,&ilen1.)),%sysfunc(mod(&i.,&ilen1.)),&ilen1.)),%str( ))&innersep.%qscan(%nrbquote(&string2.),
         %sysfunc(ifn(%sysfunc(mod(&i.,&ilen2.)),%sysfunc(mod(&i.,&ilen2.)),&ilen2.)),%str( ));
    %else %let ans = &ans.&outersep.%qscan(%nrbquote(&string1.),
         %sysfunc(ifn(%sysfunc(mod(&i.,&ilen1.)),%sysfunc(mod(&i.,&ilen1.)),&ilen1.)),%str( ))&innersep.%qscan(%nrbquote(&string2.),
         %sysfunc(ifn(%sysfunc(mod(&i.,&ilen2.)),%sysfunc(mod(&i.,&ilen2.)),&ilen2.)),%str( ));
%end;
&ans.
%mend paste;
