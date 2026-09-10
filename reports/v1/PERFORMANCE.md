# FLYFEAR — performans ve doğrulama raporu

Ölçüm: 10 Eylül 2026. MacBook Pro, Apple M4 Pro (14 CPU çekirdeği), 24 GB birleşik RAM; macOS 26.6.2, ARM64. Proje başlangıcında klasör boştu; mevcut kullanıcı dosyası değiştirilmedi.

## Tam bağlantı grafiği

Alt ağ küçültmesi **yapılmadı**. 166.700 tanımlı nöron; 25.582.938 yönlü bağlantı; 124.177.617 temas. Kaynak dosyalar SHA256 ile doğrulandı. Grafik işaret/normalizasyon varsayımları ve 3.718 nötr işaretli nöron README'de açıklanır. Bu boyut DOOMFLY'nin LIF dinamiği çalıştırıldı anlamına gelmez: ölçülen, FLYFEAR'ın kendi 24 iterasyonlu bağlantı temelli etkinlik modelidir.

| Ölçüm | Sonuç |
|---|---:|
| İlk içeri alma | 40,63 sn |
| Hazırlama sonunda RSS (zirve değil) | 1.940,91 MiB |
| İlk tam model yükleme | 0.341 sn |
| 16 karar p50 | 438.18 ms |
| 16 karar p95 | 441.04 ms |
| En yavaş karar | 442.07 ms |
| Bağımsız model RSS | 269.88 MiB |
| Bağımsız süreç tepe RSS | 269.97 MiB |

Girdiler değişince ölçülen sinir çıktıları değişti. Gerçek kenarları kaldıran testte giriş nöronları uyarıldığı halde dört çıkış grubu sıfırlandı. Rastgele ağ kullanılmadı. Tam grafiğin bellek/gecikmesi 2–5 saniye hedef aralığına sığdığından alt ağ seçeneğine ihtiyaç olmadı.

Kanıt: [ham model ölçümü](brain-benchmark.json), [içeri alma çıktısı](import.log), [veri manifesti](../data/manifest.json).

## Gerçek 1920×1080 çizim

Godot 4.5.2 Compatibility, `OpenGL 4.1 Metal - 90.5`, Apple M4 Pro. Gerçek macOS penceresi ve 1920×1080 viewport; headless sonuçları bu tabloya alınmadı. Kare aralıkları `Time.get_ticks_usec()` ile ölçüldü. İlk 2 saniye hariç; yaklaşık 50 saniyelik tur. Aynı anda tek beyin süreci, ışık/ses/siluet olayları ve görünür ölçüm paneli açık. Sistem diğer masaüstü uygulamalarıyla birlikte çalışıyordu; kontrollü termal laboratuvar koşulu yok.

| Ölçüm | Sabit model | Öğrenen katman |
|---|---:|---:|
| Tur tamamlandı | Evet | Evet |
| Örneklenen kare | 5738 | 5635 |
| Ortalama FPS | 119.60 | 119.55 |
| Kare süresi p50 | 11.453 ms | 8.187 ms |
| Kare süresi p95 | 12.942 ms | 9.873 ms |
| Kare süresi p99 | 13.462 ms | 10.227 ms |
| Oyun örneklenmiş tepe RSS | 277.58 MiB | 277.91 MiB |
| Beyin örneklenmiş tepe RSS | 297.36 MiB | 297.95 MiB |
| Son karar simülasyon süresi | 437.30 ms | 457.75 ms |

**1080p / 60 FPS hedefi bu kısa ölçümlerde karşılandı.** Uzun oturum, farklı güç/ekran modu, eşzamanlı ağır iş yükü ve başka donanım için garanti değil. RSS her 0,5 saniye örneklendi; örnekler arasındaki kısa zirveler görünmeyebilir. Panelde oyun heap'i gösterilir; RSS ile aynı sayaç değildir. GPU'ya özgü bellek kullanımı ayrı ölçülmedi.

Kanıt: [sabit çizim](game-fixed-benchmark.json), [öğrenen çizim](game-learn-benchmark.json), [sabit bellek izi](runtime-fixed.json), [öğrenen bellek izi](runtime-learn.json), [gerçek ekran görüntüsü](game-1080p.png).

## Eş bütçeli üç mod deneyi

60 gerçek tam-graf sinir kararı ölçüldü; aynı dizi 3 mod × 3 tohum için yeniden oynatıldı. Her tur 180 sanal saniye, 3 saniyelik karar aralığı. Bütün modlarda 5 olay / 60 saniye, 8 saniye genel ve 16 saniye aynı olay beklemesi. **Aşağıdaki tepki değerleri sentetik test verisidir; insan korkusu değildir.** Tepki senaryosu siluete daha büyük tepki verecek şekilde yazılmıştır; bu modelin insanı daha iyi korkuttuğuna kanıt olmaz.

