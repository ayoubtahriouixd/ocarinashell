#!/usr/bin/env python3
"""Write assets/data/*.json: themes, 七十二候 (72 micro-seasons), kotowaza, kanji glossary, traditional colours.

Single source of truth for the theme engine (bin/ocarina-theme), the shell (Theme, Kisetsu, Glossary) and the
mockups. Colours are CSS hex (#RRGGBB or #RRGGBBAA); the theme engine converts per target (QML is #AARRGGBB).
Checks WCAG contrast of every theme and exits non-zero if a required pair fails.

usage: python3 tools/build_data.py [outdir=assets/data]
"""
import json
import pathlib
import sys

K = pathlib.Path(__file__).resolve().parent.parent

# ----------------------------------------------------------------------------- 二十四節気 + 七十二候
# Start dates are the usual ones (±1 day depending on the year); `lon` is the solar ecliptic longitude at which
# each period starts, so the Kisetsu service can compute the exact day for any year.
SEKKI = [
    ("立春", "りっしゅん", "Risshun", "Comienzo de la primavera", (2, 4)),
    ("雨水", "うすい", "Usui", "Agua de lluvia", (2, 19)),
    ("啓蟄", "けいちつ", "Keichitsu", "Despertar de los insectos", (3, 6)),
    ("春分", "しゅんぶん", "Shunbun", "Equinoccio de primavera", (3, 21)),
    ("清明", "せいめい", "Seimei", "Claro y luminoso", (4, 5)),
    ("穀雨", "こくう", "Kokuu", "Lluvia de los granos", (4, 20)),
    ("立夏", "りっか", "Rikka", "Comienzo del verano", (5, 5)),
    ("小満", "しょうまん", "Shōman", "Pequeña plenitud", (5, 21)),
    ("芒種", "ぼうしゅ", "Bōshu", "Siembra del grano con arista", (6, 6)),
    ("夏至", "げし", "Geshi", "Solsticio de verano", (6, 21)),
    ("小暑", "しょうしょ", "Shōsho", "Pequeño calor", (7, 7)),
    ("大暑", "たいしょ", "Taisho", "Gran calor", (7, 23)),
    ("立秋", "りっしゅう", "Risshū", "Comienzo del otoño", (8, 7)),
    ("処暑", "しょしょ", "Shosho", "Fin del calor", (8, 23)),
    ("白露", "はくろ", "Hakuro", "Rocío blanco", (9, 8)),
    ("秋分", "しゅうぶん", "Shūbun", "Equinoccio de otoño", (9, 23)),
    ("寒露", "かんろ", "Kanro", "Rocío frío", (10, 8)),
    ("霜降", "そうこう", "Sōkō", "Descenso de la escarcha", (10, 23)),
    ("立冬", "りっとう", "Rittō", "Comienzo del invierno", (11, 7)),
    ("小雪", "しょうせつ", "Shōsetsu", "Pequeña nevada", (11, 22)),
    ("大雪", "たいせつ", "Taisetsu", "Gran nevada", (12, 7)),
    ("冬至", "とうじ", "Tōji", "Solsticio de invierno", (12, 21)),
    ("小寒", "しょうかん", "Shōkan", "Pequeño frío", (1, 5)),
    ("大寒", "だいかん", "Daikan", "Gran frío", (1, 20)),
]

