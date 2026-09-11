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
