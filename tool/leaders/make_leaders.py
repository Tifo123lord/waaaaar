import json, re
from roster import R
info = json.load(open(__import__('os').path.join(__import__('os').path.dirname(__file__),'info.json'))); slugs = json.load(open(__import__('os').path.join(__import__('os').path.dirname(__file__),'slugs.json')))

FA_NAME = {
 'Abbas Araghchi':'سید عباس عراقچی','Abdel Fattah el-Sisi':'عبدالفتاح السیسی','Agus Subiyanto':'آگوس سوبیانتو',
 'Ahn Gyu-back':'آن گیو-بک','Aisha Mohammed (politician)':'عایشه محمد','Aitkurman Omarbekov':'آیتکورمان عمربکوف',
 'Ali Abdollahi':'علی عبداللهی','Andrii Sybiha':'آندری سیبیها','Angie Motshekga':'انجی موتشکگا','Anita Anand':'آنیتا آناند',
 'Anutin Charnvirakul':'آنوتین چارنویراکول','Ashraf Salem Zaher':'اشرف سالم زاهر','Boris Pistorius':'بوریس پیستوریوس',
 'Carlos Presti':'کارلوس پرستی','Catherine Vautrin':'کاترین ووترن','Cho Hyun (diplomat)':'چو هیون',
 'Christopher Gwabin Musa':'کریستوفر گوابین موسی','David McGuinty':'دیوید مک‌گینتی','Dilan Yeşilgöz':'دیلان یشیل‌گوز',
 'Dimitrios Choupis':'دیمیتریوس خوپیس','Däuren Qosanov':'داورن قوسانوف','Ermek Köşerbaev':'ارمک کوشربایف',
 'Fabien Mandon':'فابین ماندون','Gedion Timothewos':'گدیون تیموتیووس','Geraldo Alckmin':'ژرالدو آلکمین',
 'Gibran Rakabuming Raka':'جبران راکابومینگ راکا','Giorgos Gerapetritis':'گیورگوس گراپتریتیس','Hiroaki Uchikura':'هیروآکی اوچیکورا',
 'Issa Al Mazrouei':'عیسی المزروعی','Jennie Carignan':'جنی کارینیان','Jin Young Seung':'جین یونگ-سونگ',
 'Johann Wadephul':'یوهان وادفول','José Manuel Albares':'خوزه مانوئل آلبارس','José Múcio':'ژوزه موسیو',
 'Kashim Shettima':'کاشیم شتیما','Lê Hoài Trung':'له هوای ترونگ','Lê Minh Hưng':'له مین هونگ',
 'Marcelo Dalle Nogare':'مارسلو داله نوگاره','Maria Malmer Stenergard':'ماریا مالمر استنرگارد','Mark Hammond (admiral)':'مارک هاموند',
 'Mauro Vieira':'مائورو ویرا','Michael Claesson':'میکائیل کلاسون','Mykhailo Drapatyi':'میخایلو دراپاتی',
 'Mykhailo Fedorov':'میخایلو فدوروف','N. S. Raja Subramani':'ان. اس. راجا سوبرامانی','Natthaphon Narkphanit':'ناتاپون ناکپانیت',
 'Nguyễn Tân Cương':'نگوین تان کونگ','Nikos Dendias':'نیکوس دندیاس','Olufemi Oluyede':'اولوفمی اولویده',
 'Pablo Quirno':'پابلو کیرنو','Paul Mashatile':'پل ماشاتیله','Phan Văn Giang':'فان وان جانگ','Pål Jonson':'پول یونسون',
 'Raymundo Morales Ángeles':'رایموندو مورالس آنخلس','Renato Rodrigues de Aguiar Freire':'رناتو فریره',
 'Ricardo Trevilla Trejo':'ریکاردو تره‌ویا ترخو','Roberto Velasco Álvarez':'روبرتو ولاسکو آلوارز','Ronald Lamola':'رونالد لامولا',
 'Rudzani Maphwanya':'رودزانی ماپوانیا','S. Jaishankar':'سوبرامانیام جایشانکار','Shinjirō Koizumi':'شینجیرو کویزومی',
 'Sihasak Phuangketkeow':'سیهاساک پوانگکت‌کیو','Sjafrie Sjamsoeddin':'شفری شمس‌الدین','Sugiono':'سوگیونو',
 'Tom Berendsen':'تام برندسن','Tore O. Sandvik':'توره اونسهویس ساندویک','Ukris Boontanondha':'اوکریت بونتانون',
 'Yusuf Tuggar':'یوسف توگار','Zhang Shengmin':'ژانگ شنگ‌مین','Ali Abdollahi':'علی عبداللهی',
 'Abdel Fattah el-Sisi':'عبدالفتاح السیسی','Javier Milei':'خاویر میلی',
}
def fa_name(n):
    if n in FA_NAME: return FA_NAME[n]
    v = info[n]['fa']; assert v, n
    return re.sub(r'\s*\(.*?\)', '', v).strip()