KO = [  # kanji, kana, romaji, español, start (month, day) — 略本暦 (Japón, 1874)
    ("東風解凍", "はるかぜこおりをとく", "Harukaze kōri wo toku", "El viento del este deshiela", (2, 4)),
    ("黄鶯睍睆", "うぐいすなく", "Uguisu naku", "Canta el uguisu", (2, 9)),
    ("魚上氷", "うおこおりをいずる", "Uo kōri wo izuru", "Los peces asoman bajo el hielo", (2, 14)),
    ("土脉潤起", "つちのしょううるおいおこる", "Tsuchi no shō uruoi okoru", "La lluvia humedece la tierra", (2, 19)),
    ("霞始靆", "かすみはじめてたなびく", "Kasumi hajimete tanabiku", "Empieza a flotar la neblina", (2, 24)),
    ("草木萌動", "そうもくめばえいずる", "Sōmoku mebae izuru", "Brotan hierbas y árboles", (3, 1)),
    ("蟄虫啓戸", "すごもりむしとをひらく", "Sugomori mushi to wo hiraku", "Los insectos salen de su letargo", (3, 6)),
    ("桃始笑", "ももはじめてさく", "Momo hajimete saku", "Florecen los primeros melocotoneros", (3, 11)),
    ("菜虫化蝶", "なむしちょうとなる", "Namushi chō to naru", "Las orugas se vuelven mariposas", (3, 16)),
    ("雀始巣", "すずめはじめてすくう", "Suzume hajimete sukū", "Los gorriones empiezan a anidar", (3, 21)),
    ("桜始開", "さくらはじめてひらく", "Sakura hajimete hiraku", "Se abren los primeros cerezos", (3, 26)),
    ("雷乃発声", "かみなりすなわちこえをはっす", "Kaminari sunawachi koe wo hassu", "Retumba el trueno a lo lejos", (3, 31)),
    ("玄鳥至", "つばめきたる", "Tsubame kitaru", "Vuelven las golondrinas", (4, 5)),
    ("鴻雁北", "こうがんかえる", "Kōgan kaeru", "Los gansos salvajes vuelan al norte", (4, 10)),
    ("虹始見", "にじはじめてあらわる", "Niji hajimete arawaru", "Aparecen los primeros arcoíris", (4, 15)),
    ("葭始生", "あしはじめてしょうず", "Ashi hajimete shōzu", "Brotan los primeros juncos", (4, 20)),
    ("霜止出苗", "しもやんでなえいずる", "Shimo yande nae izuru", "Cesa la escarcha, brota el arroz", (4, 25)),
    ("牡丹華", "ぼたんはなさく", "Botan hana saku", "Florecen las peonías", (4, 30)),
    ("蛙始鳴", "かわずはじめてなく", "Kawazu hajimete naku", "Empiezan a cantar las ranas", (5, 5)),
    ("蚯蚓出", "みみずいずる", "Mimizu izuru", "Salen las lombrices", (5, 10)),
    ("竹笋生", "たけのこしょうず", "Takenoko shōzu", "Brotan los tallos de bambú", (5, 15)),
    ("蚕起食桑", "かいこおきてくわをはむ", "Kaiko okite kuwa wo hamu", "Los gusanos de seda comen morera", (5, 21)),
    ("紅花栄", "べにばなさかう", "Benibana sakau", "Florece el cártamo", (5, 26)),
    ("麦秋至", "むぎのときいたる", "Mugi no toki itaru", "Madura el trigo", (5, 31)),
    ("蟷螂生", "かまきりしょうず", "Kamakiri shōzu", "Nacen las mantis", (6, 6)),
    ("腐草為螢", "くされたるくさほたるとなる", "Kusaretaru kusa hotaru to naru", "La hierba húmeda se llena de luciérnagas", (6, 11)),
    ("梅子黄", "うめのみきばむ", "Ume no mi kibamu", "Amarillean las ciruelas", (6, 16)),
    ("乃東枯", "なつかれくさかるる", "Natsukarekusa karuru", "Se seca la prunela", (6, 21)),
    ("菖蒲華", "あやめはなさく", "Ayame hana saku", "Florecen los lirios", (6, 26)),
    ("半夏生", "はんげしょうず", "Hange shōzu", "Brota el hange", (7, 2)),
    ("温風至", "あつかぜいたる", "Atsukaze itaru", "Llegan los vientos cálidos", (7, 7)),
    ("蓮始開", "はすはじめてひらく", "Hasu hajimete hiraku", "Se abren los primeros lotos", (7, 12)),
    ("鷹乃学習", "たかすなわちわざをならう", "Taka sunawachi waza wo narau", "Los halcones aprenden a volar", (7, 17)),
    ("桐始結花", "きりはじめてはなをむすぶ", "Kiri hajimete hana wo musubu", "La paulonia da sus frutos", (7, 23)),
    ("土潤溽暑", "つちうるおうてむしあつし", "Tsuchi uruōte mushiatsushi", "Tierra húmeda, calor bochornoso", (7, 28)),
    ("大雨時行", "たいうときどきふる", "Taiu tokidoki furu", "Caen grandes lluvias de vez en cuando", (8, 2)),
    ("涼風至", "すずかぜいたる", "Suzukaze itaru", "Llega la brisa fresca", (8, 7)),
    ("寒蝉鳴", "ひぐらしなく", "Higurashi naku", "Cantan las cigarras del atardecer", (8, 12)),
    ("蒙霧升降", "ふかききりまとう", "Fukaki kiri matō", "Se espesa la niebla", (8, 17)),
    ("綿柎開", "わたのはなしべひらく", "Wata no hanashibe hiraku", "Se abren las cápsulas del algodón", (8, 23)),
    ("天地始粛", "てんちはじめてさむし", "Tenchi hajimete samushi", "Por fin amaina el calor", (8, 28)),
    ("禾乃登", "こくものすなわちみのる", "Kokumono sunawachi minoru", "Madura el arroz", (9, 2)),
    ("草露白", "くさのつゆしろし", "Kusa no tsuyu shiroshi", "Rocío blanco sobre la hierba", (9, 8)),
    ("鶺鴒鳴", "せきれいなく", "Sekirei naku", "Cantan las lavanderas", (9, 13)),
    ("玄鳥去", "つばめさる", "Tsubame saru", "Se van las golondrinas", (9, 18)),
    ("雷乃収声", "かみなりすなわちこえをおさむ", "Kaminari sunawachi koe wo osamu", "El trueno calla", (9, 23)),
    ("蟄虫坏戸", "むしかくれてとをふさぐ", "Mushi kakurete to wo fusagu", "Los insectos sellan sus refugios", (9, 28)),
    ("水始涸", "みずはじめてかるる", "Mizu hajimete karuru", "Se drenan los arrozales", (10, 3)),
    ("鴻雁来", "こうがんきたる", "Kōgan kitaru", "Llegan los gansos salvajes", (10, 8)),
    ("菊花開", "きくのはなひらく", "Kiku no hana hiraku", "Florecen los crisantemos", (10, 13)),
    ("蟋蟀在戸", "きりぎりすとにあり", "Kirigirisu to ni ari", "Los grillos cantan junto a la puerta", (10, 18)),
    ("霜始降", "しもはじめてふる", "Shimo hajimete furu", "Cae la primera escarcha", (10, 23)),
    ("霎時施", "こさめときどきふる", "Kosame tokidoki furu", "Llovizna de vez en cuando", (10, 28)),
    ("楓蔦黄", "もみじつたきばむ", "Momiji tsuta kibamu", "Arces y hiedras cambian de color", (11, 2)),
    ("山茶始開", "つばきはじめてひらく", "Tsubaki hajimete hiraku", "Florecen las primeras camelias", (11, 7)),
    ("地始凍", "ちはじめてこおる", "Chi hajimete kōru", "La tierra empieza a helarse", (11, 12)),
    ("金盞香", "きんせんかさく", "Kinsenka saku", "Florecen los narcisos", (11, 17)),
    ("虹蔵不見", "にじかくれてみえず", "Niji kakurete miezu", "Los arcoíris se esconden", (11, 22)),
    ("朔風払葉", "きたかぜこのはをはらう", "Kitakaze konoha wo harau", "El viento del norte barre las hojas", (11, 27)),
    ("橘始黄", "たちばなはじめてきばむ", "Tachibana hajimete kibamu", "Amarillean los tachibana", (12, 2)),
    ("閉塞成冬", "そらさむくふゆとなる", "Sora samuku fuyu to naru", "El cielo se cierra, llega el invierno", (12, 7)),
    ("熊蟄穴", "くまあなにこもる", "Kuma ana ni komoru", "Los osos se retiran a sus cuevas", (12, 12)),
    ("鱖魚群", "さけのうおむらがる", "Sake no uo muragaru", "Los salmones remontan en bancos", (12, 16)),
    ("乃東生", "なつかれくさしょうず", "Natsukarekusa shōzu", "Brota la prunela", (12, 21)),
    ("麋角解", "さわしかのつのおつる", "Sawashika no tsuno otsuru", "Los ciervos mudan la cornamenta", (12, 26)),
    ("雪下出麦", "ゆきわたりてむぎのびる", "Yuki watarite mugi nobiru", "Bajo la nieve crece el trigo", (1, 1)),
    ("芹乃栄", "せりすなわちさかう", "Seri sunawachi sakau", "Prospera el perejil japonés", (1, 5)),
    ("水泉動", "しみずあたたかをふくむ", "Shimizu atataka wo fukumu", "Los manantiales se templan", (1, 10)),
    ("雉始雊", "きじはじめてなく", "Kiji hajimete naku", "Cantan los primeros faisanes", (1, 15)),
    ("款冬華", "ふきのはなさく", "Fuki no hana saku", "Brotan las flores del fuki", (1, 20)),
    ("水沢腹堅", "さわみずこおりつめる", "Sawamizu kōri tsumeru", "El hielo cubre los arroyos", (1, 25)),
    ("鶏始乳", "にわとりはじめてとやにつく", "Niwatori hajimete toya ni tsuku", "Las gallinas empiezan a poner", (1, 30)),
]

# one kanji per kō for the island (Shima) — 菊 for 菊花開, etc.
KO_SYMBOL = ("風鶯魚潤霞萌虫桃蝶雀桜雷燕雁虹葭苗華蛙蚓筍蚕紅麦螂螢梅枯菖夏温蓮鷹桐暑雨涼蝉霧綿粛稲露鴒燕収戸涸雁菊蟋"
             "霜霎楓椿凍香蔵葉橘冬熊鮭生鹿雪芹泉雉蕗氷鶏")

