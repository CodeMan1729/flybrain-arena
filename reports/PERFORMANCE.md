# FLYFEAR v2 — doğrulama ve öğrenme raporu

Güncel genel performans çalışması: [yükleme, bellek ve çizim optimizasyonu](optimization/README.md).

Son beyin gösterimi ve görünür ölçüm: [yoğun, döndürülebilir ağ](brain-view/README.md).

Son harita genişletmesi ve görünür ölçüm: [üç oda ve servis koridoru](expanded-map/README.md).

Güncel öğrenme sürümü: [v3 eğitim, doğrudan geri bildirim ve doğrulama](learning-v3/README.md).

Son oyun/sinek bakımı ve güncel ölçüm: [kritik düzeltmeler](critical/README.md). Aşağıdaki v2 tablosu tarihsel ölçümdür.

10 Eylül 2026 · Apple M4 Pro, 14 CPU çekirdeği, 24 GB birleşik RAM · macOS 26.6.2 ARM64 · Godot 4.5.2 Compatibility / OpenGL 4.1 Metal.

## Teslim edilen davranış

- Odada özgün 3B gövdesi, altı bacağı ve kanatları olan fiziksel sinek uçar; duvar/mobilya çarpışması, görüş mesafesi/açısı ve engel raycast'i vardır.
- Görünür oyuncu bilgisi gerçek MaleCNS bağlantıları üzerindeki etkinlik hesabına gider. Ölçülen L1/L2/L3/Mi1 çıktıları mühendislik uçuş kontrolünü etkiler; olay tercihlerini dış öğrenen katman belirler.
- Sağ altta 512 gerçek soma konumu, örneklenmiş gerçek bağlantılar ve hesaplanmış etkinlik görülür. Gösterim 2–5 saniyelik son sinir örneğini ve yaşını belirtir; eski veri griye döner. Hesaplamada ağ küçültülmez.
- Öğrenen mod varsayılandır. Her geçerli ödül sonrası atomik kayıt; yeni tur/yeni uygulamada devam; ana menüde tur geçmişi, güncelleme ve olay başına gözlenen tepki sayıları vardır.

## Gerçek bağlantı grafiği ve maliyet

166.700 nöron, 25.582.938 yönlü bağlantı, 124.177.617 temas. Ham kaynak ve dönüştürme kuralları README/manifestte; alt ağ küçültmesi yapılmadı. Sayısal model 24 ayrık etkinlik iterasyonu kullanır, kalibre biyolojik emülasyon değildir. Gösterim için anatomik örnekleme ve downstream bağlam grupları hazırlanması yükleme süresine dahildir.

| Bağımsız tam model ölçümü | Sonuç |
|---|---:|
| Yükleme | 0.680 sn |
| 16 karar p50 | 438.80 ms |
| 16 karar p95 | 440.54 ms |
| En yavaş karar | 440.75 ms |
| Ölçüm sonu RSS | 330.52 MiB |
| Süreç ömrü tepe RSS | 372.52 MiB |

Kanıt: [model ölçümü](brain-benchmark.json), [veri manifesti](../data/manifest.json). Girdi değişikliği çıktıyı değiştirir. Tüm gerçek kenarlar kaldırılıp ağ sıfırlandığında hem dört tip çıktısı hem öğrenen katmanın **12 downstream özelliği sıfırlanır**. Dış karar katmanı ham oyuncu telemetrisini okumaz.

## Gerçek 1920×1080 çizim

Aşağıdaki iki koşu ayrı süreçlerde, tek beyin ve tek oyunla yapıldı. Yeni fiziksel sinek ve beyin görünümü açık; efektler, duraklama, kopma/yeniden bağlanma ve anahtar/çıkış rotası dahil. Kare aralıkları gerçek monoton saatten; ilk iki saniye hariç. Bunlar headless değerleri değildir.

