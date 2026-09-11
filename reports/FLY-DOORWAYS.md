# Sineğin kapı köşelerinde takibi — 11 Eylül 2026

Görüş kaybında sinek son görülen oyuncu konumuna yöneliyordu, fakat görünür
oyuncuyla koruduğu 2,3 birim uzaklığı burada da koruyordu. Dar dönüşte son
konuma ulaşamadan bekliyor, üç saniyelik iz süresi bitince oyuncudan
uzaklaşabiliyordu. Tek satırlık düzeltme yalnızca oyuncu görünürken bu
mesafeyi korur; görünmüyorsa son görülen noktaya kadar yaklaşır. Duvardan
geçiş/görüş, güncel gizli oyuncu konumuna erişim veya yol planlama eklenmedi.

Aynı gerçek Godot fiziğinde üç tohum ve iki rota yönü karşılaştırıldı.
Oyuncu 3,2 birim/sn hızla yan oda → servis koridoru → karşı oda → ana
koridor halkasını durmadan yürüdü. Dört yan/arka kapı iki yönde geçildi.
Sabit `[0.16,0.06,0.08,0.04]` sinir sürüşü uçuş denetimini izole eder;
bunlar biyolojik ya da öğrenilmiş navigasyon ölçümleri değildir.

| Tohum | Rota yönü | Önce, rota sonunda mesafe | Sonra, rota sonunda mesafe | Sonra, en uzun görüş kaybı |
|---|---|---:|---:|---:|
| 42 | Makine → arşiv | 2.82 | 2.82 | 0.00 sn |
| 3 | Makine → arşiv | 2.89 | 2.89 | 0.30 sn |
| 17 | Makine → arşiv | 2.74 | 2.74 | 0.30 sn |
| 42 | Arşiv → makine | 3.16 | 2.83 | 0.30 sn |
| 3 | Arşiv → makine | 11.15 | 2.86 | 0.27 sn |
| 17 | Arşiv → makine | 11.56 | 2.72 | 0.25 sn |

Mesafeler oyun birimidir. Eski sürümde ters yönün 3 ve 17 tohumlarında,
rota sonunda on saniye daha beklendiğinde bile oyuncu yeniden bulunamadı.
Yeni sürümde altı rotanın sonunda da oyuncu görünür ve üç birimden yakındı;
bütün hareket parçaları bağımsız fizik ışınıyla kontrol edildi, duvarı
kesen hareket olmadı. Önce/sonra keşfi sabit 60 Hz simülasyonla hızlandırıldı;
son regresyon testi normal oyun hızında tekrarlandı.

Mevcut `tests/fly.gd` içine 12 rota kontrolü eklendi; toplam **25 uçuş
kontrolü** hatasız geçti. Boyut, normal koridor takibi, kısa yön değişimleri,
duraklama, sessiz/eski sinir çıktısında durma da korundu. Ayrı gerçek
beyinle **48 tam tur kontrolü** başarılıydı; kişisel kayıtlar kullanılmadı.
Semgrep uygulama taraması 318 kural / 39 dosya, değişen iki GDScript dosyasına
ayrıca 47 genel kural: iki taramada da sıfır bulgu/hata/uyarı. GDScript
mantığını doğrulayan kontrol Godot testidir.

`web-20260911-doorway-follow` yayını önceki statik dosyaları koruyarak atomik
etkinleştirildi. Yeni paket `game-01113e1eb9072136.pck`; HTTPS'teki motor,
ses ve paket özetleri yerel dosyalarla eşleşti, önceki paket de erişilebilir.
Beyin ve Nginx yeniden başlatılmadı; mevcut WSS bağlantısı, beyin PID'si ve
öğrenme dosyalarının baytları korundu. Canlı Chrome menüsü ve önbelleği
silmeden normal yenileme başarılı; konsol hatası yok. Canlıda test turu
başlatılmadı. Sağlık: hazır, 166.700 nöron, 27 öğrenme örneği / 5 tur.
Önce yayın doğrulandı, sonra GitHub'a gönderildi.

Bu kontrolün kapsamı üç tohumlu sabit sürüş rotalarıdır; her olası oyuncu
rotası için garanti değildir. Fiziksel telefon veya tarayıcıda elle bu
halkanın tamamını yürüme testi yapılmadı. Mobil arayüz/girdi kodu değişmedi.


## Ölçülmüş sinir sürüşü ve gizli konum ayrımı