# ----------------------------------------------------------------------------- ことわざ (proverb of the day)
KOTOWAZA = [
    ("七転び八起き", "ななころびやおき", "Nana korobi ya oki", "Cae siete veces, levántate ocho."),
    ("猿も木から落ちる", "さるもきからおちる", "Saru mo ki kara ochiru", "Hasta los monos se caen de los árboles."),
    ("石の上にも三年", "いしのうえにもさんねん", "Ishi no ue ni mo sannen", "Tres años sobre una piedra: la constancia la calienta."),
    ("継続は力なり", "けいぞくはちからなり", "Keizoku wa chikara nari", "La constancia es fuerza."),
    ("塵も積もれば山となる", "ちりもつもればやまとなる", "Chiri mo tsumoreba yama to naru", "El polvo acumulado se vuelve montaña."),
    ("一期一会", "いちごいちえ", "Ichigo ichie", "Cada encuentro ocurre una sola vez."),
    ("花より団子", "はなよりだんご", "Hana yori dango", "Mejor dulces que flores: lo práctico primero."),
    ("急がば回れ", "いそがばまわれ", "Isogaba maware", "Si tienes prisa, da un rodeo."),
    ("出る杭は打たれる", "でるくいはうたれる", "Deru kui wa utareru", "El clavo que sobresale recibe el martillazo."),
    ("井の中の蛙大海を知らず", "いのなかのかわずたいかいをしらず", "I no naka no kawazu taikai wo shirazu", "La rana del pozo no conoce el océano."),
    ("雨降って地固まる", "あめふってじかたまる", "Ame futte ji katamaru", "Después de la lluvia, la tierra se afirma."),
    ("案ずるより産むが易し", "あんずるよりうむがやすし", "Anzuru yori umu ga yasushi", "Hacerlo es más fácil que temerlo."),
    ("能ある鷹は爪を隠す", "のうあるたかはつめをかくす", "Nō aru taka wa tsume wo kakusu", "El halcón hábil esconde sus garras."),
    ("千里の道も一歩から", "せんりのみちもいっぽから", "Senri no michi mo ippo kara", "Un camino de mil ri empieza con un paso."),
    ("鉄は熱いうちに打て", "てつはあついうちにうて", "Tetsu wa atsui uchi ni ute", "Golpea el hierro mientras está caliente."),
    ("百聞は一見に如かず", "ひゃくぶんはいっけんにしかず", "Hyakubun wa ikken ni shikazu", "Ver una vez vale más que oír cien."),
    ("時は金なり", "ときはかねなり", "Toki wa kane nari", "El tiempo es oro."),
    ("笑う門には福来る", "わらうかどにはふくきたる", "Warau kado ni wa fuku kitaru", "La fortuna llega a la casa donde se ríe."),
    ("知らぬが仏", "しらぬがほとけ", "Shiranu ga hotoke", "No saber es estar en paz."),
    ("二兎を追う者は一兎をも得ず", "にとをおうものはいっとをもえず", "Nito wo ou mono wa itto wo mo ezu", "Quien persigue dos liebres no atrapa ninguna."),
    ("習うより慣れろ", "ならうよりなれろ", "Narau yori narero", "La práctica enseña más que la lección."),
    ("弘法も筆の誤り", "こうぼうもふでのあやまり", "Kōbō mo fude no ayamari", "Hasta el gran calígrafo se equivoca con el pincel."),
    ("果報は寝て待て", "かほうはねてまて", "Kahō wa nete mate", "La buena suerte se espera durmiendo."),
    ("備えあれば憂いなし", "そなえあればうれいなし", "Sonae areba urei nashi", "Quien está preparado no tiene de qué preocuparse."),
    ("三人寄れば文殊の知恵", "さんにんよればもんじゅのちえ", "Sannin yoreba Monju no chie", "Tres cabezas juntas tienen la sabiduría de Monju."),
    ("灯台下暗し", "とうだいもとくらし", "Tōdai moto kurashi", "Bajo el faro está oscuro: lo cercano pasa desapercibido."),
    ("郷に入っては郷に従え", "ごうにいってはごうにしたがえ", "Gō ni itte wa gō ni shitagae", "Donde fueres, haz lo que vieres."),
    ("一石二鳥", "いっせきにちょう", "Isseki nichō", "Una piedra, dos pájaros."),
    ("猫に小判", "ねこにこばん", "Neko ni koban", "Monedas de oro a un gato."),
    ("覆水盆に返らず", "ふくすいぼんにかえらず", "Fukusui bon ni kaerazu", "El agua derramada no vuelve a la bandeja."),
    ("待てば海路の日和あり", "まてばかいろのひよりあり", "Mateba kairo no hiyori ari", "Quien espera encuentra buen tiempo para navegar."),
    ("光陰矢の如し", "こういんやのごとし", "Kōin ya no gotoshi", "El tiempo vuela como una flecha."),
    ("縁の下の力持ち", "えんのしたのちからもち", "En no shita no chikaramochi", "La fuerza que sostiene la casa sin ser vista."),
    ("口は災いの元", "くちはわざわいのもと", "Kuchi wa wazawai no moto", "La boca es el origen de las desgracias."),
    ("虎穴に入らずんば虎子を得ず", "こけつにいらずんばこじをえず", "Koketsu ni irazunba koji wo ezu", "Sin entrar en la cueva del tigre no hay cachorro."),
    ("好きこそ物の上手なれ", "すきこそもののじょうずなれ", "Suki koso mono no jōzu nare", "Lo que amas es lo que llegas a dominar."),
    ("明日は明日の風が吹く", "あしたはあしたのかぜがふく", "Ashita wa ashita no kaze ga fuku", "Mañana soplará el viento de mañana."),
    ("雀百まで踊り忘れず", "すずめひゃくまでおどりわすれず", "Suzume hyaku made odori wasurezu", "El gorrión no olvida su baile ni a los cien años."),
    ("実るほど頭を垂れる稲穂かな", "みのるほどこうべをたれるいなほかな", "Minoru hodo kōbe wo tareru inaho kana", "Cuanto más madura la espiga, más inclina la cabeza."),
    ("蛇の道は蛇", "じゃのみちはへび", "Ja no michi wa hebi", "El camino de la serpiente lo conoce la serpiente."),
    ("腹が減っては戦ができぬ", "はらがへってはいくさができぬ", "Hara ga hette wa ikusa ga dekinu", "Con el estómago vacío no se gana ninguna batalla."),
    ("急いては事を仕損じる", "せいてはことをしそんじる", "Seite wa koto wo shisonjiru", "Con prisa, las cosas salen mal."),
]

# ----------------------------------------------------------------------------- 日本の伝統色 (accent swatches)
COLORES = [  # id, kanji, kana, español, hex (JIS 慣用色名 where it exists)
    ("aka", "赤", "あか", "Rojo (赤, el de la marca)", "#e60033"),
    ("shu", "朱", "しゅ", "Bermellón", "#eb6101"),
    ("kurenai", "紅", "くれない", "Carmesí", "#d7003a"),
    ("akane", "茜", "あかね", "Rubia (granza)", "#b7282e"),
    ("enji", "臙脂", "えんじ", "Carmín oscuro", "#b94047"),
    ("kobai", "紅梅", "こうばい", "Ciruelo rosa", "#f2a0a1"),
    ("sango", "珊瑚", "さんご", "Coral", "#f5b1aa"),
    ("sakura", "桜", "さくら", "Cerezo", "#fef4f4"),
    ("botan", "牡丹", "ぼたん", "Peonía", "#e7609e"),
    ("kaki", "柿", "かき", "Caqui", "#ed6d3d"),
    ("kohaku", "琥珀", "こはく", "Ámbar", "#bf783a"),
    ("yamabuki", "山吹", "やまぶき", "Rosa amarilla (kerria)", "#f8b500"),
    ("kin", "金", "きん", "Oro", "#e6b422"),
    ("moegi", "萌黄", "もえぎ", "Verde brote", "#aacf53"),
    ("wakakusa", "若草", "わかくさ", "Hierba joven", "#c3d825"),
    ("wakatake", "若竹", "わかたけ", "Bambú joven", "#68be8d"),
    ("matcha", "抹茶", "まっちゃ", "Matcha", "#c5c56a"),
    ("koke", "苔", "こけ", "Musgo", "#69821b"),
    ("asagi", "浅葱", "あさぎ", "Cebolleta clara (cian)", "#00a3af"),
    ("sora", "空", "そら", "Cielo", "#a0d8ef"),
    ("ruri", "瑠璃", "るり", "Lapislázuli", "#1e50a2"),
    ("gunjo", "群青", "ぐんじょう", "Ultramar", "#4c6cb3"),
    ("ai", "藍", "あい", "Índigo", "#165e83"),
    ("kon", "紺", "こん", "Azul marino", "#223a70"),
    ("sumire", "菫", "すみれ", "Violeta", "#7058a3"),
    ("murasaki", "紫", "むらさき", "Púrpura", "#884898"),
    ("kinari", "生成り", "きなり", "Crudo (algodón natural)", "#fbfaf5"),
    ("gofun", "胡粉", "ごふん", "Blanco de concha", "#fffffc"),
    ("nezumi", "鼠", "ねずみ", "Gris ratón", "#949495"),
    ("sumi", "墨", "すみ", "Tinta", "#595857"),
    ("shikkoku", "漆黒", "しっこく", "Negro laca", "#0d0015"),
]
ACCENTS = ["aka", "shu", "kin", "wakatake", "asagi", "ruri", "murasaki", "kobai"]  # Settei → 外観 (+ «Desde el fondo»)

