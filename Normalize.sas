%macro normalize_address(input, address, output, normalized, keep=, mod=10000, batch=1) / minoperator;
%local dsid vars i;
%if &normalized.= %then %let normalized = %sysfunc(propcase(normalized));
%let dsid = %sysfunc(open(&input.));
    %if &dsid. %then %do i = 1 %to %sysfunc(attrn(&dsid.,nvars));
        %let vars = &vars. %sysfunc(varname(&dsid.,&i.));
    %end;
%let dsid = %sysfunc(close(&dsid.));

%*部分規則引用多次，故提前宣告;
%local rule_newvillage;
%let rule_newvillage = s/^((..){2}?|功學社|長庚醫謢)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|\d)+村|(新村)(?!路)|新屯|(新城)(?!街))//;

data &output.;
%*PK;
length obs 8;
%if &mod. ne and &batch. ne %then %do;
set &input.(firstobs=%sysevalf((&batch. - 1) * &mod. + 1) obs=%sysevalf(&mod. * &batch.));
%end; %else %do;
set &input.;
%end;

obs = %sysevalf((&batch. - 1) * &mod.) + _n_;
if missing(&address.) then goto exit;

_address = &address.;
_sort = _address;

%*全形數字;
_sort = ktranslate(_sort, "0", "０", "1", "１", "2", "２", "3", "３", "4", "４", "5", "５", "6", "６", "7", "７", "8", "８", "9", "９");

%*俗難字轉換;
_sort = ktranslate(_sort,
    "一", "ㄧ", "台", "臺",
    "市", "巿", "豐", "丰",
    "峰", "峯", "雙", "双",
    "鹽", "塩", "穀", "榖",
    "群", "羣", "館", "舘",
    "屯", "邨", "部", "廍",
    "溫", "温", "銀", "银",
    "號", "号");
%*就是你不要跑(注意 0x9AB6 非 廍，0xB9F8 非 廓);
_sort = prxchange("s/(大|小|上|下)(康|槺|慷|\?|\*|？|＊|木康)(榔)/$1康$3/", 1, strip(_sort));
_sort = prxchange("s/(康|槺|慷|\?|\*|？|＊|木康)(榔)(村|里)/康$2$3/", 1, strip(_sort));
_sort = prxchange("s/(半|新|舊|寮|後|糖|蔗|寶|頂|南|下)(部|\x9A\xB6|\xB9\xF8|廍|廓|\?|\*|？|＊)(里|路)/$1部$3/", 1, strip(_sort));
%*將&master.中的&xid.圖騰擷取出來放在&out.，可選擇清空&master.與否;
%macro extract(master, out, xid=_xid, i=_i, j=_j, remove=1);
if prxmatch(&xid., &master.) then do;
    call prxsubstr(&xid., &master., &i., &j.);
    if 0 then &out. = &master.;
    if &j. and missing(&out.) then &out. = substr(&master., &i., &j.);
    %if &remove. %then &master. = prxchange(&xid., 1, &master.)%str(;);
end;
%mend extract;

