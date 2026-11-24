"""Lingoy studio art: native vectors, reproducible, with archived upstream sources."""
from pathlib import Path
import json,hashlib,xml.etree.ElementTree as ET,colorsys,re,math,shutil
ROOT=Path(__file__).resolve().parents[1]
ART={}
def path(d,fill='none',stroke='#493A58',sw=3):return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>'
def circle(x,y,r,fill,stroke='none',sw=3):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def ellipse(x,y,rx,ry,fill):return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}"/>'
def rect(x,y,w,h,fill,rx=6,stroke='none',sw=3):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def leaf(x=120,y=40):return f'<g transform="translate({x} {y})">'+path('M0 0C4-24 28-25 37-21 35-3 20 6 0 0Z','url(#green)','none')+path('M5-1 28-16','none','#5B8964',2)+'</g>'
def shine(d):return path(d,'none','#FFFFFF',6).replace('stroke-width="6"','stroke-width="6" opacity=".42"')
def svg(body):
 defs=''.join(f'<linearGradient id="{n}" x1="0" y1="0" x2=".85" y2="1"><stop stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>' for n,a,b in [('red','#FFB2A2','#E56476'),('green','#B8D59D','#69A88A'),('gold','#FFE5A0','#E9B94F'),('purple','#CAB0E5','#9477C6'),('water','#BEE7EA','#73ACBF'),('cream','#FFFAE8','#E8D6B8'),('wood','#D6B28B','#AC7D5D'),('grey','#E7E5EF','#A6A6BE'),('orange','#FFD5A2','#EEA05F')])
 return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256"><defs>'+defs+'</defs>'+ellipse(128,224,78,8,'#E9E3ED')+'<g stroke-linecap="round" stroke-linejoin="round">'+body+'</g></svg>'
# Fruit: unambiguous silhouettes, richer tone, seeds, rind and leaves.
ART['apple']=path('M128 77C101 54 52 69 51 116 48 160 79 205 103 205 116 205 120 196 128 196 136 196 143 205 156 205 182 205 208 156 206 116 203 70 158 54 128 77Z','url(#red)','none')+path('M127 77C123 60 130 45 140 39','none','#886349',6)+leaf(137,58)+shine('M76 105C68 123 73 145 81 153')
ART['pear']=path('M117 57C90 59 99 94 84 113 44 156 58 204 103 212 155 228 202 204 194 162 190 136 156 111 150 87 148 69 142 54 117 57Z','url(#green)','none')+path('M129 60 137 37','none','#886349',6)+leaf(136,47)+shine('M83 149C73 168 85 185 96 188')
ART['banana']=path('M48 66C62 169 139 185 206 117 187 191 103 228 64 174 42 145 34 106 40 72Z','url(#gold)','none')+path('M49 75C65 164 136 188 198 128','none','#D6A746',3)+path('M39 73 38 58 49 56 53 69Z','#8D7457','none')+path('M202 117 211 109 217 115 209 125Z','#8D7457','none')+shine('M59 101C68 135 91 157 116 161')
for w,col in [('orange','orange'),('apricot','orange'),('plum','purple'),('peach','red')]:
 body=circle(128,139,74,'url(#'+col+')')+leaf(129,70)+path('M128 69 133 50','none','#886349',5)+shine('M78 109C68 125 68 140 73 151')
 if w in ['peach','apricot','plum']:body+=path('M132 81C153 112 149 163 134 193','none',{'peach':'#D88279','apricot':'#D69A5D','plum':'#7C5EA8'}[w],3)
 else:body+=''.join(circle(x,y,1.4,'#E59E62') for x,y in [(98,105),(157,115),(168,152),(113,175),(101,148),(141,190),(86,137)])
 ART[w]=body
