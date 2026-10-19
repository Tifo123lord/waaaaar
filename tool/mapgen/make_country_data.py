#!/usr/bin/env python3
"""Generate lib/data/country_data.dart — 36 playable nations.

Economic, demographic and military figures are *fictionalised demo values*
authored for gameplay balance, in the same spirit as the original ten.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "lib", "data", "country_data.dart"))

# id, nameEn, nameFa, shortEn, shortFa, capEn, capFa, iso, flag(3 hex),
# pop(M), ind, infra, stab, treasury, resourceIncome, budget, personality,
# res production {oil,steel,alu,rubber,food,energy}, factories (civilian,military)
C = [
 ("us","United States","ایالات متحده آمریکا","USA","آمریکا","Washington, D.C.","واشینگتن دی‌سی","US",["0xFF3C3B6E","0xFFFFFFFF","0xFFB22234"],340,118,88,61,142000,4200,1.35,"opportunist",dict(oil=42,steel=38,alu=30,rubber=9,food=62,energy=54),dict(c=9,m=6)),
 ("ca","Canada","کانادا","CAN","کانادا","Ottawa","اتاوا","CA",["0xFFD80621","0xFFFFFFFF","0xFFD80621"],40,46,86,70,52000,3600,1.05,"defensive",dict(oil=48,steel=22,alu=26,rubber=4,food=44,energy=40),dict(c=5,m=3)),
 ("mx","Mexico","مکزیک","MEX","مکزیک","Mexico City","مکزیکوسیتی","MX",["0xFF006847","0xFFFFFFFF","0xFFCE1126"],129,34,52,55,24000,2400,0.95,"opportunist",dict(oil=22,steel=12,alu=6,rubber=5,food=28,energy=16),dict(c=4,m=2)),
 ("br","Brazil","برزیل","BRA","برزیل","Brasília","برازیلیا","BR",["0xFF009C3B","0xFFFFDF00","0xFF002776"],216,48,50,56,46000,4200,0.90,"industrialist",dict(oil=18,steel=20,alu=14,rubber=14,food=58,energy=26),dict(c=6,m=3)),
 ("ar","Argentina","آرژانتین","ARG","آرژانتین","Buenos Aires","بوئنوس آیرس","AR",["0xFF74ACDF","0xFFFFFFFF","0xFF74ACDF"],46,26,54,52,14000,2600,0.85,"opportunist",dict(oil=12,steel=10,alu=6,rubber=3,food=42,energy=12),dict(c=3,m=2)),
 ("uk","United Kingdom","بریتانیا","GBR","بریتانیا","London","لندن","GB",["0xFF012169","0xFFFFFFFF","0xFFC8102E"],68,54,82,66,70000,2400,1.05,"defensive",dict(oil=14,steel=16,alu=10,rubber=3,food=20,energy=22),dict(c=6,m=4)),
 ("fr","France","فرانسه","FRA","فرانسه","Paris","پاریس","FR",["0xFF0055A4","0xFFFFFFFF","0xFFEF4135"],68,58,80,60,74000,2600,1.10,"defensive",dict(oil=6,steel=18,alu=12,rubber=3,food=34,energy=34),dict(c=6,m=4)),
 ("de","Germany","آلمان","DEU","آلمان","Berlin","برلین","DE",["0xFF000000","0xFFDD0000","0xFFFFCE00"],84,76,90,70,126000,3200,0.95,"industrialist",dict(oil=5,steel=30,alu=16,rubber=4,food=30,energy=32),dict(c=8,m=4)),
 ("it","Italy","ایتالیا","ITA","ایتالیا","Rome","رم","IT",["0xFF008C45","0xFFFFFFFF","0xFFCD212A"],59,48,74,58,52000,2200,0.95,"defensive",dict(oil=6,steel=14,alu=8,rubber=4,food=26,energy=20),dict(c=5,m=3)),
 ("es","Spain","اسپانیا","ESP","اسپانیا","Madrid","مادرید","ES",["0xFFAA151B","0xFFF1BF00","0xFFAA151B"],48,42,76,62,40000,2000,0.90,"defensive",dict(oil=3,steel=12,alu=8,rubber=3,food=28,energy=18),dict(c=4,m=2)),
 ("nl","Netherlands","هلند","NLD","هلند","Amsterdam","آمستردام","NL",["0xFFAE1C28","0xFFFFFFFF","0xFF21468B"],18,34,88,72,34000,1600,0.90,"industrialist",dict(oil=3,steel=8,alu=4,rubber=2,food=16,energy=12),dict(c=3,m=2)),
 ("se","Sweden","سوئد","SWE","سوئد","Stockholm","استکهلم","SE",["0xFF006AA7","0xFFFECC00","0xFF006AA7"],10,32,86,74,26000,1400,1.00,"defensive",dict(oil=2,steel=12,alu=6,rubber=2,food=10,energy=14),dict(c=3,m=2)),
 ("no","Norway","نروژ","NOR","نروژ","Oslo","اسلو","NO",["0xFFBA0C2F","0xFFFFFFFF","0xFF00205B"],6,28,88,76,30000,2800,1.00,"defensive",dict(oil=40,steel=8,alu=8,rubber=2,food=8,energy=22),dict(c=3,m=1)),
 ("pl","Poland","لهستان","POL","لهستان","Warsaw","ورشو","PL",["0xFFFFFFFF","0xFFDC143C","0xFFFFFFFF"],38,36,66,62,22000,1400,1.20,"defensive",dict(oil=3,steel=12,alu=6,rubber=2,food=20,energy=12),dict(c=3,m=3)),
 ("ua","Ukraine","اوکراین","UKR","اوکراین","Kyiv","کی‌یف","UA",["0xFF0057B7","0xFFFFD700","0xFF0057B7"],36,32,58,46,12000,1600,1.40,"defensive",dict(oil=4,steel=16,alu=6,rubber=2,food=34,energy=10),dict(c=3,m=3)),
 ("ru","Russia","روسیه","RUS","روسیه","Moscow","مسکو","RU",["0xFFFFFFFF","0xFF0039A6","0xFFD52B1E"],143,62,58,52,61000,4800,1.45,"expansionist",dict(oil=58,steel=32,alu=20,rubber=6,food=40,energy=52),dict(c=5,m=6)),
 ("gr","Greece","یونان","GRC","یونان","Athens","آتن","GR",["0xFF0D5EAF","0xFFFFFFFF","0xFF0D5EAF"],10,24,68,54,12000,900,1.05,"defensive",dict(oil=1,steel=6,alu=4,rubber=2,food=12,energy=8),dict(c=2,m=2)),
 ("tr","Turkey","ترکیه","TUR","ترکیه","Ankara","آنکارا","TR",["0xFFE30A17","0xFFFFFFFF","0xFFE30A17"],85,52,62,54,34000,2200,1.25,"opportunist",dict(oil=4,steel=18,alu=8,rubber=4,food=34,energy=16),dict(c=5,m=4)),
 ("ir","Iran","ایران","IRN","ایران","Tehran","تهران","IR",["0xFF239F40","0xFFFFFFFF","0xFFDA0000"],89,38,44,44,26000,2600,1.30,"expansionist",dict(oil=44,steel=10,alu=6,rubber=3,food=22,energy=28),dict(c=4,m=3)),
 ("sa","Saudi Arabia","عربستان سعودی","SAU","عربستان","Riyadh","ریاض","SA",["0xFF006C35","0xFFFFFFFF","0xFF006C35"],36,42,60,58,88000,5200,1.20,"industrialist",dict(oil=68,steel=8,alu=6,rubber=2,food=10,energy=30),dict(c=4,m=3)),
 ("ae","United Arab Emirates","امارات متحده عربی","UAE","امارات","Abu Dhabi","ابوظبی","AE",["0xFF00732F","0xFFFFFFFF","0xFF000000"],10,36,80,66,46000,3200,1.15,"industrialist",dict(oil=34,steel=4,alu=8,rubber=2,food=4,energy=14),dict(c=3,m=2)),
 ("il","Israel","اسرائیل","ISR","اسرائیل","Jerusalem","اورشلیم","IL",["0xFF0038B8","0xFFFFFFFF","0xFF0038B8"],10,40,84,60,30000,1200,1.35,"defensive",dict(oil=1,steel=6,alu=4,rubber=2,food=8,energy=8),dict(c=3,m=3)),
 ("kz","Kazakhstan","قزاقستان","KAZ","قزاقستان","Astana","آستانه","KZ",["0xFF00AFCA","0xFFFEC50C","0xFF00AFCA"],20,30,50,58,28000,3400,0.95,"industrialist",dict(oil=38,steel=12,alu=8,rubber=2,food=16,energy=20),dict(c=3,m=2)),
 ("eg","Egypt","مصر","EGY","مصر","Cairo","قاهره","EG",["0xFFCE1126","0xFFFFFFFF","0xFF000000"],106,34,48,48,16000,2000,1.15,"opportunist",dict(oil=10,steel=8,alu=4,rubber=3,food=18,energy=14),dict(c=3,m=3)),
 ("ng","Nigeria","نیجریه","NGA","نیجریه","Abuja","آبوجا","NG",["0xFF008751","0xFFFFFFFF","0xFF008751"],224,28,40,42,14000,2600,1.00,"opportunist",dict(oil=36,steel=4,alu=2,rubber=4,food=22,energy=10),dict(c=3,m=2)),
 ("et","Ethiopia","اتیوپی","ETH","اتیوپی","Addis Ababa","آدیس‌آبابا","ET",["0xFF078930","0xFFFCDD09","0xFFDA121A"],126,18,32,38,6000,900,1.05,"defensive",dict(oil=1,steel=3,alu=2,rubber=2,food=24,energy=5),dict(c=2,m=2)),
 ("za","South Africa","آفریقای جنوبی","ZAF","آفریقای جنوبی","Pretoria","پرتوریا","ZA",["0xFF007A4D","0xFFFFB612","0xFF002395"],60,38,54,56,20000,2600,0.90,"industrialist",dict(oil=5,steel=16,alu=10,rubber=5,food=24,energy=16),dict(c=3,m=2)),
 ("in","India","هند","IND","هند","New Delhi","دهلی نو","IN",["0xFFFF9933","0xFFFFFFFF","0xFF138808"],1430,72,52,58,84000,3800,1.15,"opportunist",dict(oil=12,steel=26,alu=16,rubber=8,food=64,energy=34),dict(c=7,m=5)),
 ("pk","Pakistan","پاکستان","PAK","پاکستان","Islamabad","اسلام‌آباد","PK",["0xFF01411C","0xFFFFFFFF","0xFF01411C"],240,30,44,44,14000,1400,1.25,"defensive",dict(oil=4,steel=8,alu=4,rubber=3,food=30,energy=12),dict(c=3,m=3)),
 ("cn","China","چین","CHN","چین","Beijing","پکن","CN",["0xFFDE2910","0xFFFFDE00","0xFFDE2910"],1410,132,80,74,208000,5200,1.30,"industrialist",dict(oil=30,steel=48,alu=30,rubber=12,food=68,energy=56),dict(c=11,m=7)),
 ("jp","Japan","ژاپن","JPN","ژاپن","Tokyo","توکیو","JP",["0xFFFFFFFF","0xFFBC002D","0xFFFFFFFF"],123,84,92,72,132000,2800,1.00,"defensive",dict(oil=2,steel=26,alu=14,rubber=5,food=16,energy=30),dict(c=8,m=4)),
 ("kr","South Korea","کره جنوبی","KOR","کره جنوبی","Seoul","سئول","KR",["0xFFFFFFFF","0xFFCD2E3A","0xFF0047A0"],52,66,88,68,62000,1800,1.20,"defensive",dict(oil=1,steel=20,alu=10,rubber=4,food=10,energy=18),dict(c=5,m=4)),
 ("th","Thailand","تایلند","THA","تایلند","Bangkok","بانکوک","TH",["0xFFA51931","0xFFFFFFFF","0xFF2D2A4A"],72,34,56,54,18000,1600,0.95,"opportunist",dict(oil=4,steel=8,alu=6,rubber=12,food=26,energy=12),dict(c=3,m=2)),
 ("vn","Vietnam","ویتنام","VNM","ویتنام","Hanoi","هانوی","VN",["0xFFDA251D","0xFFFFCD00","0xFFDA251D"],99,36,50,60,16000,1800,1.15,"defensive",dict(oil=6,steel=10,alu=6,rubber=10,food=28,energy=12),dict(c=3,m=3)),
 ("id","Indonesia","اندونزی","IDN","اندونزی","Jakarta","جاکارتا","ID",["0xFFCE1126","0xFFFFFFFF","0xFFCE1126"],278,40,48,56,26000,3200,1.00,"opportunist",dict(oil=22,steel=12,alu=10,rubber=18,food=34,energy=20),dict(c=4,m=3)),
 ("au","Australia","استرالیا","AUS","استرالیا","Canberra","کانبرا","AU",["0xFF00008B","0xFFFFFFFF","0xFFCC0000"],27,44,84,72,48000,3400,1.00,"defensive",dict(oil=14,steel=18,alu=20,rubber=4,food=30,energy=24),dict(c=5,m=3)),
]

# strength / weakness text (En, Fa) per nation — concise and thematic.
TEXT = {
 "us": ("Unmatched power projection: two-ocean reach, the deepest industrial base and the largest air fleet.",
        "توان پرتاب نیرو در سطح جهانی: دسترسی به دو اقیانوس، عمیق‌ترین پایه صناعی و بزرگ‌ترین ناوگان هوایی.",
        "Politically polarised. Domestic stability recovers slowly and expensive formations are costly to maintain.",
        "دوقطبی‌شدن سیاسی. ثبات داخلی کند بازیابی می‌شود و نگهداری یگان‌های پرهزینه سنگین است."),
 "ca": ("Enormous territory, resource wealth and secure borders; excellent infrastructure.",
        "قلمرو پهناور، ثروت منابع و مرزهای امن؛ زیرساخت عالی.",
        "Small population limits the army it can field and sustain.",
        "جمعیت کم، اندازه ارتش قابل‌تأمین و نگهداری را محدود می‌کند."),
 "mx": ("Large population and growing industry with oil income close to home.",
        "جمعیت بزرگ و صناعت رو به رشد با درآمد نفتی نزدیک.",
        "Weak infrastructure and modest treasury slow every modernisation.",
        "زیرساخت ضعیف و خزانه متوسط، هر نوسازی را کند می‌کند."),
 "br": ("Resource-rich with room to grow; no land border with a rival great power.",
        "سرشار از منابع با فضای رشد؛ بدون مرز زمینی با قدرت بزرگ رقیب.",
        "Low military funding and thin industrial depth; poor infrastructure.",
        "بودجه نظامی پایین و عمق صناعی اندک؛ زیرساخت ضعیف."),
 "ar": ("Vast agricultural and energy resources with a compact, defensible core.",
        "منابع کشاورزی و انرژی گسترده با هسته‌ای فشرده و قابل دفاع.",
        "Chronic fiscal weakness and a small industrial base.",
        "ضعف مالی مزمن و پایه صناعی کوچک."),
 "uk": ("Professional armed forces, superb infrastructure and strong alliance potential.",
        "نیروهای مسلح حرفه‌ای، زیرساخت عالی و توان بالای اتحادسازی.",
        "Limited manpower; sustained land campaigns drain reserves quickly.",
        "نیروی انسانی محدود؛ کارزار زمینی طولانی ذخایر را تخلیه می‌کند."),
 "fr": ("Versatile army with strong logistics, able to operate far from home.",
        "ارتشی چندمنظوره با لجستیک قوی که دور از خانه مستقل عمل می‌کند.",
        "Moderate industry; heavy reliance on allied support in a long war.",
        "صناعت متوسط؛ اتکای زیاد به متحدان در جنگ طولانی."),
 "de": ("The strongest civilian economy and the best infrastructure in Europe.",
        "قوی‌ترین اقتصاد غیرنظامی و بهترین زیرساخت اروپا.",
        "Underfunded military; formations recover slowly after losses.",
        "ارتش کم‌بودجه؛ یگان‌ها پس از تلفات کند بازیابی می‌شوند."),
 "it": ("Central Mediterranean position with solid industry and a capable navy.",
        "موقعیت مرکزی مدیترانه با صناعت مستحکم و نیروی دریایی توانا.",
        "Low resource self-sufficiency; dependent on imported energy.",
        "خودکفایی منابع پایین؛ وابسته به انرژی وارداتی."),
 "es": ("Good infrastructure and a strategic gateway to the Atlantic and Mediterranean.",
        "زیرساخت خوب و دروازه‌ای راهبردی به اطلس و مدیترانه.",
        "Modest industry and limited force projection.",
        "صناعت متوسط و توان پرتاب نیروی محدود."),
 "nl": ("Very high infrastructure and productivity for its size; trade hub.",
        "زیرساخت و بهره‌وری بسیار بالا نسبت به اندازه؛ قطب تجارت.",
        "Tiny territory and manpower pool, exposed to blockade.",
        "قلمرو و ذخیره نیروی انسانی کوچک و آسیب‌پذیر در محاصره."),
 "se": ("Advanced industry and a strong domestic defence industry.",
        "صناعت پیشرفته و صنایع دفاعی داخلی قوی.",
        "Small population; neutral posture limits early aggression.",
        "جمعیت کم؛ موضع بی‌طرفی، تهاجم زودهنگام را محدود می‌کند."),
 "no": ("Energy-rich with superb infrastructure and a long, defensible coastline.",
        "سرشار از انرژی با زیرساخت عالی و خط ساحلی طولانی و قابل دفاع.",
        "Very small population and army.",
        "جمعیت و ارتش بسیار کوچک."),
 "pl": ("Large, motivated army and a central position on the northern plain.",
        "ارتش بزرگ و باانگیزه و موقعیت مرکزی در دشت شمالی.",
        "Exposed borders on every side and a modest treasury.",
        "مرزهای آسیب‌پذیر از هر سو و خزانه متوسط."),
 "ua": ("Deep agricultural and steel base with battle-hardened forces.",
        "پایه عمیق کشاورزی و فولاد با نیروهای کارآزموده.",
        "War-damaged industry and fragile stability.",
        "صناعت آسیب‌دیده از جنگ و ثبات شکننده."),
 "ru": ("The heaviest armoured formations and a war economy that tolerates mobilisation.",
        "سنگین‌ترین یگان‌های زرهی و اقتصادی جنگی که بسیج طولانی را تحمل می‌کند.",
        "Weak civilian economy and ageing infrastructure; volatile resource income.",
        "اقتصاد غیرنظامی ضعیف و زیرساخت فرسوده؛ درآمد منابع پرنوسان."),
 "gr": ("Difficult mountainous terrain and a large merchant marine.",
        "زمین کوهستانی دشوار و ناوگان تجاری بزرگ.",
        "Heavy debt and a small industrial base.",
        "بدهی سنگین و پایه صناعی کوچک."),
 "tr": ("Controls the straits and fields one of the largest armies in the region.",
        "کنترل تنگه‌ها و یکی از بزرگ‌ترین ارتش‌های منطقه.",
        "Inflation and a strained treasury limit sustained campaigns.",
        "تورم و خزانه تحت فشار، کارزار طولانی را محدود می‌کند."),
 "ir": ("Defends mountainous, hard-to-invade terrain and fields massed infantry.",
        "دفاع از زمین کوهستانی دشوار و به‌کارگیری انبوه پیاده‌نظام.",
        "Small treasury and low industrial depth slow modernisation.",
        "خزانه کوچک و عمق صناعی پایین، نوسازی را کند می‌کند."),
 "sa": ("Vast oil reserves and a large treasury to buy modern equipment.",
        "ذخایر عظیم نفتی و خزانه بزرگ برای خرید تجهیزات مدرن.",
        "Small population and a reliance on foreign equipment.",
        "جمعیت کم و وابستگی به تجهیزات خارجی."),
 "ae": ("High income per head, modern infrastructure and a professional air force.",
        "درآمد سرانه بالا، زیرساخت مدرن و نیروی هوایی حرفه‌ای.",
        "Very small population; vulnerable to a long land war.",
        "جمعیت بسیار کم؛ آسیب‌پذیر در جنگ زمینی طولانی."),
 "il": ("Elite formations, advanced technology and short interior lines.",
        "یگان‌های نخبه، فناوری پیشرفته و خطوط داخلی کوتاه.",
        "Very small population and no strategic depth.",
        "جمعیت بسیار کم و بدون عمق راهبردی."),
 "kz": ("Enormous resource wealth and a large, open territory.",
        "ثروت عظیم منابع و سرزمینی پهناور و باز.",
        "Low population density and weak infrastructure.",
        "تراکم جمعیتی پایین و زیرساخت ضعیف."),
 "eg": ("Large population, a strategic canal and a central position.",
        "جمعیت بزرگ، کانال راهبردی و موقعیت مرکزی.",
        "Resource-poor and dependent on food imports.",
        "فقیر از منابع و وابسته به واردات غذا."),
 "ng": ("Africa's largest population and significant oil income.",
        "بزرگ‌ترین جمعیت آفریقا و درآمد نفتی چشمگیر.",
        "Weak infrastructure and internal instability.",
        "زیرساخت ضعیف و ناپایداری داخلی."),
 "et": ("Very large population and defensible highlands.",
        "جمعیت بسیار بزرگ و ارتفاعات قابل دفاع.",
        "Very low industrial capacity and treasury.",
        "ظرفیت صناعی و خزانه بسیار پایین."),
 "za": ("Strongest African industry with rich mineral resources.",
        "قوی‌ترین صناعت آفریقا با منابع معدنی غنی.",
        "Social strain and modest military funding.",
        "تنش اجتماعی و بودجه نظامی متوسط."),
 "in": ("Enormous manpower reserves and a rapidly growing industrial base.",
        "ذخایر عظیم نیروی انسانی و پایه صناعی به‌سرعت رشدیابنده.",
        "Weak infrastructure throttles income growth.",
        "زیرساخت ضعیف، رشد درآمد را محدود می‌کند."),
 "pk": ("Large army and a nuclear-capable strategic position.",
        "ارتش بزرگ و موقعیت راهبردی با توان هسته‌ای.",
        "Fragile economy and low industrial depth.",
        "اقتصاد شکننده و عمق صناعی پایین."),
 "cn": ("The largest industrial capacity and manpower pool, with high stability.",
        "بزرگ‌ترین ظرفیت صناعی و ذخیره نیروی انسانی با ثبات بالا.",
        "Contested maritime periphery and rising labour costs.",
        "حاشیه دریایی پرتنش و هزینه‌های نیروی کار در حال افزایش."),
 "jp": ("Elite infrastructure and very high stability; superb industry.",
        "زیرساخت نخبه و ثبات بسیار بالا؛ صناعت عالی.",
        "Almost entirely dependent on imported resources.",
        "تقریباً کاملاً وابسته به منابع وارداتی."),
 "kr": ("High-technology industry and well-equipped, well-trained forces.",
        "صناعت فناورانه و نیروهای مجهز و آموزش‌دیده.",
        "Exposed to a massed neighbour and dependent on imports.",
        "در معرض همسایه‌ای پرجمعیت و وابسته به واردات."),
 "th": ("Central position in Southeast Asia with strong agriculture.",
        "موقعیت مرکزی در جنوب‌شرق آسیا با کشاورزی قوی.",
        "Modest industry and political volatility.",
        "صناعت متوسط و بی‌ثباتی سیاسی."),
 "vn": ("Disciplined, battle-hardened forces and rapid growth.",
        "نیروهای منظم و کارآزموده و رشد سریع.",
        "Limited heavy industry and low treasury.",
        "صناعت سنگین محدود و خزانه کم."),
 "id": ("Vast archipelago rich in resources with a huge population.",
        "مجمع‌الجزایری پهناور و سرشار از منابع با جمعیتی عظیم.",
        "Fragmented geography and uneven infrastructure.",
        "جغرافیای پراکنده و زیرساخت نامتوازن."),
 "au": ("Resource superpower with secure borders and excellent infrastructure.",
        "ابرقدرت منابع با مرزهای امن و زیرساخت عالی.",
        "Small population and long supply lines.",
        "جمعیت کم و خطوط تدارکاتی طولانی."),
}

GROUP = {"west": 0, "east": 1}

def group_of(cid):
    import world_data
    for n in world_data.NATIONS:
        if n['id'] == cid:
            return n['group']
    return 'east'

def relations_for(cid, group):
    """Deterministic, plausible relations: same-group nations like each other,
    cross-group nations are cooler, and everyone is neutral to distant states."""
    r = {}
    for other, *_ in [(c[0],) for c in C]:
        if other == cid:
            continue
        og = group_of(other)
        base = 44 if og == group else -20
        # spread deterministically so no two rows are identical
        jitter = ((hash(cid + other) % 31) - 15)
        val = max(-75, min(88, base + jitter))
        r[other] = val
    return r

def theatres_for(cid):
    """Reachable theatres = land neighbours + a few regional partners."""
    borders = []
    for a, b in LAND_BORDERS:
        if a == cid:
            borders.append(b)
        elif b == cid:
            borders.append(a)
    group = group_of(cid)
    others = [c[0] for c in C if c[0] != cid and group_of(c[0]) == group and c[0] not in borders]
    return borders + others[:4]

LAND_BORDERS = []

def load_borders():
    import world_data
    return world_data.LAND_BORDERS

def fmt_map(m):
    return "{" + ", ".join(f"'{k}': {v}" for k, v in m.items()) + "}"

def main():
    global LAND_BORDERS
    LAND_BORDERS = load_borders()

    L = []
    w = L.append
    w("import '../core/balance.dart';")
    w("import '../models/country.dart';")
    w("")
    w("/// The 36 playable nations of WORLD DOMINION.")
    w("///")
    w("/// **Data disclosure:** every economic, demographic and military figure")
    w("/// below is a *fictionalised demo value* authored for gameplay balance.")
    w("/// Some are loosely inspired by real-world orders of magnitude, but they")
    w("/// are deliberately rounded, mixed with invented trade/resource income and")
    w("/// advanced to a fictional 2027 start date. They are **not** presented as,")
    w("/// and must not be interpreted as, accurate national statistics.")
    w("class CountryData {")
    w("  CountryData._();")
    w("")
    ids = [c[0] for c in C]
    w("  static const List<String> playableIds = [")
    for i in range(0, len(ids), 6):
        w("    " + ", ".join(f"'{x}'" for x in ids[i:i+6]) + ",")
    w("  ];")
    w("")
    w("  /// Starting army composition: infantry / armor division counts.")
    w("  static const Map<String, List<int>> startingArmy = {")
    for c in C:
        # Scale starting divisions with industry & population, bounded.
        inf = max(4, min(26, round(c[10] * 0.20 + c[12] * 0.05)))
        arm = max(1, min(10, round(c[10] * 0.075)))
        w(f"    '{c[0]}': [{inf}, {arm}],")
    w("  };")
    w("")
    w("  static List<Country> build() => [")
    for c in C:
        (cid, nen, nfa, sen, sfa, cen, cfa, iso, flag, pop, ind, infra, stab,
         treas, resinc, budget, pers, res, fac) = c
        st_en, st_fa, wk_en, wk_fa = TEXT[cid]
        rel = relations_for(cid, group_of(cid))
        th = theatres_for(cid)
        w("    _c(")
        w(f"      id: '{cid}',")
        w(f"      nameEn: '{nen}',")
        w(f"      nameFa: '{nfa}',")
        w(f"      shortEn: '{sen}',")
        w(f"      shortFa: '{sfa}',")
        w(f"      capitalEn: '{cen}',")
        w(f"      capitalFa: '{cfa}',")
        w(f"      iso: '{iso}',")
        w(f"      flag: [{', '.join(flag)}],")
        w(f"      population: {pop},")
        w(f"      industrial: {ind},")
        w(f"      infrastructure: {infra},")
        w(f"      stability: {stab},")
        w(f"      treasury: {treas},")
        w(f"      resourceIncome: {resinc},")
        w(f"      militaryBudget: {budget},")
        w(f"      personality: AiPersonality.{pers},")
        w(f"      theatres: [{', '.join(repr(x) for x in th)}],")
        w(f"      strengthsEn:\n          '{st_en}',")
        w(f"      strengthsFa:\n          '{st_fa}',")
        w(f"      weaknessesEn:\n          '{wk_en}',")
        w(f"      weaknessesFa:\n          '{wk_fa}',")
        rels = ", ".join(f"'{k}': {v}" for k, v in rel.items())
        w(f"      relations: {{{rels}}},")
        w(f"      civilianFactories: {fac['c']},")
        w(f"      militaryFactories: {fac['m']},")
        w(f"      resourceProduction: const {fmt_map(res)},")
        w("    ),")
    w("  ];")
    w("")
    w("  static Country _c({")
    w("    required String id,")
    w("    required String nameEn,")
    w("    required String nameFa,")
    w("    required String shortEn,")
    w("    required String shortFa,")
    w("    required String capitalEn,")
    w("    required String capitalFa,")
    w("    required String iso,")
    w("    required List<int> flag,")
    w("    required double population,")
    w("    required double industrial,")
    w("    required double infrastructure,")
    w("    required double stability,")
    w("    required double treasury,")
    w("    required double resourceIncome,")
    w("    required double militaryBudget,")
    w("    required AiPersonality personality,")
    w("    required List<String> theatres,")
    w("    required String strengthsEn,")
    w("    required String strengthsFa,")
    w("    required String weaknessesEn,")
    w("    required String weaknessesFa,")
    w("    required Map<String, double> relations,")
    w("    required int civilianFactories,")
    w("    required int militaryFactories,")
    w("    required Map<String, double> resourceProduction,")
    w("  }) {")
    w("    return Country(")
    w("      id: id,")
    w("      nameEn: nameEn,")
    w("      nameFa: nameFa,")
    w("      shortEn: shortEn,")
    w("      shortFa: shortFa,")
    w("      capitalEn: capitalEn,")
    w("      capitalFa: capitalFa,")
    w("      iso: iso,")
    w("      flagColors: flag,")
    w("      population: population,")
    w("      industrial: industrial,")
    w("      infrastructure: infrastructure,")
    w("      stability: stability,")
    w("      treasury: treasury,")
    w("      resourceIncome: resourceIncome,")
    w("      militaryBudget: militaryBudget,")
    w("      personality: personality,")
    w("      theatres: theatres,")
    w("      strengthsEn: strengthsEn,")
    w("      strengthsFa: strengthsFa,")
    w("      weaknessesEn: weaknessesEn,")
    w("      weaknessesFa: weaknessesFa,")
    w("      relations: relations,")
    w("      buildings: const {'factory': 2, 'infrastructure': 1},")
    w("      civilianFactories: civilianFactories,")
    w("      militaryFactories: militaryFactories,")
    w("      resourceProduction: resourceProduction,")
    w("    );")
    w("  }")
    w("}")
    with open(OUT, "w") as fh:
        fh.write("\n".join(L) + "\n")
    print("wrote", OUT, len("\n".join(L)) // 1024, "KB")

if __name__ == "__main__":
    main()