| Mod | Olay sayısı (tohum 3 / 42 / 123) | Üç tur ortalama sentetik tepki | Dış katman güncellemesi |
|---|---|---:|---|
| Rastgele kontrol | 15, 15, 15 | 0.4612 | 0, 0, 0 |
| Sabit model | 12, 14, 13 | 0.5470 | 0, 0, 0 |
| Öğrenen karar katmanı | 13, 14, 13 | 0.5415 | 13, 14, 13 |

Öğrenen katman bu kısa, yapay karşılaştırmada sabit modeli geçmedi (0,5415 vs 0,5470). Parametre güncellenmesi ve kaydedilmesi doğrulandı; üstünlük veya genellenebilir öğrenme gösterilmedi. Sinek bağlantı ağırlıkları hiçbir modda öğrenmedi. Daha yüksek rastgele-kontrol farkı da bu kurgulanmış tepki dağılımının sonucudur; biyolojik anlam yüklenmez.

Kanıt: [deney özeti](experiment-summary.json), [540 karar/politika kaydı](experiment.jsonl). Aynı sinir izi kullanıldığı için bu kayıtlardaki 540 satır 540 bağımsız sinir hesaplaması değildir; 60 hesaplama tekrar kullanıldı.

## Doğrulama

- **8 unittest/entegrasyon testi geçti.** Gerçek veri, tüm ID'ler, giriş/çıkış, bağlantı ablasyonu, normalizasyon, ödül, bütçe, tohum, kayıt/sıfırlama, bozuk kayıt, origin/token reddi, onay/ödül akışı, yinelenen onay, pause ve sunucu kapanışı.
- Üretim Godot WebSocket istemcisi, 1,85 saniye geciktirilen olay yanıtını **uygulamadı**; kare döngüsü devam etti, eylem bekle kaldı. Bu test sunucusu yalnızca `tests/` altında açıkça sentetik fixture olarak bulunur.
- Godot'ta son headless turda **27**, görünür 1080p sabit turda **27**, öğrenen turda **23 oynanış kontrolü** geçti: duvar çarpışması, anahtarsız kilit, masa/anahtar, tüm efektler, arkadaki 3B ses konumu, yerel spam engeli, duraklatma, gerçek socket kopması ve otomatik yeniden bağlantı, anahtarlı kapı, zafer, gerçek sinir çıktısı.
- Son headless tura eklenen W/A/S/D testleri gerçek `InputEventKey` → `Input.is_physical_key_pressed` → fizik hareketi yolunu geçti; her tuş karakteri hareket ettirdi.
- `setup.sh` mevcut kurulumda tekrar çalıştırıldı; üç ham dosya hash'i yeniden doğrulandı ve Godot import edildi.
- İlk testlerde değişken/sinyal adı çakışması, otomatik rotanın çıkış eşiğinden önce durması ve döngülü ambiyansın kapanışta ses kaynağını bırakmaması bulundu. Düzeltilmiş son headless ve görünür koşular temiz tamamlandı; eski başarısız geliştirme günlükleri `logs/validation/` içinde korunur.

Kanıt: [son test çıktısı](full-tests.log), [headless oyun sonucu](game-smoke.json), [kurulum testi](setup-test.log).

## Tamamlanmayan / doğrulanmayan kapsam

İnsan katılımcılı korku veya öğrenme deneyi yapılmadı. DOOMFLY'nin özgün ViZDoom/LIF yığını burada çalıştırılmadı; kaynak ve lisans incelendi. FLYFEAR'ın sayısal etkinlik modeli biyolojik olarak kalibre edilmedi; nöromodülatör/reseptör dinamiği yok. Uzun süreli soak testi, ayrı GPU bellek ölçümü, donanım ses basıncı, farklı Mac modelleri, imzalı/notarize uygulama paketi test edilmedi. Prototip yerel Godot projesi + tek komut başlatıcı olarak teslim edilir. Rastgele demo ile gerçek veri entegrasyonunu ikame etme gereği doğmadı.

## Son kullanıcı arayüzü kontrolü

Yerel Godot penceresinde Başlat, mod açılır listesi, Ayarlar, Kaydet, Sıfırla, TAB paneli, F el feneri, WASD tuşları, ESC duraklatma ve menüden çıkış denendi. Ayarlar açıkken açıklama metninin düğmelerle üst üste gelmesi giderildi; fare hassasiyeti artık dört ondalıkla gösteriliyor. Rastgele modda gerçek sinir ölçümü ve pause/kayıt onayları sunucu günlüğünde doğrulandı. Bu kısa UI kontrolü, otomatik fizik rotasıyla birlikte değerlendirilmeli; uzun insan oynanış/korku testi değildir. [UI kontrol kaydı](manual-ui-check.json).