ART['lemon']=path('M53 132C39 117 62 78 99 75 128 46 185 79 199 122 220 137 191 183 159 187 127 213 70 185 58 149Z','url(#gold)','none')+leaf(161,83)+shine('M81 109C97 93 117 91 135 96')
ART['cherry']=path('M81 147C104 107 109 67 139 43 154 83 158 114 174 139','none','#6E9C74',5)+leaf(137,57)+circle(83,168,39,'url(#red)')+circle(173,172,40,'url(#red)')+shine('M63 154 59 166')+shine('M155 155 151 168')
ART['grape']=path('M123 81C113 60 125 44 145 40','none','#8C6A50',5)+leaf(127,65)+''.join(circle(x,y,25,'url(#purple)','#A28AC5',1.5) for x,y in [(91,93),(133,91),(170,105),(74,132),(115,130),(157,140),(93,170),(137,179),(119,210)])+shine('M79 88 78 94')
ART['strawberry']=path('M53 91C60 54 195 54 202 94 204 137 157 206 128 218 98 203 48 133 53 91Z','url(#red)','none')+path('m128 84-22-36 33 16 29-19-8 35 34 10-43 9-23 20-17-24-39-11 33-10Z','url(#green)','none')+''.join(ellipse(x,y,2.5,5,'#FFE6AF') for x,y in [(80,116),(111,123),(148,121),(175,115),(94,151),(130,154),(161,152),(112,182),(142,186)])
ART['watermelon']=path('M37 100h182C211 236 44 234 37 100Z','url(#green)','none')+path('M49 100h158C198 217 57 216 49 100Z','#FFF3D9','none')+path('M59 100h138C188 204 67 204 59 100Z','url(#red)','none')+''.join(ellipse(x,y,3,5,'#564050') for x,y in [(82,121),(113,128),(145,128),(174,121),(107,159),(149,158),(128,181)])
ART['pineapple']=path('m126 90-38-48 31 12 7-29 18 28 31-17-19 52Z','url(#green)','none')+ellipse(129,151,61,73,'url(#gold)')+'<clipPath id="pineappleclip"><ellipse cx="129" cy="151" rx="61" ry="73"/></clipPath><g clip-path="url(#pineappleclip)">'+''.join(path(f'M{60+i*23} 105l95 95','none','#D5AD60',2) for i in range(5))+''.join(path(f'M{82+i*23} 90 45 180','none','#D5AD60',2) for i in range(5))+'</g>'+shine('M88 123 84 143')
ART['mango']=path('M157 57C214 80 203 163 159 193 122 231 52 210 60 160 66 109 97 42 157 57Z','url(#orange)','none')+path('M160 59C191 100 174 157 135 188 168 142 161 96 142 63Z','#F18D78','none')+leaf(147,62)+shine('M93 105C84 117 79 135 80 148')
ART['coconut']=circle(146,143,71,'url(#wood)')+''.join(path(f'M{90+i*22} 91q-18 52 3 103','none','#967450',2) for i in range(6))+ellipse(108,167,65,51,'#AB7D59')+ellipse(108,163,57,44,'#FFF9E9')+ellipse(108,164,42,29,'#EEE7D9')+ellipse(108,168,36,23,'#FBF6E9')
ART['kiwi']=ellipse(158,124,66,76,'url(#wood)')+circle(103,164,62,'#A27C54')+circle(103,163,55,'url(#green)')+ellipse(103,163,13,24,'#F8EEB8')+''.join(ellipse(103+math.cos(i*math.pi/8)*31,163+math.sin(i*math.pi/8)*31,2,3,'#514746') for i in range(16))
# Kitchen and food.
ART['bread']=path('M53 109C41 63 92 48 128 54 180 44 218 76 202 111v90H53Z','url(#wood)','none')+path('M69 114C59 79 98 64 128 71 167 64 197 83 186 114v73H69Z','url(#cream)','none')+path('m89 99 11-16m22 16 11-18m21 18 9-15','none','#C7A16F',4)
ART['rice']=path('M54 135h148c-8 54-35 77-74 77s-65-23-74-77Z','url(#water)','none')+ellipse(128,137,74,26,'#FFF8E8')+''.join(path(f'M{x} {y}q5-5 11 0','none','#D3C4A9',2) for x,y in [(81,130),(109,121),(137,131),(164,137),(96,145),(130,148),(153,119)])+path('M91 213h74','none','#7397A6',5)
ART['cheese']=path('m48 121 119-62 46 60-16 78H48Z','url(#gold)','none')+path('m48 121 119-62 46 60Z','#FFEAA7','none')+''.join(circle(x,y,rr,'#DEAD45') for x,y,rr in [(77,151,11),(126,172,14),(167,144,9),(167,182,6)])
ART['egg']=path('M178 76c20 32 32 69 21 94-16 33-71 33-85 0-10-25 4-62 24-94 10-15 30-15 40 0Z','url(#cream)','none')+ellipse(93,170,57,44,'#FFFCF5')+ellipse(93,170,26,26,'url(#gold)')+shine('M80 160 79 166')
ART['milk']=path('m66 68 26-27h58l28 27v142H66Z','url(#water)','none')+path('m66 68 26-27h58l-23 27Z','#E4F3F0','none')+rect(82,106,79,74,'#FFFCF1',12)+path('M105 126c-16 18-14 32 5 32 21 0 18-16 5-32Z','url(#water)','none')+rect(91,36,61,11,'#9B8AC2',3)
ART['water']=rect(92,60,74,150,'url(#water)',18)+rect(107,34,44,29,'#9B8AC2',5)+path('M97 126q32 13 64 0v62q0 17-17 17h-29q-18 0-18-18Z','#92C8D6','none')+shine('M106 86v45')+rect(98,100,62,43,'#EFF9F7',3)+path('M129 109c-20 20-13 26 0 26s20-7 0-26Z','#7BB6C9','none')
for w in ['coffee','tea','cup']:
 body=path('M173 100h21c34 0 36 55-18 52','none','#9B87BE',12)+path('M54 87h125v69c0 64-125 64-125 0Z','url(#purple)','none')+ellipse(116,88,63,20,'#EEE5F0')+ellipse(116,90,52,13,'#8D6852' if w=='coffee' else '#B79A66')+ellipse(123,211,86,9,'#DDD1E8')+path('M90 58q-11-13 0-25m36 26q-11-13 0-25','none','#B5A5BC',3)
 if w=='tea':body+=path('M146 91v72l19 9v-30l-19 4','none','#D9C4A0',2)+leaf(164,192)
 if w=='coffee':body+=ellipse(186,198,9,15,'#916749')+path('m182 188 7 20','none','#D4B397',2)
 ART[w]=body