# ----------------------------------------------------------------------------- glosario de la interfaz
KAOMOJI = [  # (kaomoji, categoría, palabras clave en español) — Torii `:` (07-IDEAS); sin emoji: solo texto
    ("(＾▽＾)", "alegría", "feliz alegría sonrisa"), ("ヽ(・∀・)ﾉ", "alegría", "feliz yupi celebrar"),
    ("(≧▽≦)", "alegría", "feliz emoción genial"), ("(✿◠‿◠)", "alegría", "feliz flor dulce"),
    ("٩(◕‿◕｡)۶", "alegría", "feliz alegría bien"), ("(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧", "alegría", "magia brillo celebrar alegría"),
    ("＼(＾▽＾)／", "alegría", "hurra celebrar feliz"), ("(*^‿^*)", "alegría", "sonrisa contento"),
    ("(´｡• ᵕ •｡`)", "alegría", "tierno contento"), ("o(≧▽≦)o", "alegría", "emoción genial"),
    ("☆*:.｡.o(≧▽≦)o.｡.:*☆", "alegría", "celebrar brillo estrellas fiesta"), ("(◕‿◕✿)", "alegría", "dulce flor"),
    ("(≧∇≦)ﾉ", "risa", "risa jaja"), ("( ´∀｀ )b", "risa", "bien ok pulgar"),
    ("(♡°▽°♡)", "amor", "amor enamorado"), ("(´∀｀)♡", "amor", "amor cariño"),
    ("(づ｡◕‿‿◕｡)づ", "amor", "abrazo amor"), ("(っ˘з(˘⌣˘ )", "amor", "beso amor"),
    ("( ˘ ³˘)♥", "amor", "beso"), ("(♥ω♥*)", "amor", "amor enamorado"), ("♡(｡- ω -)", "amor", "amor tierno"),
    ("(っ´ω`c)", "amor", "tierno mejillas"),
    ("(╥﹏╥)", "tristeza", "llorar triste"), ("(ಥ﹏ಥ)", "tristeza", "llorar triste"),
    ("(；ω；)", "tristeza", "llorar pena"), ("(｡•́︿•̀｡)", "tristeza", "triste pena"),
    ("( ´_ゝ`)", "tristeza", "decepción meh"), ("(´；ω；`)", "tristeza", "llorar pena"),
    ("(╬ Ò﹏Ó)", "enfado", "enfado furia"), ("(＃｀Д´)", "enfado", "enfado grito"),
    ("ヽ(`⌒´メ)ノ", "enfado", "enfado rabia"), ("(｀へ´)", "enfado", "enfado molesto"),
    ("(ಠ益ಠ)", "enfado", "furia rabia"), ("( ｰ̀εｰ́ )", "enfado", "enfurruñado puchero"),
    ("(╯°□°)╯︵ ┻━┻", "mesa", "mesa volcar enfado rabia"), ("┬─┬ノ( º _ ºノ)", "mesa", "mesa ordenar calma arreglar"),
    ("(ノಠ益ಠ)ノ彡┻━┻", "mesa", "mesa furia volcar"), ("┻━┻ ︵ヽ(`Д´)ﾉ︵ ┻━┻", "mesa", "mesas doble furia"),
    ("(°o°)", "sorpresa", "sorpresa oh"), ("Σ(°ロ°)", "sorpresa", "sorpresa susto"),
    ("(⊙_⊙)", "sorpresa", "sorpresa asombro"), ("w(°ｏ°)w", "sorpresa", "sorpresa increíble"),
    ("(ﾟДﾟ;)", "sorpresa", "susto sorpresa"), ("ヽ(°〇°)ﾉ", "sorpresa", "pánico gritar"),
    ("(⁄ ⁄•⁄ω⁄•⁄ ⁄)", "vergüenza", "vergüenza sonrojo"), ("(〃▽〃)", "vergüenza", "vergüenza tímido"),
    ("(*/ω＼*)", "vergüenza", "esconderse vergüenza"), ("(^_^;)", "nervios", "nervios apuro"),
    ("(・_・;)", "nervios", "nervios incómodo"), ("(￣▽￣;)", "nervios", "apuro nervios"),
    ("(・・?)", "duda", "duda confusión"), ("(・_・ヾ", "duda", "confusión rascar"),
    ("┐(￣ヘ￣)┌", "duda", "no sé encogerse"), ("¯\\_(ツ)_/¯", "duda", "encogerse no sé da igual"),
    ("( ˘•ω•˘ )", "duda", "pensar duda"), ("(￢_￢)", "duda", "sospecha mirada"),
    ("(¬‿¬)", "duda", "pícaro sospecha"), ("ಠ_ಠ", "duda", "desaprobación mirada juicio"),
    ("(＾▽＾)ノ", "saludo", "hola saludo"), ("( ´ ▽ ` )ﾉ", "saludo", "hola adiós"),
    ("(^_^)/", "saludo", "hola saludo"), ("ヾ(・ω・)ノ", "saludo", "hola adiós chao"),
    ("(￣▽￣)ノ", "saludo", "hola buenas"), ("(｀・ω・´)ゞ", "saludo", "entendido ok a la orden"),
    ("(￣^￣)ゞ", "saludo", "saludo entendido"),
    ("m(_ _)m", "gracias", "perdón gracias reverencia"), ("(人 •͈ᴗ•͈)", "gracias", "gracias por favor"),
    ("(b ᵔ▽ᵔ)b", "gracias", "bien perfecto ok"), ("(*￣▽￣)b", "gracias", "genial bien"),
    ("( •̀ ω •́ )✧", "ánimo", "confianza listo brillo"), ("ᕦ(ò_óˇ)ᕤ", "ánimo", "fuerza músculo ánimo"),
    ("(ง •̀_•́)ง", "ánimo", "luchar ánimo vamos"), ("(๑•̀ㅂ•́)و✧", "ánimo", "ánimo vamos éxito"),
    ("\\(^o^)/", "ánimo", "ganar victoria hurra"), ("✧٩(•́⌄•́๑)و ✧", "ánimo", "victoria bien hecho"),
    ("(｀・ω・´)", "ánimo", "decidido serio"),
    ("(－_－) zzZ", "sueño", "dormir sueño"), ("(∪｡∪)｡｡｡zzZ", "sueño", "dormir sueño"),
    ("(￣o￣) zzZZzzZZ", "sueño", "dormir roncar"), ("(=_=)", "sueño", "cansado aburrido"),
    ("(︶︹︺)", "sueño", "cansado fastidio"), ("(×_×)", "sueño", "agotado ko muerto"),
    ("(；一_一)", "sueño", "fastidio meh"),
    ("(っ˘ڡ˘ς)", "comida", "comer rico delicioso"), ("( ˘▽˘)っ♨", "comida", "comida caliente té ramen"),
    ("(￣～￣)", "comida", "masticar comer"),
    ("♪(´ε｀ )", "música", "música silbar"), ("ヾ(´〇`)ﾉ♪♪♪", "música", "cantar música"),
    ("(〜￣▽￣)〜", "música", "bailar música"), ("┏(＾0＾)┛┗(＾0＾)┓", "música", "bailar fiesta"),
    ("(=^･ω･^=)", "animales", "gato miau"), ("ฅ^•ﻌ•^ฅ", "animales", "gato zarpas"), ("(^・ω・^ )", "animales", "gato"),
    ("∪･ω･∪", "animales", "perro guau"), ("ʕ•ᴥ•ʔ", "animales", "oso"), ("(ᵔᴥᵔ)", "animales", "oso tierno"),
    ("(・x・)", "animales", "conejo"), ("／(･ × ･)＼", "animales", "conejo"), ("くコ:彡", "animales", "calamar"),
    (">゜))))彡", "animales", "pez"),
    ("ε=ε=┌( >_<)┘", "acción", "correr prisa"), ("┬┴┬┴┤(･_├┬┴┬┴", "acción", "esconderse espiar mirar"),
    ("(^_−)☆", "acción", "guiño"), ("(￣ω￣)☆", "acción", "guiño brillo"), ("(⌐■_■)", "acción", "gafas molón cool"),
]