%*移除空白(0x20)，全形空白(0xA140);
_sort = prxchange("s/(\x20|\xA1\x40|。|\?{3,}|TW|ＴＷ)//", -1, _sort);
%*移除其他不必要括號註記，其中0xA15D表全形前括號，0xA15E表全形後括號，括號亦可能只有前半;
_sort = ktranslate(_sort, "（", "(", "）", ")");
_sort = prxchange("s/\xa1\x5d.+\xa1\x5e//", -1, strip(_sort));
_sort = prxchange("s/\xa1\x5d.+//", -1, strip(_sort));
%*前字串相同重覆(3至8個DBCS);
%do i = 6 %to 16 %by 2;
if not missing(_sort) and substr(_sort, 1, &i.) =: substr(_sort, %eval(&i.+1)) then _sort = substr(_sort, %eval(&i.+1));
%end;
%*郵政信箱;
_xid = prxparse("s/(.{4}?(鄉|鎮|市|區)*|金六結|高山頂|玉里|.{4}?大學)(郵政|郵局).+信箱//");
%extract(_sort, postadd)
_xid = prxparse("s/(.{4}?(鄉|鎮|市|區)*)(郵政|郵局)信箱.+號//");
%extract(_sort, postadd)
%*修正簡寫;
_sort = prxchange("s/^基市/基隆市/", 1, strip(_sort));
_sort = prxchange("s/^北市/台北市/", 1, strip(_sort));
_sort = prxchange("s/^北縣/台北縣/", 1, strip(_sort));
_sort = prxchange("s/^桃縣/桃園縣/", 1, strip(_sort));
_sort = prxchange("s/^園縣/桃園縣/", 1, strip(_sort));
_sort = prxchange("s/^中市/台中市/", 1, strip(_sort));
_sort = prxchange("s/^中縣/台中縣/", 1, strip(_sort));
_sort = prxchange("s/^嘉縣/嘉義縣/", 1, strip(_sort));
_sort = prxchange("s/^南市/台南市/", 1, strip(_sort));
_sort = prxchange("s/^高市/高雄市/", 1, strip(_sort));
_sort = prxchange("s/^高縣/高雄縣/", 1, strip(_sort));
_sort = prxchange("s/^宜縣/宜蘭縣/", 1, strip(_sort));
_sort = prxchange("s/^蘭縣/宜蘭縣/", 1, strip(_sort));
_sort = prxchange("s/^花市/花蓮市/", 1, strip(_sort));
_sort = prxchange("s/^花縣/花蓮縣/", 1, strip(_sort));
_sort = prxchange("s/^(新竹)(科學園區)/$1市$2/", 1, strip(_sort));
%*錯別字我盡量;
_sort = prxchange("s/^(台北|新北|新竹|台中|嘉義|台南|高雄)(?!縣|市)(是|事|世|式|室|勢|示|識|仕|巾|士(?!林)|失|施|師|詩)(.*)/$1市$3/", 1, strip(_sort));
_sort = prxchange("s/^(台北|桃園|新竹|苗栗|台中|彰化|南投|雲林|嘉義|台南|高雄|屏東|宜蘭|花蓮|台東|澎湖)(?!縣|市)(限|線|現|憲|羨|先)(.*)/$1縣$3/", 1, strip(_sort));
_sort = prxchange("s/^(薪|欣)(北市)(.*)/新$2$3/", 1, strip(_sort));
%*未寫明一級行政區;
_sort = prxchange("s/^(台北|新竹|台中|嘉義|台南|高雄)(?!縣|市)(東|南|西|北|....)(區)(.*)/$1市$2$3$4/", 1, strip(_sort));
_sort = prxchange("s/^(台北|桃園|新竹|苗栗|台中|彰化|南投|雲林|嘉義|台南|高雄|屏東|宜蘭|花蓮|台東|澎湖)(?!縣|市)(....)(鄉|鎮|市)(.*)/$1縣$2$3$4/", 1, strip(_sort));
%*調整省轄市重覆或謬誤問題;
_sort = prxchange("s/(基隆市|新竹市|嘉義市)*/$1/", 1, strip(_sort));
_sort = prxchange("s/^(台北縣|新北市|基隆縣)*(基隆市)/$2/", 1, strip(_sort));
_sort = prxchange("s/^(新竹縣)*(新竹市)/$2/", 1, strip(_sort));
_sort = prxchange("s/^(嘉義縣)*(嘉義市)/$2/", 1, strip(_sort));
%*只寫縣轄市，亦有重覆、顛倒問題;
_sort = prxchange("s/(彰化市)*/$1/", 1, strip(_sort));
_sort = prxchange("s/^(彰化市)(彰化縣)*/彰化縣彰化市/", 1, strip(_sort));
_sort = prxchange("s/(花蓮市)*/$1/", 1, strip(_sort));
_sort = prxchange("s/^(花蓮市)(花蓮縣)*/花蓮縣花蓮市/", 1, strip(_sort));
%*調整直轄市重覆或謬誤問題;
_sort = prxchange("s/^(台北市|台中市|台南市|高雄市)*/$1/", 1, strip(_sort));
_sort = prxchange("s/^(台北縣|高雄縣)*(台北市|高雄市)/$2/", 1, strip(_sort));
%*改制專區;
_sort = prxchange("s/^(桃園縣)*(楊梅鎮)/$1楊梅市/", 1, strip(_sort));
_sort = prxchange("s/(楊梅)(?!(鎮|市))/楊梅市/", 1, strip(_sort));
_sort = prxchange("s/^(高雄市)*(那瑪夏(鄉|區))/$1那瑪夏區/", 1, strip(_sort));
_sort = prxchange("s/(那瑪夏)(?!(區|鄉))/那瑪夏區/", 1, strip(_sort));