Ayrı bir `Connectome` örneğinde her örnek öncesi `reset()` çağrıldı;
sekiz normalize girişin tamamı sırasıyla −1, 0 ve +1 olacak biçimde
`step()` çalıştırıldı. Tam 166.700 nöronlu ağdan ölçülen dört çıktı,
mevcut fizik testine sabit örnekler olarak eklendi. Öğrenme modeli veya
kişisel kayıtlar açılmadı; bu normalize seviyeler biyolojik uyarım
ölçümleri değildir.

Her örnekte aynı başlangıç, tohum ve son görülen konum korundu. Oyuncu
bir denemede arşivde, diğerinde makine odasında duvar arkasına taşındı.
Görüş güncellendikten sonra iki uçuşun 240 fizik karesi karşılaştırıldı;
bu dört saniye hem üç saniyelik konum hafızasını hem sonraki aramayı kapsar.
Gizli oyuncu telemetrisi her karede boş kaldı; uçuş izleri birebir eşleşti.

| Her normalize giriş | En yüksek hız, birim/sn | İki uçuş izi arasındaki en büyük fark |
|---|---:|---:|
| -1 | 6.12878 | 0.00000 |
| +0 | 6.64568 | 0.00000 |
| +1 | 8.00000 | 0.00000 |

Her karede hız sonlu ve 8 birim/sn sınırı içindeydi. Aynı tohumlu iki
başlangıcın karşılaştırması fizik karesinin aynı aşamasından başlatıldı.
Yeni altı kontrolle `tests/fly.gd` normal oyun hızında **31 kontrolü**
hatasız geçti. Semgrep, değişen testte 47 genel kural / 0 bulgu bildirdi;
GDScript davranışı Godot ile doğrulandı.

Üretim hatası bulunmadı; uygulama kodu değiştirilmedi. GitHub push'tan
önce canlı HTML'nin güncel paketi gösterdiği ve HTTPS paket özeti
doğrulandı; sağlık yanıtı hazır, 166.700 nöron, 27 örnek / 5 turdu.
Çalışan hizmet değiştirilmedi; canlı öğrenme test için kullanılmadı.
Bu test dondurulmuş üç
ölçüm örneğini kapsar; sürekli değişen sinir akışı veya her oyuncu rotası
üzerine bir garanti değildir.


## Ölçülmüş sürüşle kesintisiz kapı rotası

Aynı kapı testi, yukarıdaki ölçülmüş düşük ve yüksek giriş örnekleriyle
çalıştırıldı. Üç tohum × iki yön × üç sürüş (önceki sabit denetim örneği
ve iki ölçülmüş örnek), **18 kesintisiz rota** oluşturur. Ara noktalarda
oyuncu beklemez; yalnızca rota sonunda takip mesafesinin üç birimin altına
inmesi için en fazla iki saniye tanınır. Varış anındaki mesafe ayrıca
kaydedildiği için bu bekleme yürüyüş sırasında geride kalmayı gizlemez.

| Sürüş | Varış mesafesi aralığı | En uzun görüş kaybı | Üç birimden yakına gelmek için ek süre |
|---|---:|---:|---:|
| Önceki sabit denetim örneği | 2,719–2,889 | 0,300 sn | 0 sn |
| Ölçülmüş düşük giriş | 2,803–3,055 | 0,483 sn | En fazla 0,050 sn |
| Ölçülmüş yüksek giriş | 2,576–2,760 | 0,350 sn | 0 sn |

Bütün ara noktalar ve dört kapı iki yönde geçildi; hareket parçalarını
kesen duvar bulunmadı. Düşük girişteki 3,055 birimlik anlık mesafe uzun
bir takılma değildi: oyuncu durunca üç fizik karesinde üç birimin altına
indi. Bu ölçüm için uçuş hızları veya takip mesafesi değiştirilmedi.

Mevcut test döngüsü ve sinir örnekleri tekrar kullanıldı. Normal oyun
hızında **55 kontrol** hatasız geçti; buna boyut, duraklama, hız sınırı ve
gizli konum karşılaştırmaları da dahildir. Semgrep: değişen GDScript
üzerinde 47 genel kural / 0 bulgu; davranış kontrolü Godot ile yapıldı.
Üretim değişikliği gerekmedi. Push öncesinde canlı HTML/paket SHA256 ve
HTTPS sağlık yanıtı doğrulandı: hazır, 166.700 nöron, 27 örnek / 5 tur.
Kişisel kayıtlar ve canlı öğrenme test için kullanılmadı. Sonuç, bu sabit
ölçüm örneklerini ve rotaları kapsar; canlı değişken sinir akışı, fiziksel
telefon veya her oyuncu rotası için garanti değildir.