KANJI_UI = {
    "numerals": ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十",
                 "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十"],
    "weekdays": [  # Sunday first, like JS Date.getDay()
        {"kanji": "日", "es": "domingo"}, {"kanji": "月", "es": "lunes"}, {"kanji": "火", "es": "martes"},
        {"kanji": "水", "es": "miércoles"}, {"kanji": "木", "es": "jueves"}, {"kanji": "金", "es": "viernes"},
        {"kanji": "土", "es": "sábado"}],
    "months": [
        {"n": "一月", "wafu": "睦月", "romaji": "Mutsuki", "es": "enero"},
        {"n": "二月", "wafu": "如月", "romaji": "Kisaragi", "es": "febrero"},
        {"n": "三月", "wafu": "弥生", "romaji": "Yayoi", "es": "marzo"},
        {"n": "四月", "wafu": "卯月", "romaji": "Uzuki", "es": "abril"},
        {"n": "五月", "wafu": "皐月", "romaji": "Satsuki", "es": "mayo"},
        {"n": "六月", "wafu": "水無月", "romaji": "Minazuki", "es": "junio"},
        {"n": "七月", "wafu": "文月", "romaji": "Fumizuki", "es": "julio"},
        {"n": "八月", "wafu": "葉月", "romaji": "Hazuki", "es": "agosto"},
        {"n": "九月", "wafu": "長月", "romaji": "Nagatsuki", "es": "septiembre"},
        {"n": "十月", "wafu": "神無月", "romaji": "Kannazuki", "es": "octubre"},
        {"n": "十一月", "wafu": "霜月", "romaji": "Shimotsuki", "es": "noviembre"},
        {"n": "十二月", "wafu": "師走", "romaji": "Shiwasu", "es": "diciembre"}],
    "dateUnits": {"year": "年", "month": "月", "day": "日", "hour": "時", "minute": "分", "second": "秒"},
    "seasons": [{"kanji": "春", "es": "primavera"}, {"kanji": "夏", "es": "verano"},
                {"kanji": "秋", "es": "otoño"}, {"kanji": "冬", "es": "invierno"}],
    "greetings": {
        "byHour": [{"from": 5, "to": 11, "jp": "おはよう", "es": "Buenos días"},
                   {"from": 11, "to": 18, "jp": "こんにちは", "es": "Buenas tardes"},
                   {"from": 18, "to": 23, "jp": "こんばんは", "es": "Buenas noches"},
                   {"from": 23, "to": 5, "jp": "おやすみ", "es": "Que descanses"}],
        "welcomeBack": {"jp": "お帰りなさい", "es": "Bienvenido de nuevo"},
        "goodWork": {"jp": "お疲れさま", "es": "Buen trabajo"},
        "boot": {"jp": "ようこそ", "es": "Bienvenido"},
        "shutdown": {"jp": "おやすみなさい", "es": "Buenas noches"},
        "reboot": {"jp": "また後で", "es": "Hasta ahora"},
        "updating": {"jp": "更新中", "es": "Actualizando"},
        "diskPassword": {"jp": "鍵", "es": "Contraseña del disco"}},
    "modules": {
        "obi": {"kanji": "帯", "es": "Barra"}, "shima": {"kanji": "島", "es": "Isla"},
        "torii": {"kanji": "鳥居", "es": "Lanzador"}, "engawa": {"kanji": "縁側", "es": "Centro de control"},
        "fumi": {"kanji": "文", "es": "Notificaciones"}, "koyomi": {"kanji": "暦", "es": "Calendario"},
        "kagi": {"kanji": "鍵", "es": "Bloqueo"}, "dengen": {"kanji": "電源", "es": "Energía"},
        "kura": {"kanji": "蔵", "es": "Portapapeles"}, "techo": {"kanji": "手帳", "es": "Notas"},
        "mihari": {"kanji": "見張", "es": "Monitor"}, "settei": {"kanji": "設定", "es": "Ajustes"},
        "kabegami": {"kanji": "壁紙", "es": "Fondos"}, "mado": {"kanji": "窓", "es": "Reglas de ventanas"},
        "shinobi": {"kanji": "忍", "es": "Ahorro extremo"}, "oni": {"kanji": "鬼", "es": "Rendimiento extremo"},
        "kishin": {"kanji": "鬼神", "es": "Kishin (experimental)"}, "kakusei": {"kanji": "覚醒", "es": "Despertar"},
        "fune": {"kanji": "船", "es": "Apps de Windows"}, "snake": {"kanji": "蛇", "es": "IA local"},
        "mamori": {"kanji": "守", "es": "Mantenimiento autónomo"},
        # ideas de Claude (docs/07-IDEAS.md)
        "haichi": {"kanji": "配置", "es": "Pantallas"}, "happyo": {"kanji": "発表", "es": "Presentar"},
        "hogo": {"kanji": "保護", "es": "Cuidado del OLED"}, "hikae": {"kanji": "控", "es": "Copias de seguridad"},
        "fukugen": {"kanji": "復元", "es": "Restaurar sesión"}, "honban": {"kanji": "本番", "es": "Producción (SSH)"},
        "iro": {"kanji": "色", "es": "Cuentagotas"}, "shuchu": {"kanji": "集中", "es": "Modo foco"},
        "yomu": {"kanji": "読", "es": "Leer y traducir"}, "kyukei": {"kanji": "休憩", "es": "Descanso"}},
    "settingsPages": [  # kanji = page header (30 px); glyph = one kanji for the 26×26 sidebar seal
        {"id": "apariencia", "kanji": "外観", "glyph": "彩", "es": "Apariencia"},
        {"id": "barra", "kanji": "帯", "glyph": "帯", "es": "Barra e isla"},
        {"id": "pantalla", "kanji": "画面", "glyph": "画", "es": "Pantalla"},
        {"id": "sonido", "kanji": "音", "glyph": "音", "es": "Sonido"},
        {"id": "red", "kanji": "網", "glyph": "網", "es": "Red y Bluetooth"},
        {"id": "energia", "kanji": "電源", "glyph": "電", "es": "Energía"},
        {"id": "shinobi", "kanji": "忍", "glyph": "忍", "es": "Shinobi"}, {"id": "oni", "kanji": "鬼", "glyph": "鬼", "es": "Oni"},
        {"id": "fune", "kanji": "船", "glyph": "船", "es": "Apps de Windows"},
        {"id": "snake", "kanji": "蛇", "glyph": "蛇", "es": "Snake"},
        {"id": "mamori", "kanji": "守", "glyph": "守", "es": "Mantenimiento"},
        {"id": "bloqueo", "kanji": "鍵", "glyph": "鍵", "es": "Bloqueo"},
        {"id": "entrada", "kanji": "入力", "glyph": "入", "es": "Teclado y ratón"},
        {"id": "atajos", "kanji": "技", "glyph": "技", "es": "Atajos"},
        {"id": "notificaciones", "kanji": "通知", "glyph": "文", "es": "Notificaciones"},
        {"id": "ventanas", "kanji": "窓", "glyph": "窓", "es": "Ventanas"},
        {"id": "fondos", "kanji": "壁紙", "glyph": "壁", "es": "Fondos"},
        {"id": "acerca", "kanji": "情報", "glyph": "情", "es": "Acerca de"}],
    "toggles": {
        "wifi": {"kanji": "網", "es": "Wi-Fi"}, "bluetooth": {"kanji": "青", "es": "Bluetooth"},
        "dnd": {"kanji": "静", "es": "No molestar"}, "nightLight": {"kanji": "夜", "es": "Luz nocturna"},
        "airplane": {"kanji": "空", "es": "Modo avión"}, "caffeine": {"kanji": "醒", "es": "Mantener despierto"},
        "mic": {"kanji": "声", "es": "Micrófono"}, "record": {"kanji": "録", "es": "Grabar pantalla"},
        "screenshot": {"kanji": "写", "es": "Captura"}, "vpn": {"kanji": "隠", "es": "VPN"},
        "darkMode": {"kanji": "闇", "es": "Tema oscuro"}},
    "powerProfiles": {"power-saver": {"kanji": "省", "es": "Ahorro"},
                      "balanced": {"kanji": "均", "es": "Equilibrado"},
                      "performance": {"kanji": "速", "es": "Rendimiento"}},
    "power": [{"id": "lock", "kanji": "鍵", "key": "l", "es": "Bloquear"},
              {"id": "suspend", "kanji": "眠", "key": "s", "es": "Suspender"},
              {"id": "logout", "kanji": "退", "key": "e", "es": "Cerrar sesión"},
              {"id": "reboot", "kanji": "再", "key": "r", "es": "Reiniciar"},
              {"id": "poweroff", "kanji": "終", "key": "p", "es": "Apagar"}],
    "battery": {"battery": "電", "charging": "充", "full": "満", "low": "低", "limit": "限"},
    "weatherWmo": {  # Open-Meteo WMO codes
        "0": {"kanji": "晴", "es": "Despejado", "icon": "clear_day"},
        "1": {"kanji": "晴", "es": "Casi despejado", "icon": "partly_cloudy_day"},
        "2": {"kanji": "曇", "es": "Parcialmente nublado", "icon": "partly_cloudy_day"},
        "3": {"kanji": "曇", "es": "Nublado", "icon": "cloud"},
        "45": {"kanji": "霧", "es": "Niebla", "icon": "foggy"}, "48": {"kanji": "霧", "es": "Niebla helada", "icon": "foggy"},
        "51": {"kanji": "雨", "es": "Llovizna débil", "icon": "rainy_light"},
        "53": {"kanji": "雨", "es": "Llovizna", "icon": "rainy_light"},
        "55": {"kanji": "雨", "es": "Llovizna intensa", "icon": "rainy"},
        "56": {"kanji": "氷", "es": "Llovizna helada", "icon": "weather_mix"},
        "57": {"kanji": "氷", "es": "Llovizna helada intensa", "icon": "weather_mix"},
        "61": {"kanji": "雨", "es": "Lluvia débil", "icon": "rainy_light"}, "63": {"kanji": "雨", "es": "Lluvia", "icon": "rainy"},
        "65": {"kanji": "雨", "es": "Lluvia intensa", "icon": "rainy_heavy"},
        "66": {"kanji": "氷", "es": "Lluvia helada", "icon": "weather_mix"},
        "67": {"kanji": "氷", "es": "Lluvia helada intensa", "icon": "weather_mix"},
        "71": {"kanji": "雪", "es": "Nevada débil", "icon": "weather_snowy"}, "73": {"kanji": "雪", "es": "Nevada", "icon": "weather_snowy"},
        "75": {"kanji": "雪", "es": "Nevada intensa", "icon": "snowing_heavy"},
        "77": {"kanji": "雪", "es": "Granos de nieve", "icon": "weather_snowy"},
        "80": {"kanji": "雨", "es": "Chubascos", "icon": "rainy"}, "81": {"kanji": "雨", "es": "Chubascos", "icon": "rainy"},
        "82": {"kanji": "雨", "es": "Chubascos fuertes", "icon": "rainy_heavy"},
        "85": {"kanji": "雪", "es": "Chubascos de nieve", "icon": "weather_snowy"},
        "86": {"kanji": "雪", "es": "Chubascos de nieve fuertes", "icon": "snowing_heavy"},
        "95": {"kanji": "雷", "es": "Tormenta", "icon": "thunderstorm"},
        "96": {"kanji": "雹", "es": "Tormenta con granizo", "icon": "thunderstorm"},
        "99": {"kanji": "雹", "es": "Tormenta con granizo fuerte", "icon": "thunderstorm"}},
    "moonPhases": [  # 8 phases, starting at new moon
        {"kanji": "新月", "es": "Luna nueva"}, {"kanji": "三日月", "es": "Luna creciente"},
        {"kanji": "上弦", "es": "Cuarto creciente"}, {"kanji": "十三夜", "es": "Gibosa creciente"},
        {"kanji": "満月", "es": "Luna llena"}, {"kanji": "寝待月", "es": "Gibosa menguante"},
        {"kanji": "下弦", "es": "Cuarto menguante"}, {"kanji": "有明月", "es": "Luna menguante"}],
    "mangohud": {"fps": "速", "cpu": "脳", "gpu": "絵", "ram": "記", "vram": "像", "power": "電", "temp": "熱",
                 "frametime": "間"},
    "nvimModes": {"normal": "常", "insert": "挿", "visual": "視", "vline": "行", "vblock": "塊", "replace": "換",
                  "command": "令", "terminal": "端", "select": "選"},
    "gitStatus": {"branch": "枝", "ahead": "先", "behind": "後", "diverged": "岐", "staged": "済", "modified": "変",
                  "untracked": "新", "deleted": "消", "renamed": "名", "stashed": "蔵", "conflicted": "衝"},
    "indicators": {"fune": "船", "snake": "蛇", "rebootPending": "新", "recording": "録", "shinobi": "忍", "oni": "鬼",
                   "mamori": "守"},
    "funeStatus": {"running": {"kanji": "動", "es": "Activa"}, "paused": {"kanji": "停", "es": "En pausa"},
                   "off": {"kanji": "止", "es": "Apagada"}, "starting": {"kanji": "起", "es": "Arrancando"}},
    "snakeStatus": {"loaded": {"kanji": "起", "es": "Modelo cargado"}, "idle": {"kanji": "眠", "es": "Dormida (0 MB)"},
                    "thinking": {"kanji": "考", "es": "Pensando"}, "blocked": {"kanji": "封", "es": "Bloqueada (Shinobi/Oni)"}},
    "mamoriStatus": {"ok": {"kanji": "安", "es": "Todo en orden"}, "waiting": {"kanji": "待", "es": "Esperando condiciones"},
                     "updating": {"kanji": "更", "es": "Actualizando"}, "holding": {"kanji": "留", "es": "Retenido"},
                     "repaired": {"kanji": "直", "es": "Reparado"}, "rolledBack": {"kanji": "戻", "es": "Revertido"},
                     "attention": {"kanji": "注", "es": "Necesita a Ayoub"}},
    "watermarks": {"notification": "文", "workspaceEmpty": "空", "search": "探す", "clipboard": "蔵", "calendar": "暦",
                   "music": "音", "weather": "天"},
}