def en_name(n):
    return {'Wang Yi (politician)':'Wang Yi','Cho Hyun (diplomat)':'Cho Hyun','Aisha Mohammed (politician)':'Aisha Mohammed',
            'Mark Hammond (admiral)':'Mark Hammond','Salman of Saudi Arabia':'Salman bin Abdulaziz Al Saud',
            'Renato Rodrigues de Aguiar Freire':'Renato Freire','Tore O. Sandvik':'Tore O. Sandvik'}.get(n, n)

FA_TITLE = {
 'President':'رئیس‌جمهور','Vice President':'معاون رئیس‌جمهور','First Vice President':'معاون اول رئیس‌جمهور','Deputy President':'معاون رئیس‌جمهور',
 'Federal President':'رئیس‌جمهور فدرال','King':'پادشاه','Emperor':'امپراتور','Supreme Leader':'رهبر انقلاب اسلامی',
 'Prime Minister':'نخست‌وزیر','Prime Minister (caretaker)':'نخست‌وزیر (موقت)','Chancellor':'صدراعظم','Premier':'نخست‌وزیر (رئیس شورای دولتی)',
 'Crown Prince & Prime Minister':'ولیعهد و نخست‌وزیر','Vice President & Prime Minister':'معاون رئیس و نخست‌وزیر',
 'General Secretary & President':'دبیرکل حزب کمونیست و رئیس‌جمهور',
 'Secretary of State':'وزیر امور خارجه','Minister of Foreign Affairs':'وزیر امور خارجه','Minister for Foreign Affairs':'وزیر امور خارجه',
 'Secretary of Foreign Affairs':'وزیر امور خارجه','Foreign Secretary':'وزیر امور خارجه','Minister for Europe and Foreign Affairs':'وزیر اروپا و امور خارجه',
 'Minister of External Affairs':'وزیر امور خارجه','Minister of International Relations':'وزیر روابط بین‌الملل','Deputy PM & Foreign Minister':'معاون نخست‌وزیر و وزیر خارجه',
 'Secretary of Defense':'وزیر جنگ/دفاع','Minister of National Defence':'وزیر دفاع ملی','Minister of National Defense':'وزیر دفاع ملی','Secretary of National Defense':'وزیر دفاع ملی',
 'Minister of Defence':'وزیر دفاع','Minister of Defense':'وزیر دفاع','Minister for Defence':'وزیر دفاع','Secretary of State for Defence':'وزیر دفاع',
 'Minister of the Armed Forces':'وزیر نیروهای مسلح',
 'Chairman of the Joint Chiefs of Staff':'رئیس ستاد مشترک ارتش','Chief of the Defence Staff':'رئیس ستاد دفاع','Chief of Defence Staff':'رئیس ستاد دفاع',
 'Secretary of the Navy':'وزیر نیروی دریایی','Chief of the Joint Staff of the Armed Forces':'رئیس ستاد مشترک نیروهای مسلح','Chief of the Joint Chiefs of Staff':'رئیس ستاد مشترک',
 'Inspector General of the Bundeswehr':'بازرس کل بوندسور (فرمانده ارتش)','Chief of Defence':'فرمانده کل نیروهای دفاعی','Supreme Commander':'فرمانده عالی نیروهای مسلح',
 'Chief of the General Staff':'رئیس ستاد کل','Commander-in-Chief of the Armed Forces':'فرمانده کل نیروهای مسلح','Chief of the National Defence General Staff':'رئیس ستاد کل دفاع ملی',
 'Chief of the General Staff of the Armed Forces':'رئیس ستاد کل نیروهای مسلح','Commander-in-Chief of the IRGC':'فرمانده کل سپاه پاسداران','Commander-in-Chief of the Army':'فرمانده کل ارتش',
 'Chief of Staff of the Armed Forces':'رئیس ستاد نیروهای مسلح','Chief of General Staff':'رئیس ستاد کل','Chief of the National Defence Force':'فرمانده نیروی دفاع ملی',
 'Chief of Defence Forces':'فرمانده نیروهای دفاعی','Vice Chairman, Central Military Commission':'نایب‌رئیس کمیسیون نظامی مرکزی','Chief of Staff, Joint Staff':'رئیس ستاد مشترک',
 'Commander of the National Armed Forces':'فرمانده نیروهای مسلح ملی','Chief of the Defence Force':'فرمانده نیروی دفاعی',
}
FA_TITLE['Secretary of Defense'] = 'وزیر دفاع'
EN_RANK = {  # military rank prefixes
 'Dan Caine':'Gen.','Jennie Carignan':'Gen.','Ricardo Trevilla Trejo':'Gen.','Raymundo Morales Ángeles':'Adm.','Renato Rodrigues de Aguiar Freire':'Adm.',
 'Marcelo Dalle Nogare':'V.Adm.','Rich Knighton':'ACM Sir','Fabien Mandon':'Gen.','Carsten Breuer':'Gen.','Luciano Portolano':'Gen.',
 'Teodoro Esteban López Calderón':'Adm. Gen.','Onno Eichelsheim':'Gen.','Michael Claesson':'Gen.','Eirik Kristoffersen':'Gen.','Wiesław Kukuła':'Gen.',
 'Mykhailo Drapatyi':'Gen.','Valery Gerasimov':'Army Gen.','Dimitrios Choupis':'Gen.','Selçuk Bayraktaroğlu':'Gen.','Ali Abdollahi':'Maj. Gen.',
 'Ahmad Vahidi':'Maj. Gen.','Amir Hatami':'Maj. Gen.','Fayyadh Al Ruwaili':'ACM','Issa Al Mazrouei':'Lt. Gen.','Eyal Zamir':'Lt. Gen.',
 'Aitkurman Omarbekov':'Maj. Gen.','Ashraf Salem Zaher':'Lt. Gen.','Ahmed Fathy Khalifa':'Lt. Gen.','Christopher Gwabin Musa':'Gen. (rtd.)',
 'Olufemi Oluyede':'Gen.','Birhanu Jula':'Field Marshal','Rudzani Maphwanya':'Gen.','N. S. Raja Subramani':'Gen.','Asim Munir':'Field Marshal',
 'Dong Jun':'Adm.','Zhang Shengmin':'Gen.','Hiroaki Uchikura':'Gen.','Jin Young Seung':'Gen.','Natthaphon Narkphanit':'Gen.','Ukris Boontanondha':'Gen.',
 'Phan Văn Giang':'Army Gen.','Nguyễn Tân Cương':'Gen.','Sjafrie Sjamsoeddin':'Gen. (Hon.)','Agus Subiyanto':'Gen.','Mark Hammond (admiral)':'Adm.',
 'Däuren Qosanov':'Lt. Gen.',
}
FA_RANK = {'Gen.':'ژنرال','Adm.':'دریاسالار','V.Adm.':'دریابان','ACM Sir':'ارتشبد هوایی سر','Adm. Gen.':'دریاسالار','Army Gen.':'ارتشبد',
 'Maj. Gen.':'سرلشکر','ACM':'ارتشبد هوایی','Lt. Gen.':'سپهبد','Gen. (rtd.)':'ژنرال (بازنشسته)','Field Marshal':'فیلدمارشال','Gen. (Hon.)':'ژنرال افتخاری'}