ART['soup']=path('M48 131h160c-7 57-42 77-80 77s-72-22-80-77Z','url(#cream)','none')+ellipse(128,131,80,27,'#ECA36D')+''.join(ellipse(x,y,9,4,col) for x,y,col in [(80,127,'#92AF7A'),(115,139,'#F8D77E'),(147,120,'#98B680'),(176,134,'#F8D77E')])+path('M215 77 173 132','none','#9BA1B6',7)+path('M99 77q-11-13 0-25m32 25q-11-13 0-25','none','#B5A5BC',3)
ART['cake']=path('M54 112h148v92H54Z','url(#red)','none')+rect(54,137,148,20,'#FFF2D7',0)+rect(54,178,148,16,'#FFF2D7',0)+path('M49 111c0-27 157-27 157 0v23c-15 21-24-5-36 8-16 15-21-7-37 4-19 14-24-9-38 0-14 8-24-7-46-7Z','url(#cream)','none')+rect(120,48,12,49,'url(#purple)',2)+path('M126 46c-21-21 0-30 0-30s23 23 0 30Z','url(#gold)','none')+circle(80,104,9,'#E4757F')+circle(176,104,9,'#E4757F')
ART['pizza']=path('m46 80 173 24-116 115Z','url(#gold)','none')+path('m46 80 173 24-6 19L52 101Z','url(#wood)','none')+''.join(circle(x,y,13,'#E7867D') for x,y in [(90,119),(150,130),(110,173)])+''.join(ellipse(x,y,6,3,'#7EAA7D') for x,y in [(76,107),(128,117),(142,150),(96,151)])
ART['sandwich']=path('m45 92 148-31 20 16-146 48Z','url(#wood)','none')+path('m49 119 156-34-8 85-142 37Z','url(#cream)','none')+path('m52 146 150-42-1 17-146 42Z','#9AB780','none')+path('m54 166 145-41-1 16-141 43Z','#EA9287','none')+path('m56 187 144-40v28L61 218Z','url(#wood)','none')
ART['carrot']=path('M77 73c27-24 69 3 69 26 0 27-66 107-89 124 0-44 1-119 20-150Z','url(#orange)','none')+path('m113 74 2-48m14 50 24-38m-38 35-26-35','none','#7FA879',9)+path('m77 107 15 6m-20 30 14 5m-20 25 11 4','none','#D28C54',3)+shine('M95 87 82 125')
ART['potato']=path('M65 92C90 53 128 61 167 74 208 85 221 140 198 180 177 216 116 222 78 198 46 177 41 128 65 92Z','url(#wood)','none')+''.join(path(f'M{x} {y}q5-4 9 0','none','#9B7653',2) for x,y in [(91,98),(151,110),(115,159),(168,172),(74,151),(142,193)])+shine('M78 118 75 135')
ART['tomato']=ellipse(128,149,82,67,'url(#red)')+path('m128 97-32-23 18 25-39 8 45 8 10 23 10-23 39-1-30-16 10-27-26 22Z','url(#green)','none')+path('m128 97 2-33','none','#6E9C74',5)+shine('M72 130q-6 15 1 25')
ART['cucumber']=path('M59 176 153 61c23-23 61-1 48 27l-81 122c-21 28-77-9-61-34Z','url(#green)','none')+path('m85 171 77-96m-57 111 71-99','none','#699D7E',3)+ellipse(92,189,39,31,'#CDE2AD')+ellipse(92,189,29,23,'#E4EDC3')+''.join(ellipse(x,y,2,4,'#C0CB90') for x,y in [(78,185),(91,178),(105,185),(92,199)])
# Clear household objects and learning materials.
ART['book']=path('M32 74q45-22 96 2 44-24 96-2v122q-50-12-96 7-48-20-96-7Z','url(#purple)','none')+path('M39 63q48-18 89 11 46-28 89-11v124q-45-12-89 13-46-25-89-13Z','url(#cream)','none')+path('M128 75v120','none','#D1BD9E',3)+''.join(path(f'M55 {y}q31-1 56 11m35 0q28-12 54-10','none','#CBBFAE',2) for y in [93,114,135,156])
ART['notebook']=rect(63,43,137,170,'url(#purple)',12)+rect(78,44,14,168,'#8B71AD',1)+rect(106,73,69,54,'#FFF8E6',7)+path('M119 89h42m-42 15h28','none','#B3A0C2',3)+''.join(path(f'M57 {y}h25','none','#E9D3A4',5) for y in [67,94,121,148,175,197])
ART['paper']=path('M64 36h97l39 40v143H64Z','url(#cream)','none')+path('M161 36v40h39Z','#D6C6A8','none')+''.join(path(f'M83 {y}h94','none','#B9ADBE',3) for y in [105,130,155,180])
ART['pencil']='<g transform="rotate(34 128 128)">'+rect(108,37,40,139,'url(#gold)',3)+rect(108,30,40,29,'url(#red)',6)+rect(108,55,40,14,'#D1BF9E',0)+path('m108 176 20 53 20-53Z','#E5CCAA','none')+path('m121 210 7 19 7-19Z','#544A60','none')+path('M119 71v97','none','#FFEBC1',4)+'</g>'
ART['pen']='<g transform="rotate(34 128 128)">'+rect(112,38,32,135,'url(#water)',9)+path('m112 173 16 47 16-47Z','url(#gold)','none')+rect(111,36,34,40,'url(#purple)',9)+path('M140 48h11v54','none','#89759E',4)+shine('M121 84v70')+'</g>'
ART['ruler']='<g transform="rotate(-25 128 128)">'+rect(33,99,190,61,'url(#gold)',7)+''.join(path(f'M{x} 101v{22 if i%2==0 else 13}','none','#AD8B54',2.5) for i,x in enumerate(range(48,212,15)))+'</g>'
ART['eraser']=path('m51 127 70-62 89 34-68 83-83-20Z','url(#red)','none')+path('m121 65 89 34-68 83-27-48 53-52Z','url(#purple)','none')+path('m59 162 83 20 68-83v31l-68 79-83-21Z','#9B85B7','none')+path('m62 206 13 3m14 5 9-1','none','#C8BDCD',3)
ART['backpack']=path('M66 87c0-64 124-64 124 0v119H66Z','url(#red)','none')+path('M106 53V37h44v16','none','#A385AD',7)+rect(83,130,91,68,'url(#purple)',14)+path('M90 151h77m-8 0v16','none','#F9E6BE',3)+path('M65 99H52v81h14m124-81h15v81h-15','none','#B78A98',8)+shine('M79 86q5-23 31-25')
ART['computer']=rect(48,48,162,115,'url(#purple)',10)+rect(58,59,142,91,'url(#water)',4)+rect(105,164,45,27,'url(#grey)',2)+path('M30 195h196l-18 20H47Z','url(#grey)','none')+rect(82,79,69,10,'#E3F1ED',3)+rect(82,100,99,6,'#E3F1ED',2)+rect(82,115,80,6,'#E3F1ED',2)
ART['phone']=rect(84,25,91,207,'url(#purple)',18)+rect(92,37,75,176,'url(#water)',12)+rect(111,37,37,9,'#847195',3)+''.join(rect(x,y,16,16,col,5) for x,y,col in [(104,85,'#E3B7C3'),(137,85,'#F6D990'),(104,119,'#C6DFAE'),(137,119,'#C4B1E0')])+rect(110,197,39,4,'#EEF6F0',2)
ART['clock']=circle(128,132,87,'url(#purple)')+circle(128,132,73,'#FFF8EA')+''.join(path(f'M{128+math.sin(i*math.pi/6)*57:.2f} {132-math.cos(i*math.pi/6)*57:.2f}l{math.sin(i*math.pi/6)*6:.2f} {-math.cos(i*math.pi/6)*6:.2f}','none','#A99CB2',2) for i in range(12))+path('M128 85v47l35 18','none','#6E5A8B',7)+circle(128,132,7,'#E4B565')
ART['key']=circle(91,99,43,'url(#gold)')+circle(91,99,18,'#FFF8ED')+path('m121 127 68 74 19-18-14-14-13 9-11-12 11-11-13-14-11 10-19-23Z','url(#gold)','none')
ART['umbrella']=path('M41 118c6-93 167-94 175 0-20-11-37-8-55 5-21-18-43-18-65 0-21-17-38-16-55-5Z','url(#purple)','none')+path('M128 117v75c0 31 42 30 42 0','none','#A28367',7)+path('M128 48C105 65 99 90 96 118m32-70c23 17 30 42 33 70','none','#AC92CB',3)
ART['lamp']=path('M90 45h77l31 94H58Z','url(#gold)','none')+path('M128 139v64','none','#9B85B2',10)+ellipse(128,210,55,11,'url(#purple)')+path('m188 145 1 22','none','#A98956',3)+circle(189,170,4,'#C9A76E')
ART['mirror']=ellipse(128,111,68,87,'url(#wood)')+ellipse(128,111,57,74,'url(#water)')+path('m104 160 46-86m-26 96 28-52','none','#EAF3ED',4)+path('M127 199v17m-40 3h82','none','#A78161',9)
ART['house']=path('M57 111h144v98H57Z','url(#cream)','none')+path('m35 114 93-83 94 83-15 14-79-69-79 69Z','url(#red)','none')+rect(113,148,35,61,'url(#wood)',4)+rect(72,136,29,31,'url(#water)',4)+rect(161,136,26,31,'url(#water)',4)+path('M87 139v26m-13-13h25m75-13v26m-12-13h24','none','#FBF3E5',2)+circle(138,180,2,'#FFE4A0')
ART['door']=rect(65,30,131,192,'url(#wood)',3)+rect(77,43,108,179,'#F5E4C3',2)+rect(87,54,88,168,'url(#purple)',3)+rect(101,69,59,59,'#BBA3D2',5)+rect(101,143,59,62,'#BBA3D2',5)+circle(166,137,6,'url(#gold)')
ART['window']=rect(43,46,174,165,'url(#wood)',2)+rect(54,58,152,139,'url(#water)',1)+path('M129 57v140M54 128h152','none','#FFF1D5',9)+path('m68 111 28-40m40 112 47-58','none','#E7F3ED',4)+rect(34,207,191,11,'#CBA982',3)
ART['chair']=rect(81,37,99,92,'url(#purple)',14)+rect(74,121,111,26,'url(#wood)',7)+path('M84 147 76 218m99-71 8 71M95 146v51m70-51v51','none','#A98765',9)
ART['table']=path('M38 107h182v27H38Z','url(#wood)','none')+path('M49 134v81m159-81v81M75 135v50m109-50v50','none','#A98765',10)+rect(37,96,184,22,'#D8B58C',6)
ART['bed']=path('M44 101h18v112H44Zm160-12h14v124h-14Z','url(#wood)','none')+rect(59,116,145,80,'url(#purple)',5)+rect(60,115,143,28,'#DDD0E8',4)+rect(68,92,51,35,'#FFF6E8',10)+path('M61 146h143','none','#B49CCC',3)+path('M66 197v17m132-17v17','none','#A98765',8)
ART['sofa']=rect(54,76,149,104,'url(#purple)',22)+rect(64,122,129,57,'#C8B4DD',10)+rect(38,126,35,71,'#9F82BF',15)+rect(185,126,35,71,'#9F82BF',15)+path('M126 123v55M69 201v13m122-13v13','none','#8D719F',5)
ART['cupboard']=rect(59,34,143,180,'url(#wood)',8)+rect(71,47,117,155,'#DFBF95',3)+path('M129 48v152','none','#B68B66',3)+circle(118,128,4,'#8C7185')+circle(141,128,4,'#8C7185')+path('M73 214v12m114-12v12','none','#A98765',8)
ART['carpet']=path('m42 88 138-39 34 137-138 39Z','url(#purple)','none')+path('m61 104 105-29 22 94-105 30Z','none','#E7C9A2',4)+path('m124 107 31 22-19 36-32-24Z','url(#gold)','none')+''.join(path(f'M{76+i*16} {225-i*4}l3 11','none','#B4A0CF',3) for i in range(8))
ART['roof']=ART['house']+path('m35 114 93-83 94 83-15 14-79-69-79 69Z','url(#red)','#98696F',2)+path('m81 97 12 11m33-52 12 10m6 24 11 10m13 6 13 11','none','#CF8E8D',3)
# Landscape illustrations with depth, water and vegetation.
ART['river']=path('M29 93 81 45l46 45 46-55 56 60v116H29Z','url(#green)','none')+path('M133 88c-101 38 58 53-11 87-31 15-47 24-47 36h99c-24-28 26-37 4-70-24-31-70-29-45-53Z','url(#water)','none')+path('M122 124q39 17 30 28m-27 32-18 12','none','#E0F2EF',3)+path('m37 117 20-34 19 34Z','#83A67B','none')+rect(54,117,6,18,'#9D7B5D',2)
ART['lake']=path('m26 124 49-66 47 56 44-74 64 89v75H26Z','url(#green)','none')+path('m149 67 17-27 23 30-17-5-11 8Z','#F2F2DF','none')+ellipse(128,173,99,43,'url(#water)')+path('M78 165h45m19 20h35m-65-37h35','none','#E8F6EC',3)+path('M44 207v-29m0 17-12-10m180 22v-32m0 15 12-11','none','#71966A',4)
ART['sea']=path('M24 83h208v131H24Z','#E9F3ED','none')+circle(184,66,23,'url(#gold)')+path('M24 111c28-29 42 22 69-1s47 22 70-2 44 4 69 4v104H24Z','url(#water)','none')+path('M25 147c26-22 45 20 71 0s43 21 68 0 44 5 67 0m-206 36c27-22 44 20 71 0s43 21 68 0 44 5 67 0','none','#E0F1EB',4)
ART['fan']=circle(128,100,77,'url(#grey)')+circle(128,100,65,'#EDEAF2')+''.join('<g transform="rotate('+str(i*120)+' 128 100)">'+path('M129 99c-49-1-64-45-31-49 31-4 28 22 31 49Z','url(#purple)','none')+'</g>' for i in range(3))+circle(128,100,16,'url(#gold)')+rect(117,177,22,33,'url(#grey)',2)+path('M88 210h80l16 19H72Z','url(#purple)','none')+circle(129,219,3,'#E9C777')
# Faces now have features and context, instead of anonymous block figures.
def person(x,y,color='purple',female=False,small=False):
 scale='.7' if small else '1'
 return f'<g transform="translate({x} {y}) scale({scale})">'+(path('M-27 14v-31c0-42 55-42 55 0v31Z','#8D6854','none') if female else '')+circle(0,-11,23,'#E9BD9E')+path('M-23-16c-4-36 51-37 46 1-19-4-22-20-27-14-4 6-10 12-19 13Z','#8D6854','none')+circle(-8,-10,1.8,'#5C4B53')+circle(8,-10,1.8,'#5C4B53')+path('M-6 1q6 5 12 0','none','#9C6B68',2)+path('M-30 54c0-53 60-53 60 0v49h-60Z','url(#'+color+')','none')+path('M-18 102v28m36-28v28','none','#87798E',10)+path('M-29 53v34m58-34v34','none','#E9BD9E',9)+'</g>'