# ----------------------------------------------------------------------------- themes
def th(i, name, kanji, kana, mode, desc, wall, colors, term, system, glass=0.72, ring=None):
    return {"id": i, "name": name, "kanji": kanji, "kana": kana, "mode": mode, "description": desc,
            "colorFormat": "CSS hex: #RRGGBB o #RRGGBBAA (la shell y el motor de temas lo convierten por destino)",
            "wallpaper": wall, "colors": colors,
            "glass": {"alpha": glass, "opaqueAlpha": 0.94,
                      "border": "#ffffff12" if mode != "light" else "#00000012",
                      "highlight": "#ffffff0b" if mode != "light" else "#ffffff99"},
            "focusRing": ring or {"active": [colors["accent"], colors["accentHover"]], "inactive": colors["surface3"],
                                  "urgent": colors["accent2"], "windows": "#00a3af"},
            "shadow": "#00000099" if mode != "light" else "#2a1a1033",
            "scrim": "#0000006b" if mode != "light" else "#1a141026",
            "terminal": term, "system": system}


def term(bg, fg, cursor, sel, pal, cursor_text="#ffffff", sel_fg=None):
    return {"background": bg, "foreground": fg, "cursor": cursor, "cursorText": cursor_text,
            "selectionBackground": sel, "selectionForeground": sel_fg or fg, "palette": pal}