%**************************************************************************************************;
%*擷取縣市，正 + 三 = 0x45 + 縣 + 0x54;
_xid = prxparse("s/^(..){1,2}(縣|市){1}?//");
%extract(_sort, county)

%*清理多餘郵遞區號，5碼即視為郵區，3碼可能為地籍資訊;
_sort = prxchange("s/^(\d{5}?|(\d{3}?)(?!(鄰|巷|弄|號|之|樓)))//", 1, strip(_sort));

%*擷取鄉鎮市區，慣例：三個字以上(太麻里、三地門、阿里山)不寫鄉、新竹市科學園區園區二路，反例：新竹市園區二路;
_sort = prxchange("s/^(太麻里|三地門|阿里山)(鄉)*/$1鄉/", 1, _sort);
_xid = prxparse("s/^(前鎮區|平鎮市|新市區)//");
%extract(_sort, town)

%*先排除(工業區|園區)，特例：鎮北里(鎮+北路)、北鎮街;
town = ifc(prxmatch("/^鎮北里|北鎮街/", strip(_sort)), "null", town);
if missing(town) then do;
    _xid = prxparse("s/^.{2}?(?<!園)(區){1}?//");
    %extract(_sort, town)
    _xid = prxparse("s/^.{4}?(?<!(科學|工業|園區))(鄉|鎮|市|區){1}?//");
    %extract(_sort, town)
    _xid = prxparse("s/^.{6}?(?<!(科學|工業|園區|新竹)園)(鄉|鎮|市|區){1}?//");
    %extract(_sort, town)
end;
town = ifc(town = "null", "", town);

%*清理多餘郵遞區號，5碼必為郵區，3碼可能為地籍資訊;
_sort = prxchange("s/^(\d{5}?|(\d{3}?)(?!(鄰|巷|弄|號|之|樓)))//", 1, strip(_sort));

%macro extract_newvillage;
%*擷取新村，先排除新村(新屯)，若全住址只有 新村+號 則保留之後為local，此段有可能在里之後，所以後面再做一次;
_xid = prxparse("&rule_newvillage.");
%extract(_sort, newvillage)
%mend extract_newvillage;

%macro extract_village;
%*擷取村里。楊賢路：楊+賢 = 0xB7+里+0xE5，故以(..)取代全型字;
_xid = prxparse("s/^((里港|嘉里)村|錦村里|新里里|達卡努瓦里)//");
%extract(_sort, village)
%*避免：佳里村、東里一(0xA440)街、里林東路、萬里加(0xA55B)投、佳里興等 非村里意涵的村、道;
village = ifc(prxmatch("/^(萬里\xa5\x5b投|佳里興|松村巷|美村南路|前村東路|里(港|仁|義|順|林東)路|村(中|市)路|美村巷|\xa4\x40村巷)/", strip(_sort)), "null", village);
%*先做長度<=3，再做長度=4：甲南里(村中路);
if missing(village) then do;
    %*村 不能放入(?!...)：平和村村民巷=>平和村村;
    _xid = prxparse("s/^(..){0,2}(里|村)(?!(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|\d+)*(路|街))|六路里//");
    if missing(village) then do; %extract(_sort, village) end;
    _xid = prxparse("s/^(..){3}?(里|村)(?!(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|\d+)*(路|街))//");
    if missing(village) then do; %extract(_sort, village) end;
end;
village = ifc(village = "null", "", village);
%mend extract_village;

%macro extract_neighbor;
%*擷取鄰，須轉換國數字，且鄰有可能與路街錯置;
_xid = prxparse("s/^(第)*(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|百|\d)+鄰//");
%extract(_sort, _tmp1)
%*轉換鄰的國數字為阿拉伯數字;
neighbor = input(prxchange("s/[^\d]//", -1, strip(zhnum2arabic(_tmp1))), 12.);
%mend extract_neighbor;