for w,f in [('mother',True),('father',False)]:
 ART[w]=person(91,90,'purple' if f else 'water',f)+person(173,128,'gold',False,True)+path('m116 146 38 31','none','#E9BD9E',9)
ART['listen']=person(105,85,'purple',False)+path('M138 142 151 112 140 99','none','#E9BD9E',10)+path('M168 78q23 23 0 46m18-60q36 37 0 73','none','#C0A3D7',5)
ART['classroom']=rect(35,39,187,95,'url(#wood)',5)+rect(43,47,171,78,'#75AFA0',3)+path('M67 74h25m-13-12v25m34-13h27m20-11 18 21m0-21-18 21M65 105h117','none','#EDF1DE',3)+''.join(rect(x,y,66,15,'url(#wood)',4)+path(f'M{x+8} {y+15}v22m50-22v22','none','#AF8E73',5) for x,y in [(35,158),(153,158),(35,204),(153,204)])
ART['school']=ART['house']+path('m106 42 22-19 23 19Z','url(#purple)','none')+circle(128,65,13,'#FFF8E8')+path('M128 58v8l5 4','none','#A58CBF',2)
ART['teacher']=rect(117,43,119,101,'url(#wood)',4)+rect(123,49,106,87,'#7EAE9C',2)+path('M149 71h50m-50 18h39','none','#F4F0D6',3)+person(72,86,'purple',True)+path('M102 140 155 104','none','#E9BD9E',8)+path('m152 107 23-33','none','#A48969',3)
ART['student']=person(127,80,'water',False)+path('M73 128q26-13 53 0 27-13 54 0v50q-25-8-54 4-28-13-53-4Z','url(#cream)','none')+path('M126 130v49','none','#C4B39B',2)
# Apply the reproducible artwork and restyle the remaining editorial illustrations.
def remaster(text):
 root=ET.fromstring(text);ns='{http://www.w3.org/2000/svg}';defs=ET.Element(ns+'defs');gradient={}
 for e in root.iter():
  for key in ['fill','stroke']:
   value=e.get(key,'')
   if re.fullmatch('#[0-9a-fA-F]{3}',value):value='#'+''.join(x*2 for x in value[1:]);e.set(key,value)
   if not re.fullmatch('#[0-9a-fA-F]{6}',value):continue
   rgb=tuple(int(value[i:i+2],16) for i in [1,3,5]);h,l,s=colorsys.rgb_to_hls(*(x/255 for x in rgb))
   if l<.2:e.set(key,'#4B3D59');continue
   if s<.14 or l>.95:continue
   if key=='stroke':continue
   if value not in gradient:
    gid='studio'+str(len(gradient));gradient[value]=gid
    a=colorsys.hls_to_rgb(h,min(.9,l*.62+.28),s*.62);b=colorsys.hls_to_rgb(h,max(.24,l*.68+.10),s*.67)
    g=ET.SubElement(defs,ns+'linearGradient',{'id':gid,'x1':'0','y1':'0','x2':'.85','y2':'1'})
    for off,col in [('0',a),('1',b)]:ET.SubElement(g,ns+'stop',{'offset':off,'stop-color':'#'+''.join(f'{round(x*255):02x}' for x in col)})
   e.set(key,'url(#'+gradient[value]+')')
  if e.get('stroke') not in [None,'none']:
   e.set('stroke-linejoin','round');e.set('stroke-linecap','round')
 root.insert(0,defs);ET.register_namespace('','http://www.w3.org/2000/svg');return ET.tostring(root,encoding='unicode')