DARK_SYS = {"colorScheme": "prefer-dark", "gtkTheme": "adw-gtk3-dark", "iconTheme": "Papirus-Dark",
            "papirusFolders": "red", "cursorTheme": "Bibata-Modern-Classic", "kvantum": None}
LIGHT_SYS = {"colorScheme": "prefer-light", "gtkTheme": "adw-gtk3", "iconTheme": "Papirus",
             "papirusFolders": "red", "cursorTheme": "Bibata-Modern-Ice", "kvantum": None}

THEMES = [
    th("kurenai", "Kurenai", "紅", "くれない", "dark", "Tinta sumi + rojo laca; apto OLED (por defecto)", "kurenai-yoru.jpg",
       {"bg": "#0b0a0c", "surface0": "#141216", "surface1": "#1b181d", "surface2": "#241f26", "surface3": "#2e2830",
        "outline": "#2c262e", "outlineStrong": "#463e48", "text": "#f4efe6", "textMuted": "#aaa39b", "textDim": "#6f6862",
        "accent": "#e60033", "accentHover": "#ff1f4f", "accentSoft": "#e6003329", "onAccent": "#ffffff",
        "accent2": "#e6b422", "success": "#68be8d", "warning": "#f8b500", "error": "#ff4d6a", "info": "#a0d8ef"},
       term("#0b0a0c", "#f4efe6", "#e60033", "#4a1424",
            ["#1b181d", "#e60033", "#68be8d", "#e6b422", "#6d8fdb", "#e7609e", "#00a3af", "#d7d1c8",
             "#4f4852", "#ff4d6a", "#8fd4a9", "#f5cc52", "#93acec", "#f29ac0", "#4fc6cf", "#f4efe6"]),
       DARK_SYS),
    th("kohaku", "Kōhaku", "紅白", "こうはく", "light", "El logo hecho tema: washi blanco + sello rojo", "kohaku-washi.jpg",
       {"bg": "#f4f1ec", "surface0": "#ffffff", "surface1": "#f8f5f0", "surface2": "#efeae3", "surface3": "#e6e0d7",
        "outline": "#e3ddd4", "outlineStrong": "#cdc5ba", "text": "#18171c", "textMuted": "#5f5953", "textDim": "#9d968f",
        "accent": "#e60033", "accentHover": "#c8002d", "accentSoft": "#e600331f", "onAccent": "#ffffff",
        "accent2": "#a8770a", "success": "#2c7a52", "warning": "#946300", "error": "#c4002b", "info": "#1f6f99"},
       term("#fbf9f5", "#18171c", "#e60033", "#f6cdd6",
            ["#18171c", "#c4002b", "#2c7a52", "#946300", "#1e50a2", "#884898", "#00808a", "#d9d2c8",
             "#6f6862", "#e60033", "#3a9466", "#b0800f", "#3a6bc4", "#a35cb0", "#008a94", "#ffffff"],
            sel_fg="#18171c"),
       LIGHT_SYS),
    th("sumi", "Sumi", "墨", "すみ", "dark", "Grises de tinta; solo el sello y los errores en rojo", "sumi-sansui.jpg",
       {"bg": "#0e0e0f", "surface0": "#161617", "surface1": "#1c1c1e", "surface2": "#252527", "surface3": "#2f2f32",
        "outline": "#2a2a2d", "outlineStrong": "#444448", "text": "#ecebe8", "textMuted": "#a3a19d", "textDim": "#6b6966",
        "accent": "#e60033", "accentHover": "#ff1f4f", "accentSoft": "#e600331f", "onAccent": "#ffffff",
        "accent2": "#b7b1a6", "success": "#8fb79a", "warning": "#d9b25c", "error": "#ff4d6a", "info": "#9bb7c9"},
       term("#0e0e0f", "#ecebe8", "#e60033", "#3a2a2e",
            ["#1c1c1e", "#e60033", "#8fb79a", "#d9b25c", "#8ea4bf", "#b49ab8", "#8fb5b8", "#c9c7c2",
             "#55555a", "#ff4d6a", "#a9cbb2", "#e8c87f", "#a9bbd1", "#c8b3cb", "#a7c8ca", "#ecebe8"]),
       DARK_SYS),
    th("ai", "Ai", "藍", "あい", "dark", "Índigo aizome + oro", "ai-seigaiha.jpg",
       {"bg": "#070b14", "surface0": "#0d1322", "surface1": "#121a2d", "surface2": "#19233a", "surface3": "#212d47",
        "outline": "#1d2740", "outlineStrong": "#34436a", "text": "#eef1f8", "textMuted": "#a3abc2", "textDim": "#636d86",
        "accent": "#e6b422", "accentHover": "#f2c94c", "accentSoft": "#e6b42229", "onAccent": "#16120a",
        "accent2": "#e60033", "success": "#7bc4a0", "warning": "#f8b500", "error": "#ff5a6e", "info": "#8fb2ff"},
       term("#070b14", "#eef1f8", "#e6b422", "#22305a",
            ["#121a2d", "#e8505b", "#7bc4a0", "#e6b422", "#5b8def", "#b48ee0", "#3fc1c9", "#c8cfdf",
             "#414d6b", "#ff7a83", "#9edbbb", "#f2cd5e", "#8fb2ff", "#cdb0f0", "#79dbe1", "#eef1f8"],
            cursor_text="#070b14"),
       DARK_SYS | {"papirusFolders": "yellow"}),
    th("matcha", "Matcha", "抹茶", "まっちゃ", "light", "Té verde y papel kinari", "matcha-asanoha.jpg",
       {"bg": "#f3f1e7", "surface0": "#fbfaf5", "surface1": "#f6f4ea", "surface2": "#ebe8da", "surface3": "#e0dccb",
        "outline": "#e2decf", "outlineStrong": "#c9c3ad", "text": "#1f2419", "textMuted": "#575c4a", "textDim": "#959a86",
        "accent": "#5d7a16", "accentHover": "#4b6612", "accentSoft": "#69821b24", "onAccent": "#ffffff",
        "accent2": "#e60033", "success": "#3a7a47", "warning": "#8f6900", "error": "#c8102e", "info": "#246c94"},
       term("#fbfaf5", "#1f2419", "#5d7a16", "#dde5c4",
            ["#1f2419", "#c8102e", "#4e7a1f", "#8f6900", "#2a6aa0", "#8a4f8a", "#1f7470", "#d6d2c1",
             "#6b705d", "#e60033", "#69821b", "#9a7a0a", "#3f86bf", "#a86aa8", "#2a8a86", "#fbfaf5"],
            sel_fg="#1f2419"),
       LIGHT_SYS | {"papirusFolders": "green"}),
    th("yozakura", "Yozakura", "夜桜", "よざくら", "dark", "Violeta nocturno + rosa sakura", "yozakura.jpg",
       {"bg": "#0d0912", "surface0": "#151020", "surface1": "#1b1528", "surface2": "#241c34", "surface3": "#2e2441",
        "outline": "#2a2138", "outlineStrong": "#453858", "text": "#f6eef4", "textMuted": "#b6a8be", "textDim": "#75687e",
        "accent": "#f0708f", "accentHover": "#f791aa", "accentSoft": "#f0708f29", "onAccent": "#1a0d14",
        "accent2": "#b4a2e6", "success": "#8fd1a8", "warning": "#f3c35b", "error": "#ff5c7a", "info": "#9cc7ef"},
       term("#0d0912", "#f6eef4", "#f0708f", "#3d2340",
            ["#1b1528", "#ff5c7a", "#8fd1a8", "#f3c35b", "#8aa6ef", "#f0708f", "#7fcbd6", "#d8cde0",
             "#4d4060", "#ff8aa0", "#b0e3c4", "#f8d88e", "#b0c3f7", "#f59ab1", "#a7dde6", "#f6eef4"],
            cursor_text="#0d0912"),
       DARK_SYS | {"papirusFolders": "pink"}),
    th("shinobi", "Shinobi", "忍", "しのび", "dark", "Negro puro OLED y luminancia mínima (lo usa el modo ahorro)", None,
       {"bg": "#000000", "surface0": "#000000", "surface1": "#0a0a0a", "surface2": "#121212", "surface3": "#1a1a1a",
        "outline": "#161616", "outlineStrong": "#262626", "text": "#b8b2aa", "textMuted": "#7f7973", "textDim": "#4a4642",
        "accent": "#c0001f", "accentHover": "#d1102f", "accentSoft": "#c0001f26", "onAccent": "#e8e2da",
        "accent2": "#8a7a4a", "success": "#4f8a68", "warning": "#a8862e", "error": "#c23a50", "info": "#5f8798"},
       term("#000000", "#b8b2aa", "#c0001f", "#2a0a10",
            ["#0a0a0a", "#c0001f", "#4f8a68", "#a8862e", "#4d6a95", "#8a5a85", "#3f7f87", "#8a857e",
             "#333333", "#c23a50", "#63a07d", "#bf9d45", "#6380ab", "#a0709b", "#55969e", "#b8b2aa"],
            cursor_text="#000000"),
       DARK_SYS | {"cursorTheme": "Bibata-Modern-Classic"}, glass=0.94,
       ring={"active": ["#c0001f", "#c0001f"], "inactive": "#121212", "urgent": "#8a7a4a", "windows": "#006b73"}),
]