%extract_newvillage

%extract_village

%extract_neighbor

%extract_newvillage
%**************************************************************************************************;
%*這一區塊要放到路街以前;
%*移除 加(0xA55B)工出口區、產業園區;
_sort = prxchange("s/^(....)?(\xA5\x5B工出口區)|新北(市)?產業園區//", 1, strip(_sort));
%*移除 園區+非國數字 特例：南港區(園區街)、五股區工業區(三民路|四維路|五(權|工)(..)*路);
_sort = prxchange("s/^(..){0,6}(園區)(?!(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d|街)+)//", 1, strip(_sort));
_sort = prxchange("s/^(..){0,6}(工業區)(三民路|\xa5\x7c維路|五(權|工)(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|\d)*路)/$3/", 1, strip(_sort));
_sort = prxchange("s/^(..){0,6}(工業區|\xa5\x5b工區)(?!(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)//", 1, strip(_sort));
%*修正懶人寫法：新竹科學(園區二路)、朴子(工業區二路)，特例：台塑工業園區5號，由於 號 有可能二位數，無法用prxchange()一次寫出來;
_sort = ifc(prxmatch("/^(..){2,6}(園區|工業區)(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+(之(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|\d)+)*號/", strip(_sort)), _sort,
    prxchange("s/^(..){2,6}(園區|工業區)(?=(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)/$2/", 1, strip(_sort)));

%*擷取道路，會有阿拉伯數字：中正2路，特例：三重區(車路頭街)等，故不使用(..);
_xid = prxparse("s/^(大道路|立道路|公道五路|鐵道(南|北)路|明道(中|五)街|長道坑路)//");
%extract(_sort, road)
road = ifc(prxmatch("/^((鐵|東|西)路街|車路(頭)?街|(衛|弘|正|宏|大|厚|中)道街|東舊路街)/", strip(_sort)), "null", road);
%do i = 1 %to 12;
if missing(road) then do;
    _xid = prxparse("s/^.{&i.}?(道|路)//");
    %extract(_sort, road)
end;
%end;
road = ifc(road = "null", "", road);
%*有部分奇怪的殘餘阿拉伯數字，疑似系統問題：1中正路，例外：20張路;
road = prxchange("s/^(\d+)(?!道|路|街|巷|弄|號|樓|之|張路|\d)//", -1, strip(road));
%*轉換路街的阿拉伯數字為國數字;
road = arabic2zhnum(road);

%*另取街，街 與 道|路 列不同層級是因道與街可能同時並存;
if 0 then street = _sort;
%do i = 1 %to 12;
if missing(street) then do;
    _xid = prxparse("s/^.{&i.}?(街)//");
    %extract(_sort, street)
end;
%end;
street = arabic2zhnum(street);

%extract_village

%extract_neighbor

%extract_newvillage

%*擷取路段，合法最高：台中市台灣大道十段，但也有文字段：龍潭鄉中豐路(高平段);
%*簡言之，段/巷/弄 皆有文字型態與數字型態;
%macro get_numorchar(name=section, token=段, tmp=_tmp4);
_xid = prxparse("s/^.{1,10}(&token.)//");
%extract(_sort, &name._str)
%*順手移除可疑的之巷、之弄;
&tmp. = zhnum2arabic(prxchange("s/(之|-|–|－)(\d+)(巷|弄)/$3/", 1, strip(&name._str)));
&name. = ifn(prxmatch("/^\d+&token.$/", strip(&tmp.)), input(prxchange("s/[^\d]//", -1, strip(&tmp.)), 12.), .);
%*調整可能包含 地方+數字巷 者為阿拉伯數字巷;
&name._str = ifc(not missing(&name.), "", ifc(prxmatch("/(\d\d\d|[4-9]\d)/", zhnum2arabic(strip(&name._str))), zhnum2arabic(&name._str), arabic2zhnum(&name._str)));
%mend get_numorchar;

%get_numorchar(name=section, token=段, tmp=_tmp4)

%extract_village

%extract_neighbor