def main():
 manifest=json.loads((ROOT/'data/picture_sources.json').read_text());starter=json.loads((ROOT/'mobile/assets/starter_vectors.json').read_text());by={x['id']:x for x in manifest['sources']}
 archive=ROOT/'data/picture_art_originals_1_6';archive.mkdir(exist_ok=True)
 for word,value in starter.items():
  aid=value.split('/')[-1];p=ROOT/'data/picture_art_sources'/(aid+'.svg');original=archive/(aid+'.svg')
  if not original.exists():shutil.copyfile(p,original)
  item=by[aid];item.setdefault('original_source',dict(item));item['art_revision']='Lingoy Studio 1.7'
  if word in ART:
   p.write_text(svg(ART[word]));item.update(origin='lingoy',source_file=aid+'.svg',url='',license='MIT',author='Lingoy')
   item['art_change']='new original illustration'
  else:p.write_text(remaster(original.read_text()));item['art_change']='palette, gradient and rounded-stroke derivative; original geometry retained'
  item['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
 manifest['art_refresh']={'starter_refined':192,'new_originals':len(set(ART)&set(starter)),'source_archive':'data/picture_art_originals_1_6'}
 (ROOT/'data/picture_sources.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=1))
 print(manifest['art_refresh'])
if __name__=='__main__':main()
