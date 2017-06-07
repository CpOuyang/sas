%macro cleanse(dstname, dt_adjust=1);
%*&dt_adjust. determines whether perform date/time adjust;
%local dsid str_date str_time i;
%if not %index(&dstname., .) %then %let dstname = work.&dstname.;
%let dsid = %sysfunc(open(&dstname.));
%if not &dsid. %then %goto exit;
%do i = 1 %to %sysfunc(attrn(&dsid., nvars));
    %if %lowcase(%sysfunc(vartype(&dsid., &i.))) = n and %sysfunc(prxmatch(/_(date|dt)$/, %lowcase(%sysfunc(varname(&dsid., &i.)))))
        %then %let str_date = &str_date. %sysfunc(varname(&dsid., &i.));
    %if %lowcase(%sysfunc(vartype(&dsid., &i.))) = n and %sysfunc(prxmatch(/^(snapshot_yr_mth|date_of_birth)$/, %lowcase(%sysfunc(varname(&dsid., &i.)))))
        %then %let str_date = &str_date. %sysfunc(varname(&dsid., &i.));
    %if %lowcase(%sysfunc(vartype(&dsid., &i.))) = n and %sysfunc(prxmatch(/_(time)$/, %lowcase(%sysfunc(varname(&dsid., &i.)))))
        %then %let str_time = &str_time. %sysfunc(varname(&dsid., &i.));
%end;
%let i = %sysfunc(close(&dsid.));

proc datasets nolist lib=%scan(&dstname., 1, .);
modify %scan(&dstname., 2, .);
    attrib _all_ informat= format= label="";
    %if &dt_adjust. %then %do;
        %if %bquote(&str_date.) ne %then attrib &str_date. format=yymmdd10.%str(;);
        %if %bquote(&str_time.) ne %then attrib &str_time. format=time8.%str(;);
    %end;
quit;
%exit:
%mend cleanse;
