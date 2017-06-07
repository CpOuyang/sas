%macro intnx(yymm, n);
%sysfunc(abs(%sysfunc(intnx(month,%sysfunc(inputn(&yymm.,yymmn4.)),&n.))),yymmn4.)
%mend intnx;