| Ölçüm | Sabit | Öğrenen |
|---|---:|---:|
| Tur tamamlandı | Evet | Evet |
| Kontrol sayısı | 35 | 35 |
| Örneklenen kare | 5986 | 5985 |
| Ortalama FPS | 115.08 | 114.92 |
| Kare süresi p50 | 6.821 ms | 6.830 ms |
| Kare süresi p95 | 13.013 ms | 13.002 ms |
| Kare süresi p99 | 13.382 ms | 13.395 ms |
| Oyun örneklenmiş tepe RSS | 313.45 MiB | 312.75 MiB |
| Beyin örneklenmiş tepe RSS | 334.75 MiB | 334.36 MiB |

60 FPS hedefi bu kısa koşularda karşılandı. RSS 0,5 saniyede bir örneklenir; örnekler arası zirveler görünmeyebilir. GPU belleği ayrıca ölçülmedi; paneldeki oyun heap'i RSS değildir. Başka donanım, güç/termal koşullar ve uzun oturum için garanti yoktur.

Kanıt: [sabit oyun](game-fixed-benchmark.json), [öğrenen oyun](game-learn-benchmark.json), [sabit RSS](runtime-fixed.json), [öğrenen RSS](runtime-learn.json), [gövde ve panel görüntüsü](fly-1080p.png), [oda görüntüsü](game-1080p.png).

## Kontrollü öğrenme sonucu

**Bu değerler yapay tepki puanlarıdır; insan korkusu veya biyolojik sinek öğrenmesi değildir.** Eğitimde 128, değerlendirmede ayrı 64 gerçek tam-graf sinir girdisi kullanıldı. Sekiz politika tohumu (3, 17, 42, 71, 123, 208, 501, 999). Her eğitim 3.072 karar / 769 geçerli güncelleme; her değerlendirme 512 karar / **129 olay**. Bütün koşullarda aynı olay sayısı, 5/60 sn bütçe, 8 sn genel ve 16 sn tekrar aralığı vardır. Değerlendirmede ağırlıklar donduruldu ve keşif kapatıldı.

Ödül kuralı araçta açıkça tanımlıdır: ışık `.5+.38*x`, ses `.5-.38*x`, siluet `.45+.38*speed`; x/speed normalize edilmiş eğitim bağlamı, sonuç .02–.98'e kırpılır. Kuralı öğrenen dış katman 12 **ölçülmüş downstream sinir** özelliği ve bias kullanır. Gerçek bağlantı ağırlıklarının SHA256'sı deney öncesi/sonrası aynı kaldı.

| Koşul | Ortalama yapay tepki |
|---|---:|
| Rastgele kontrol | 0.4821 |
| Sabit model | 0.4841 |
| Eğitilmemiş karar katmanı | 0.4523 |
| Eğitilmiş karar katmanı | 0.5492 |
| Diske yazılıp yeniden yüklenmiş | 0.5492 |
| Eylemden bağımsız karıştırılmış ödül | 0.4712 |
| Sıfır ödülle güncellenmiş | 0.4523 |
| Öğrenme belleği silinmiş | 0.4523 |
| Eğitilmiş; sinir özellikleri sıfırlanmış | 0.5188 |

Eğitilmiş katman sabit modeli **0.0651 puan** geçti; fark sekiz politika tohumunun tamamında pozitiftir. Eşleştirilmiş tohum bootstrap aralığı [0.0522, 0.0772]. Bu aralık ortak sinir izleri üzerinde politika rastlantısallığını özetler; bağımsız insan/hayvan popülasyonuna ilişkin güven aralığı değildir. Kayıt/yükleme sonucu korudu; sıfırlama kazanımı kaldırdı. Sinir özelliği ablasyonu kazanımı azalttı, tamamını kaldırmadı: eğitilmiş bias da tercih saklayabilir.

Bu, dış katmanın tanımlı yapay tepki kuralında eğitim dışındaki girdilere sınırlı genellemesini destekler. Yeni tepki yasaları, gerçek insan korkusu, uzun süreli alışma, öğrenilmiş uçuş ya da biyolojik sinaps plastisitesi test edilmedi. Gerçek oyuncu ödülü daha gürültülüdür; otomatik kaydetme ve güncelleme her turun iyileşme getireceği anlamına gelmez.

