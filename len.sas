%macro len(string, sep=%str( ));
%local ans;
%if %nrbquote(&string.) eq %then %let ans = 0;
%else %do %while(%qscan(%nrbquote(&string.), %eval(&ans.+1), %nrbquote(&sep.)) ne); %let ans = %eval(&ans.+1); %end;
&ans.
%mend len;