%get_numorchar(name=lane   , token=巷, tmp=_tmp5)
%get_numorchar(name=alley  , token=弄, tmp=_tmp6)
%get_numorchar(name=long   , token=衖, tmp=_tmp7)

%*擷取地方、前之號與號;
if 0 then prenumber = _sort;
if 0 then _tmp8 = _sort;
_xid = prxparse("/(臨)?(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|百|\d)+((之|-|–|－)(零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|百|\d)+)?號/");
if prxmatch(_xid, strip(_sort)) then do;
    call prxsubstr(_xid, strip(_sort), _i, _j);
    if 1 < _i then prenumber = substr(_sort, 1, _i - 1);
    if 1 <= _i then _tmp8 = substr(_sort, _i, _j);
    if _i then _sort = substr(_sort, _i + _j);
end;

%*注意\d+要再被包起來，否則$n只能抓到末位數 (call prxsubstr()不受限);
next = ifn(prxmatch("/^臨/", strip(_tmp8)), 1, 0);
number = input(zhnum2arabic(prxchange("s/^(臨)?((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|百|\d)+)((之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|百|\d)+))?號/$2/", 1, strip(_tmp8))), 12.);
subnumber = input(zhnum2arabic(prxchange("s/^(臨)?((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|百|\d)+)((之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|百|\d)+))?號/$6/", 1, strip(_tmp8))), 12.);

%*擷取後之號，客戶通常以寫法不同來區隔樓層，有時也會混為一談，只能分開討論。注意(.*)$必須含入，否則INPUT()轉數字會錯誤;
%*之3: subsub=3;
if prxmatch("/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)(?!樓)(.*)$/", strip(_sort)) then do;
    subsubnumber = input(zhnum2arabic(prxchange("s/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)(?!樓)(.*)$/$2/", 1, strip(_sort))), 12.);
    _sort = prxchange("s/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)(?!樓)(.*)$/$4/", 1, strip(_sort));
end;
%*之3五樓: subsub=3, _sort=五樓;
else if prxmatch("/^(之|-|–|－)(\d+)(((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅)+)樓)(.*)$/", strip(_sort)) then do;
    subsubnumber = input(prxchange("s/^(之|-|–|－)(\d+)(((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅)+)樓)(.*)$/$2/", 1, strip(_sort)), 12.);
    _sort = prxchange("s/^(之|-|–|－)(\d+)(((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅)+)樓)(.*)$/$3$6/", 1, strip(_sort));
end;
%*之三5樓: subsub=3, _sort=5樓;
else if prxmatch("/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅)+)((\d+)樓)(.*)$/", strip(_sort)) then do;
    subsubnumber = input(zhnum2arabic(prxchange("s/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅)+)((\d+)樓)(.*)$/$2/", 1, strip(_sort))), 12.);
    _sort = prxchange("s/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅)+)((\d+)樓)(.*)$/$4$6/", 1, strip(_sort));
end;
%*之..135樓: subsub=..1, _sort=35樓;
else if prxmatch("/^(之|-|–|－)(\d{1,}?)((\d{2}?)樓)(.*)$/", strip(_sort)) then do;
    subsubnumber = input(prxchange("s/^(之|-|–|－)(\d{1,}?)((\d{2}?)樓)(.*)$/$2/", 1, strip(_sort)), 12.);
    _sort = prxchange("s/^(之|-|–|－)(\d{1,}?)((\d{2}?)樓)(.*)$/$3$5/", 1, strip(_sort));
end;
%*之35樓: subsub=3, _sort=5樓;
else if prxmatch("/^(之|-|–|－)(\d)((\d)樓)(.*)$/", strip(_sort)) then do;
    subsubnumber = input(prxchange("s/^(之|-|–|－)(\d)((\d)樓)(.*)$/$2/", 1, strip(_sort)), 12.);
    _sort = prxchange("s/^(之|-|–|－)(\d)((\d)樓)(.*)$/$3$5/", 1, strip(_sort));
end;
%*之5樓: subsub=., _sort=5樓;
else if prxmatch("/^(之|-|–|－)((\d)樓)(.*)$/", strip(_sort)) then do;
    subsubnumber = .;
    _sort = prxchange("s/^(之|-|–|－)((\d)樓)(.*)$/$2$4/", 1, strip(_sort));