# ----------------------------------------------------------------------------- contrast check (WCAG 2.x)
def lum(hex_):
    h = hex_.lstrip("#")[:6]
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def check(themes):
    fails, rows = [], []
    for t in themes:
        c = t["colors"]
        req = [("text", s, 7.0 if s == "bg" else 4.5) for s in ("bg", "surface0", "surface1", "surface2")]
        req += [("textMuted", s, 4.5) for s in ("bg", "surface0", "surface1")]
        req += [("accent", "bg", 3.0), ("accent", "surface0", 3.0), ("onAccent", "accent", 3.0),
                ("error", "surface0", 3.0), ("success", "surface0", 3.0), ("warning", "surface0", 3.0)]
        tp = t["terminal"]
        req += [("fg", "termbg", 7.0)]
        worst = 99
        for a, b, need in req:
            ca = tp["foreground"] if a == "fg" else c[a]
            cb = tp["background"] if b == "termbg" else c[b]
            r = ratio(ca, cb)
            worst = min(worst, r / need)
            if r < need:
                fails.append(f"{t['id']}: {a} on {b} = {r:.2f} < {need}")
        # terminal ANSI colours 1-6 and 9-14 must be readable on the terminal background (>= 3:1)
        for i in [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14]:
            r = ratio(tp["palette"][i], tp["background"])
            if r < 3.0:
                fails.append(f"{t['id']}: ansi {i} {tp['palette'][i]} on terminal bg = {r:.2f} < 3")
        rows.append(f"  {t['id']:9s} text/bg {ratio(c['text'], c['bg']):5.2f}  muted/s1 {ratio(c['textMuted'], c['surface1']):4.2f}"
                    f"  accent/bg {ratio(c['accent'], c['bg']):4.2f}  onAccent {ratio(c['onAccent'], c['accent']):4.2f}")
    return fails, rows


def write(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n")


def main(out):
    out = pathlib.Path(out)
    assert len(SEKKI) == 24 and len(KO) == 72 and len(KO_SYMBOL) == 72 and len(KOTOWAZA) == 42 and len(COLORES) == 31
    assert len({k[0] for k in KOTOWAZA}) == 42, "duplicate proverb"
    sekki = [{"index": i, "kanji": k, "kana": kana, "romaji": r, "es": es, "start": list(d), "lon": (315 + 15 * i) % 360}
             for i, (k, kana, r, es, d) in enumerate(SEKKI)]
    ko = [{"index": i + 1, "kanji": k, "symbol": KO_SYMBOL[i], "kana": kana, "romaji": r, "es": es, "start": list(d),
           "lon": (315 + 5 * i) % 360, "sekki": i // 3} for i, (k, kana, r, es, d) in enumerate(KO)]
    write(out / "kisetsu-72.json", {
        "comment": "二十四節気 y 七十二候 (versión japonesa, 略本暦). 'start' = fecha habitual [mes, día] (±1 día según el año); "
                   "'lon' = longitud eclíptica solar de inicio (cálculo exacto). 'symbol' = kanji corto para la isla.",
        "sekki": sekki, "ko": ko})
    write(out / "kotowaza.json", {"comment": "Proverbio del día = índice (día del año % 42). Para el bloqueo (縦書き).",
                                  "kotowaza": [{"index": i, "jp": a, "kana": b, "romaji": c, "es": d}
                                               for i, (a, b, c, d) in enumerate(KOTOWAZA)]})
    write(out / "colores-nippon.json", {
        "comment": "Colores tradicionales japoneses (JIS 慣用色名 cuando existe). 'accents' = muestras de 外観 en Ajustes.",
        "accents": ACCENTS,
        "colors": [{"id": i, "kanji": k, "kana": kana, "es": es, "hex": hx} for i, k, kana, es, hx in COLORES]})
    write(out / "kanji-ui.json", KANJI_UI)
    assert len({k for k, _, _ in KAOMOJI}) == len(KAOMOJI), "duplicate kaomoji"
    write(out / "kaomoji.json", {"comment": "Kaomoji para Torii (`:`), buscables por palabra en español (07-IDEAS).",
                                 "kaomoji": [{"k": k, "cat": c, "es": e.split()} for k, c, e in KAOMOJI]})
    for t in THEMES:
        write(out / "themes" / f"{t['id']}.json", t)
    write(out / "themes" / "index.json", {"default": "kurenai", "order": [t["id"] for t in THEMES],
                                          "powerSaving": "shinobi"})
    fails, rows = check(THEMES)
    print(f"wrote {out}: 24 sekki · 72 kō · {len(KOTOWAZA)} kotowaza · {len(COLORES)} colores · {len(KAOMOJI)} kaomoji · "
          f"{len(THEMES)} temas")
    print("\n".join(rows))
    if fails:
        print("CONTRAST FAILURES:\n  " + "\n  ".join(fails))
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else K / "assets" / "data")