SINCE = {
 'us':{'hos':'2025-01-20','vp':'2025-01-20','fm':'2025-01-21','dm':'2025-01-25','cod':'2025-04-11'},
 'ca':{'hos':'2022-09-08','hog':'2025-03-14','fm':'2025-05-13','dm':'2025-05-13','cod':'2024-07-18'},
 'mx':{'hos':'2024-10-01','fm':'2026-04-08','dm':'2024-10-01','cod':'2024-10-01'},
 'br':{'hos':'2023-01-01','vp':'2023-01-01','fm':'2023-01-01','dm':'2023-01-01','cod':None},
 'ar':{'hos':'2023-12-10','vp':'2023-12-10','fm':'2025-10-23','dm':'2025-12-10','cod':'2025-12-12'},
 'uk':{'hos':'2022-09-08','hog':'2026-07-20','fm':'2026-07-20','dm':'2026-07-20','cod':'2025-09-02'},
 'fr':{'hos':'2017-05-14','hog':'2025-09-09','fm':'2024-09-21','dm':'2025-10-12','cod':'2025-09-01'},
 'de':{'hos':'2017-03-19','hog':'2025-05-06','fm':'2025-05-06','dm':'2023-01-19','cod':'2023-03-17'},
 'it':{'hos':'2015-02-03','hog':'2022-10-22','fm':'2022-10-22','dm':'2022-10-22','cod':'2024-10-04'},
 'es':{'hos':'2014-06-19','hog':'2018-06-02','fm':'2021-07-12','dm':'2018-06-07','cod':'2021-01-27'},
 'nl':{'hos':'2013-04-30','hog':'2026-02-23','fm':'2026-02-23','dm':'2026-02-23','cod':'2021-04-15'},
 'se':{'hos':'1973-09-15','hog':'2022-10-18','fm':'2024-09-10','dm':'2022-10-18','cod':'2024-10-01'},
 'no':{'hos':'2026-08-28','hog':'2021-10-14','fm':'2023-10-16','dm':'2025-02-04','cod':'2020-08-17'},
 'pl':{'hos':'2025-08-06','hog':'2023-12-13','fm':'2023-12-13','dm':'2023-12-13','cod':'2023-10-10'},
 'ua':{'hos':'2019-05-20','hog':'2026-07-16','fm':'2024-09-05','dm':'2026-01-14','cod':'2026-07-21'},
 'ru':{'hos':'2012-05-07','hog':'2020-01-16','fm':'2004-03-09','dm':'2024-05-14','cod':'2012-11-09'},
 'gr':{'hos':'2025-03-13','hog':'2023-06-26','fm':'2023-06-27','dm':'2023-06-27','cod':'2024-01-12'},
 'tr':{'hos':'2014-08-28','vp':'2023-06-04','fm':'2023-06-04','dm':'2023-06-04','cod':'2025-08-05'},
 'ir':{'leader':'2026-03-08','hos':'2024-07-28','vp':'2024-07-28','fm':'2024-08-21','dm':'2026-10-18','cod':'2026-08-10','irgc':'2026-03-01','army':'2025-06-13'},
 'sa':{'hos':'2015-01-23','hog':'2022-09-27','fm':'2019-10-29','dm':'2022-09-27','cod':'2018-02-26'},
 'ae':{'hos':'2022-05-14','hog':'2006-02-11','fm':'2006-02-09','dm':'2024-07-14','cod':None},
 'il':{'hos':'2021-07-07','hog':'2022-12-29','fm':'2024-11-05','dm':'2024-11-05','cod':'2025-03-05'},
 'kz':{'hos':'2019-03-20','hog':'2024-02-06','fm':'2025-09-26','dm':'2025-06-08','cod':'2026-10-05'},
 'eg':{'hos':'2014-06-08','hog':'2018-06-07','fm':'2024-07-03','dm':'2026-02-11','cod':'2024-07-03'},
 'ng':{'hos':'2023-05-29','vp':'2023-05-29','fm':'2023-08-21','dm':'2025-12-04','cod':'2025-10-30'},
 'et':{'hos':'2024-10-07','hog':'2018-04-02','fm':'2024-10-18','dm':'2024-05-20','cod':'2020-11-04'},
 'za':{'hos':'2018-02-15','vp':'2023-03-07','fm':'2024-06-30','dm':'2024-07-03','cod':'2021-06-01'},
 'in':{'hos':'2022-07-25','hog':'2014-05-26','fm':'2019-05-30','dm':'2019-05-31','cod':'2026-05-31'},
 'pk':{'hos':'2024-03-10','hog':'2024-03-04','fm':'2024-03-11','dm':'2024-03-11','cod':'2025-12-04'},
 'cn':{'hos':'2012-11-15','hog':'2023-03-11','fm':'2023-07-25','dm':'2023-12-29','cod':'2025-10-23'},
 'jp':{'hos':'2019-05-01','hog':'2025-10-21','fm':'2025-10-21','dm':'2025-10-21','cod':'2025-08-01'},
 'kr':{'hos':'2025-06-04','hog':'2026-07-01','fm':'2025-07-19','dm':'2025-07-25','cod':'2025-09-30'},
 'th':{'hos':'2016-10-13','hog':'2025-09-07','fm':'2025-09-19','dm':'2025-06-30','cod':None},
 'vn':{'hos':'2024-08-03','hog':'2026-04-07','fm':'2025-10-25','dm':'2021-04-08','cod':'2021-06-01'},
 'id':{'hos':'2024-10-20','vp':'2024-10-20','fm':'2024-10-21','dm':'2024-10-21','cod':'2023-11-22'},
 'au':{'hos':'2022-09-08','hog':'2022-05-23','fm':'2022-05-23','dm':'2022-06-01','cod':'2026-07-09'},
}
ROLE = {'leader':'supremeLeader','hos':'headOfState','vp':'deputyHeadOfState','hog':'headOfGovernment','fm':'foreignMinister','dm':'defenceMinister','cod':'chiefOfDefence','irgc':'serviceCommander','army':'serviceCommander'}
ORDER = ['leader','hos','vp','hog','fm','dm','cod','irgc','army']
MONARCH_IDS = {'ca','uk','es','nl','se','no','sa','jp','th','au'}