Kanıt: [özet ve tüm tohumlar](experiment-summary.json), [192 gerçek sinir hesaplaması](experiment-traces.json), [eğitim/değerlendirme karar günlüğü](experiment.jsonl), [deney betiği](../tools/experiment.py). Tekrarlanan politika kararları bağımsız sinir hesaplaması sayılmaz. Sentetik eğitim çıktıları kullanıcının kişisel oyun belleğine aktarılmaz.

## Düzeltilen hatalar ve test kapsamı

- Sabit/rastgele modun kaydet/sıfırla komutuyla öğrenilmiş dosyayı bozması engellendi.
- Bekle eyleminin ödül almadan öğrenilen olaylarla yarışması kaldırıldı; bütçe/tekrar kapısı seçimden önce uygulanıyor.
- Ödül her geçerli pencerede kaydediliyor; çıkış anındaki kısa bir gecikmeye bağımlılık kaldırıldı. Eksik örnekleme, duraklama veya geçersiz onay öğrenme üretmiyor.
- Aynı tur yeniden bağlantı boyunca korunuyor; duraklatılmışken yeniden bağlantı oyunu kendiliğinden başlatmıyor.
- Geçersiz hareket türleri, model kayıt şeması/istatistikleri ve bilinmeyen eylemler reddediliyor.
- Gövde duraklama/kesintide duruyor; görüş duvarın arkasındaki oyuncu telemetrisini almıyor.
- Görünür klavye testindeki ekran görüntüsü kaynaklı zamanlayıcı hatası düzeltildi: 0,18 sn duvar saati yerine 12 gerçek fizik karesiyle hareket kontrol ediliyor. İki başarısız ara koşunun günlükleri `logs/validation/` altında korunuyor.

**9 Python birim/entegrasyon testi** ve son headless turda **35 oyun kontrolü** geçti. Gerçek veri/ID/kenar/sinir özellikleri, ödül sınırı, öğrenme/retention/reset, bozuk bellek, aynı bütçe, token/origin, otomatik kayıt, tur geçmişi ve sabit modda koruma sınanır. Üretim Godot istemcisi 1,85 sn geç yanıtı uygulamaz; fizik akışı sürer. Godot rotası WASD, oyuncu/sinek çarpışması, görüş, 512 örnek, anahtar, kilitli kapı, tüm efektler, duraklama, aktif/duraklatılmış yeniden bağlantı ve kaydedilmiş zaferi kapsar.

Kanıt: [son tam test çıktısı](full-tests.log), [headless kontrol listesi](game-smoke.json), [test betiği](../test.sh). Otomatik rota insan kullanım/duygu çalışmasının yerine geçmez.

## Önceki sonuçlar ve sınırlar

v1'in sabit modeli geçemeyen öğrenme sonucu (0,5415 vs 0,5470) [eski raporda](v1/PERFORMANCE.md) korunur; [kaynak arşivi](v1/source.tar.gz) vardır. Bu turun ilk duyusal-popülasyon pilotu 0,6207 verdi; [pilot özeti](v2-sensory-readout-pilot.json) korunur. Teslim edilen sürüm doğrudan duyusal popülasyon okumayı kaldırıp gerçek bağlantılardan sonraki grupları kullanır; bu raporun 0,5492 sonucu onun içindir. Farklı protokoller birleştirilmez.

Bağlantı verisi gerçektir; giriş/çıkış anlamları, gövde/sensör, sayısal dinamik ve dış karar katmanı mühendislik tasarımıdır. Biyolojik sineğin korkuyu anladığı veya kendi sinapslarını öğrenmeyle değiştirdiği iddia edilmez. Kalibre LIF, reseptör bazlı plastisite, insan çalışması, uzun süreli dayanıklılık ve imzalı dağıtım bu teslimin dışındadır.