end;
%*其他可能;
else if prxmatch("/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+樓)(.*)$/", strip(_sort)) then do;
    subsubnumber = .;
    _sort = cats(zhnum2arabic(prxchange("s/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+樓)(.*)$/$2/", 1, strip(_sort)))
                ,prxchange("s/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+樓)(.*)$/$4/", 1, strip(_sort)));
end;

%*擷取樓層;
_xid = prxparse("s/^(地下)*((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)((之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+))?(樓|Ｆ|ｆ|F|f)//");
%extract(_sort, _tmp9)
floor = input(strip(prxchange("s/^(地下)*((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)((之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+))?(樓|Ｆ|ｆ|F|f)/$2/", 1, zhnum2arabic(_tmp9))), 12.);
subfloor = input(strip(prxchange("s/^(地下)*((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)((之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+))?(樓|Ｆ|ｆ|F|f)/$6/", 1, zhnum2arabic(_tmp9))), 12.);
floor = ifn(prxmatch("/地下/", _tmp9), -1 * sum(0, floor), floor);
%*殘餘樓層;
_xid = prxparse("s/((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)(樓|Ｆ|ｆ|F|f)//");
%extract(_sort, _tmp10)
floor = ifn(missing(floor), input(strip(prxchange("s/((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)(樓|Ｆ|ｆ|F|f)/$1/", 1, zhnum2arabic(_tmp10))), 12.), floor);

%*擷取之樓;
_xid = prxparse("s/^(之|-|–|－)((零|○|一|二|三|\xa5\x7c|五|六|七|八|九|十|廿|卅|\d)+)//");
%extract(_sort, _tmp11)
subsubfloor = input(strip(prxchange("s/[^\d]//", -1, zhnum2arabic(_tmp11))), 12.);

postfloor = _sort;

%*2010四都升格調整;
if prxmatch("/^(台北|台中|台南|高雄)縣$/", strip(county)) then do;
    county = prxchange("s/縣/市/", 1, prxchange("s/台北/新北/", 1, strip(county)));
    town = prxchange("s/(鄉|鎮|市)$/區/", 1, strip(town));
    village = prxchange("s/村$/里/", 1, strip(village));
end;

%*REMARK1: 鄰之後，如果沒有任何的資訊包含道路、街、(文字)段、(文字)巷、(文字)弄、地方，則應保留：新村，後接 號;
%*REMARK2: 對位軟體的村里+鄰，配上地方似乎會有問題，地方型態的地址以 縣市+鄉鎮市區+地方+號 較容易命中;
if 0 then %sysfunc(propcase(&normalized., _)) = _sort;

&normalized. = cats(""
    ,county
    ,town
/*    ,village*/
/*    ,ifc(missing(neighbor), "", cats(neighbor, "鄰"))*/
    ,road
    ,street
    ,ifc(missing(section_str) and missing(section), "", ifc(missing(section), section_str, arabic2zhnum(cats(section, "段"))))
    ,ifc(missing(lane_str) and missing(lane), "", ifc(missing(lane), lane_str, cats(lane, "巷")))
    ,ifc(missing(alley_str) and missing(alley), "", ifc(missing(alley), alley_str, cats(alley, "弄")))
    ,ifc(missing(long_str) and missing(long), "", ifc(missing(long), long_str, cats(long, "衖")))
    ,prenumber
    ,ifc(nmiss(lane, alley, long) = 3 and missing(cats(road, street, lane_str, alley_str, long_str, prenumber)), newvillage, "")
    ,ifc(missing(number) and missing(subnumber) and missing(subsubnumber), "",
        cats(ifc(next, "臨", ""), number, ifc(missing(subnumber), "", cats("-", subnumber)), "號", ifc(missing(subsubnumber), "", ifc(missing(subsubnumber), "", cats("-", subsubnumber)))))
    ,ifc(missing(floor) and missing(subfloor) and missing(subsubfloor), "",
        arabic2zhnum(cats(floor, ifc(missing(subfloor), "", cats("之", subfloor)), "樓", ifc(missing(subsubfloor), "", cats("之", subsubfloor)))))
);