def q(s): return "'" + s.replace('\\','\\\\').replace("'","\\'").replace('$','\\$') + "'"
out = ["// GENERATED by tool/leaders/make_leaders.py — do not edit by hand.",
"// Officeholders verified against Wikipedia / Wikidata on 2026-10-19.",
"// Portraits: Wikimedia Commons (see assets/leaders/CREDITS.txt).","",
"part of 'country_leaders.dart';","","const Map<String, List<Leader>> _kLeaders = {"]
for cid, roles in R.items():
    out.append(f"  '{cid}': [")
    for rk in ORDER:
        if rk not in roles: continue
        title, name = roles[rk]
        rank = EN_RANK.get(name)
        since = SINCE[cid].get(rk)
        assert rk in SINCE[cid], (cid, rk)
        portrait = f"assets/leaders/{slugs[name]}.jpg" if name in slugs else None
        tfa = FA_TITLE[title]
        if cid=='us' and rk=='dm': title='Secretary of Defense (War)'; tfa='وزیر دفاع (جنگ)'
        args = [f"LeaderRole.{ROLE[rk]}", q(title), q(tfa), q(en_name(name)), q(fa_name(name))]
        extra = []
        if rank: extra += [f"rankEn: {q(rank)}", f"rankFa: {q(FA_RANK[rank])}"]
        if portrait: extra.append(f"portrait: {q(portrait)}")
        if since: extra.append(f"since: {q(since)}")
        if rk=='hos' and cid in MONARCH_IDS: extra.append("hereditary: true")
        out.append("    Leader(" + ", ".join(args + extra) + "),")
    out.append("  ],")
out.append("};")
open('/home/user/flutter_app/lib/data/country_leaders_data.dart','w').write("\n".join(out)+"\n")
# credits
cred=["Portrait photographs of officeholders, cropped and resized.","Source: Wikimedia Commons via the English Wikipedia lead image of each person's article.","Each file is used under its original licence (public domain, CC BY, or CC BY-SA); see the article image page for author and licence.",""]
for n,s in sorted(slugs.items()): cred.append(f"{s}.jpg  <-  https://en.wikipedia.org/wiki/{info[n]['title'].replace(' ','_')}")
open('/home/user/flutter_app/assets/leaders/CREDITS.txt','w').write("\n".join(cred)+"\n")
print('ok', sum(len(v) for v in R.values()))