/*%*針對對位程式的BUG，以下調整路中有區，或路中有里，縣市以上才調整;*/
/*%*台中市南屯區;*/
/*&normalized. = prxchange("s/^(台中市)(工業區二十\xA4\x40路|工業區二十七路|工業區二十三路|工業區二十二路|工業區二十五路|工業區二十六路|工業區二十\xA5\x7C路|工業區二十路|工業區十九路|工業區十八路)/$1南屯區$3/", 1, strip(&normalized.));*/
/*%*台中市烏日區;*/
/*&normalized. = prxchange("s/^(台中市)(站區\xA4\x40路|站區二路)/$1烏日區$3/", 1, strip(&normalized.));*/
/*%*台中市西屯區;*/
/*&normalized. = prxchange("s/^(台中市)(工業區\xA4\x40路|工業區七路|工業區三十\xA4\x40路|工業區三十七路|工業區三十三路|工業區三十九路|工業區三十二路|工業區三十五路)/$1西屯區$3/", 1, strip(&normalized.));*/
/*&normalized. = prxchange("s/^(台中市)(工業區三十八路|工業區三十六路|工業區三十\xA5\x7C路|工業區三十路|工業區三路|工業區九路|工業區二十七路|工業區二十九路)/$1西屯區$3/", 1, strip(&normalized.));*/
/*&normalized. = prxchange("s/^(台中市)(工業區二十八路|工業區二路|工業區五路|工業區八路|工業區六路|工業區十\xA4\x40路|工業區十七路|工業區十三路|工業區十二路)/$1西屯區$3/", 1, strip(&normalized.));*/
/*&normalized. = prxchange("s/^(台中市)(工業區十五路|工業區十六路|工業區十\xA5\x7C路|工業區十路|工業區\xA5\x7C十\xA4\x40路|工業區\xA5\x7C十二路|工業區\xA5\x7C十路|工業區\xA5\x7C路)/$1西屯區$3/", 1, strip(&normalized.));*/
/*%*新北市板橋區;*/
/*&normalized. = prxchange("s/^(新北市)(區運路)/$1板橋區$3/", 1, strip(&normalized.));*/
/*%*新北市林口區;*/
/*&normalized. = prxchange("s/^(新北市)(工七路|工三路|工九路|工\xA5\x7C路|工五路|工八路|工六路)/$1林口區$3/", 1, strip(&normalized.));*/
/*%*新竹市東區;*/
/*&normalized. = prxchange("s/^(新竹市)(園區\xA4\x40路|園區二路|園區五路)/$1東區$3/", 1, strip(&normalized.));*/
/*%*高雄市前鎮區;*/
/*&normalized. = prxchange("s/^(高雄市)(環區\xA4\x40路|環區三路|環區\xA5\x7C路)/$1前鎮區$3/", 1, strip(&normalized.));*/
/*%*高雄市楠梓區;*/
/*&normalized. = prxchange("s/^(高雄市)(區東路)/$1楠梓區$3/", 1, strip(&normalized.));*/
/*%*台中市后里區;*/
/*&normalized. = prxchange("s/^(台中市)(后里路|梅里路)/$1后里區$3/", 1, strip(&normalized.));*/
/*%*台中市大里區;*/
/*&normalized. = prxchange("s/^(台中市)(大里路|東里路)/$1大里區$3/", 1, strip(&normalized.));*/
/*%*高雄市橋頭區;*/
/*&normalized. = prxchange("s/^(高雄市)(里林西路|里林東路)/$1橋頭區$3/", 1, strip(&normalized.));*/
/*%*高雄市甲仙區;*/
/*&normalized. = prxchange("s/^(高雄市)(五里路)/$1甲仙區$3/", 1, strip(&normalized.));*/

%*drop &vars. _i _j _xid _tmp:;
keep obs &keep. &address. &normalized.;

exit:
run;
%mend normalize_address;

/*%normalize_address(pool.wii_data_register, register_address, pool.tmp, register_address_nz, mod=10000)*/

/*data sim;*/
/*length add $90;*/
/*add = "台中市工業區一路58巷11弄36號三樓之六";output;*/
/*run;*/
/**/
/*%normalize_address(sim, add, tmp)*/
