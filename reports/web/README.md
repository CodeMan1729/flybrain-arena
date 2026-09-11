# Web yayını doğrulaması — 10 Eylül 2026

[FLYFEAR'ı oyna](https://furkancakir.dev/flyfear/).

Mevcut Godot 4.5.2 oyunu HTTPS sayfasında açıldı; 166.700 nöronluk tam
MaleCNS ağı sunucuda çalıştı. Normal masaüstü ve web oyunları öğrenen
karar katmanına zorunlu olarak bağlanır. Kontrol modları araştırma testlerine ayrıldı.

## Kontroller

- **12 Python/sunucu testi:** gerçek veri, üretim istemcisinin zaman aşımı,
  yerel iletişim ve iki eşzamanlı public istemci geçti.
- **17 ayar, 112 ses/oynanış/anahtar, 24 beyin görünümü ve 48 tam tur
  kontrolü** geçti. Son ayar testi eski sabit mod tercihinin normal oyunu
  öğrenmeden çıkaramadığını da doğrular. Testler kişisel kayıtlardan ayrıdır.
- [Tam tur kontrol listesi](game-checks.json): gerçek fizik rotası,
  anahtar alma, kilitli çıkış, nöron görünümü ve kesinti/devam.
- WebGL oyunu canlı adreste açıldı. Tarayıcı klavye olaylarıyla ileri
  hareketin oyun telemetrisinde **3,2 birim/sn** ürettiği ve oyuncunun
  koridora ilerleyip katı duvarda durduğu görüldü. ESC menüsü ve devam çalıştı.
- Canlı WSS yanıtlarında **4.096 gerçek nöron örneği** alındı. Işık,
  ses ve siluet kararları; hareket ödülleri ve doğrudan `3` değerlendirmesi
  sunucu belleğine ulaştı. Web denemesi için kamera/mikrofon açılmadı.
- Canlı hizmet yeniden başlatıldı: **9 öğrenme örneği** korunurken
  model dosyasının baytları değişmedi. Yeniden bağlantı ve yeni web
  oturumu aynı ortak öğrenmeyi görür. Otomatik public testinde bu durum
  iki istemcinin doğrudan değerlendirmeleriyle de doğrulanır.
- Sağlık yolu HTTPS 200 döndürdü; ana sitenin HTTP 200 yanıtı korundu.
  COOP/COEP, WASM MIME ve kamera/mikrofon/konum izin kısıtları kontrol edildi.
  Deneme hizmeti kapatıldı; kalıcı hizmet otomatik başlatmaya alındı.

[Semgrep güvenlik taraması](semgrep.log): 17 dosyada 200 kural, **0 bulgu**. Paylaşılacak dosyalarda özel sunucu adresleri, SSH anahtarları ve yerel kişisel kayıtlar bulunmadığı kontrol edildi.

## Ölçümün kapsamı

Tarayıcıda görülen anlık kare hızı yaklaşık **119–120 FPS**; tek oyunculu
sinir hesabı yaklaşık **0,68–0,74 saniye**, gözlenen tam istek/yanıt
yaklaşık **0,78–0,82 saniye** oldu. Bunlar bu test makinesi ve bağlantısının
anlık gözlemleridir; 1920×1080 çizim yüzeyi 1280×720 tarayıcı görünümünde izlendi; bütün cihazlar veya sekiz oyuncu için garanti değildir.
Sekiz bağlı oyuncu sınırı yapılandırılmıştır; eşzamanlı durum/öğrenme
doğrulaması iki istemciyle yapılmıştır.

Web üzerinde Godot heap sayacı sıfır döndürdüğü için bunu gerçek bellek
ölçümü gibi sunmak yerine “Web: ölçülmüyor” yazılır. Başlat/duraklat
menüsündeki açıklama alt kenara sığdırıldı. Ses mekanikleri yerel
karışım testleriyle doğrulandı; son web testlerinde kullanıcının isteğiyle
Mac'in sistem sesi kapalı tutuldu. Safari ve dokunmatik kontrol test edilmedi.

Öğrenme, gerçek bağlantılardan hesaplanan sinir çıktıları üzerindeki dış
karar katmanındadır. Her geçerli tepki bu modeli günceller; her güncellemenin
bir insanı daha fazla korkutacağı veya biyolojik öğrenme olduğu iddia edilmez.

Tarayıcı konsolunda Godot/Emscripten ana iş parçacığı uyarısı ve pointer-lock geçişlerinde Chromium `UnknownError` kayıtları görüldü. Bu oturumda açılış, hareket, ölçüm, duraklatma ve devam kontrollerini engellemediler; konsolun tamamen hatasız olduğu iddia edilmez.

![Yeniden bağlantıda korunan öğrenme ve son web menüsü](live-menu.png)


## Sekme görünürlüğü ve iptal edilen tepki — 11 Eylül 2026

Üretim web paketi, ayrı geçici öğrenme klasörü kullanan gerçek MaleCNS
sunucusuna localhost üzerinden bağlandı. Chrome'da görünürlük durumu
[DevTools odak emülasyonu](https://chromedevtools.github.io/devtools-protocol/tot/Emulation/#method-setFocusEmulationEnabled)
açılıp kapatılarak kontrollü değiştirildi; `document.hidden` ve
`document.visibilityState` değerleri doğrudan okundu. Mac kilitliydi;
fiziksel sekme tıklamasıyla insan kullanım denemesi yapılmadı.

- Uygulanan `steps` olayı için geri bildirim penceresi açıldıktan **18,04 ms**
  sonra gizlenen sayfa `pause` gönderdi. Bu tek denemenin ölçümüdür.
- Duraklama sonrasındaki **105,40 saniyelik** gözlemde yeni hareket,
  karar, uygulama veya ödül mesajı görülmedi. Hizmetin 90 saniyelik boş
  bağlantı sınırı bu gözlemin içinde kaldı; kesintisiz bağlantı iddiası yoktur.
- Görünürlük geri geldiğinde menü **DURAKLATILDI / DEVAM ET** olarak kaldı.
  Kullanıcı işlemiyle yeniden bağlantı kurulunca tur `paused: true` ile
  açıldı; ayrıca DEVAM ET'e basıldıktan sonra karar akışı başladı.
- İptal edilen olay ödül almadı. İzole denemenin sayacı **7 → 7** kaldı;
  model dosyasının baytları değişmedi. Bu sayılar test oturumuna aittir.
- Hata yeniden üretilemedi; oyun ve sunucu üretim kodu değiştirilmedi.

`tests/test_public.py` içindeki mevcut gerçek sunucu testine şu regresyon
kontrolü eklendi: uygulanmış olay → duraklatma → dururken kararın reddi →
dururken ve devamdan hemen sonra eski değerlendirmenin reddi → 23 yeni
hareket örneğinde eski pencereye ödül yazılmaması → model dosyasının korunması.
Bu test, ortak öğrenme ve yeniden başlatma kontrolleriyle birlikte geçti.
Mevcut **112 oynanış kontrolü** de geçti. Semgrep: 43 hedefte 131 kural,
**0 bulgu**, hata veya uyarı yok.

```sh
.venv/bin/python -m unittest tests.test_public -v
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/gameplay.gd
```

[Ölçüm özeti ve test edilen paket SHA256'sı](visibility-check.json).
Kişisel ayarlar ve canlı ortak bellek kullanılmadı. Test sekmeleri ve geçici
sunucu kapatıldı. Web yayınına dosya yüklenmedi.

![Görünürlük testinden sonra açık devam bekleyen izole oyun](paused-after-visibility.png)


## Yeniden bağlantı menüsü düzeltmesi — 11 Eylül 2026

Bağlantı yokken BAŞLAT veya DEVAM ET'e basılması menü başlığını kalıcı
bir bağlantı mesajıyla değiştiriyordu. Beyin hazır olunca alt durum satırı
güncelleniyor, üstte ise eski “Beyne bağlanılıyor… Hazır olunca Başlat'a bas”
yazısı kalıyordu. Duraklatılmış turda düğme DEVAM ET olduğu için yönlendirme
de yanlıştı.

Başlık artık mevcut 10 Hz arayüz güncellemesinde oyun durumundan üretilir:
ilk açılışta anahtar arama hedefi, duraklamada DURAKLATILDI, bitişte çıkış
sonucu. Bağlantının güncel durumu mevcut alt satırda ve öğrenme alanında
kalır. Başlığı farklı yerlerden değiştiren beş atama kaldırıldı.
Bağlanma, başlatma ve devam etme koşulları değişmedi.

- Mevcut HUD testine üç oyun durumu × iki bağlantı durumu kontrolü eklendi.
  Tanısal eski başlık, güncel durum gösterilmeden önce bilerek yerleştirilir.
  Kontrol eski kodda başarısız oldu; düzeltmeden sonra geçti. Başlık,
  bağlantı durum satırı ve oyunun kendiliğinden başlamaması birlikte sınanır.
- **3 HUD, 17 ayar ve 112 oynanış kontrolü** geçti. Ayar testinin beklenen
  bozuk dosya/yedekleme kayıtları dışında script hatası veya uyarı yoktu.
- Yeni web paketi, ayrı öğrenme klasörlü gerçek yerel beyinle Chrome'da
  sınandı. İlk açılışta beyin durduruldu, BAŞLAT denendi, beyin açıldı:
  hedef başlığı korundu ve oyun başlamadı. Gerçek tur duraklatılıp bağlantı
  tekrar kesildi; DEVAM ET denendi ve beyin açıldı. Başlık DURAKLATILDI,
  düğme DEVAM ET, alt satır “Gerçek bağlantı verisi hazır” olarak kaldı.
- Yeniden bağlantı mesajında `paused: true` görüldü. Kontrol boyunca
  otomatik `resume`, karar, uygulama veya ödül mesajı oluşmadı. İzole
  öğrenme sayacı sıfır kaldı. Kişisel ve canlı ortak bellek test edilmedi.
- Semgrep: 43 hedefte 131 kural, **0 bulgu**, hata veya uyarı yok.

Web dışa aktarımı tamamlandı ve yalnızca statik dosyalar yayımlandı.
Beyin hizmetinin süreç kimliği değişmedi. HTTPS'den alınan paket ile
sınanan yerel paketin SHA256'sı aynı:
`7d65c04a78e8a186c2c85c6a3410e08e448ec78579e8a69fcd446676f3dca32f`.
Canlı açılış menüsü, oyun başlatılmadan doğrulandı. Geçici test süreçleri
ve sekmeler kapatıldı.

![Yerel testte yeniden bağlanmış ve açık devam bekleyen menü](reconnected-menu.png)


## Web ayarlarının kalıcılığı — 11 Eylül 2026

Değiştirilmemiş üretim web paketi, ayrı localhost origininde gerçek MaleCNS
sunucusuna bağlandı. Öğrenme için geçici klasör kullanıldı. Ses **0**, efekt
yoğunluğu **0**, fare hassasiyeti **0,0016** olarak menüden kaydedildi.
Sayfa yenilendikten sonra aynı değerler hem menüde hem tarayıcının IndexedDB
ayar dosyasında doğrulandı.

- Yenileme sonrası **170,59 saniyelik** gerçek turda beyin 2 ışık, 2 ses ve
  52 siluet olayı seçti. İstemci 56 olayın tamamına `accepted: false` yanıtı
  verdi. Ödül oluşmadı; turdan sonra yeni bağlantıyla okunan öğrenme sayacı
  **0** kaldı. Bu, sıfır yoğunluğun yeniden açılan oyuna uygulandığını doğrular.
- Mevcut ayar testine kayıtlı fare hassasiyeti için bir kontrol eklendi:
  üretim girdi işleyicisine verilen 100 × 50 piksellik hareket, yatayda
  −0,16 ve dikeyde −0,08 radyan dönüş üretti. **18 grafik Godot kontrolü**
  geçti. **17 headless kontrolü** de geçti; headless ekran fareyi
  yakalayamadığından bu ilave girdi kontrolü orada açıkça atlanır.
- Aynı test, yeniden açılışta ana ses kanalının çalma öncesinde sessize
  alındığını doğruladı. Bozuk dosya/yedekleme testlerinin iki beklenen hata
  kaydı dışında script hatası veya uyarı yoktu.
- Mac kilitli olduğundan Chrome pointer lock isteğini reddetti. Tarayıcıda
  fiziksel fare dönüşü sınanamadı; Godot kontrolü verilen bir girdi olayıyla
  yapıldı. Sistem sesi kapalı kaldı; bu turda dinleme veya tarayıcı ses
  örneği ölçümü yapılmadı.
- Hata yeniden üretilemedi; üretim kodu ve web yayını değiştirilmedi.
  Kişisel ayarlar ve canlı ortak öğrenme kullanılmadı. Test sekmesi ve
  geçici sunucu kapatıldı.

Semgrep'in üretim/test kapsamı (`brain`, Python araçları/testleri, `game`,
`web`) 44 hedefte 216 kuralla tamamlandı: **0 bulgu**, hata veya uyarı yok.
GDScript mantığını yukarıdaki Godot kontrolleri sınar. Ayrıca tüm depo
tarandığında arşivlenmiş DOOMFLY kaynağı `research/build_kernel.py:13` için
bir subprocess uyarısı çıktı. Çağrı incelendi: sabit `clang++` komutu argüman
listesiyle ve varsayılan `shell=False` ile çalışır; kullanıcı çıktıyı bir dosya
yolu olarak seçer. Kabuk komutu birleştirilmediğinden bu çağrıda belirtilen
kabuk enjeksiyonu yolu doğrulanmadı. Araştırma kopyası oyun çalışma yolunda
kullanılmaz; değiştirilmedi. Bütün depo için sıfır bulgu iddiası yoktur.

```sh
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/settings.gd
./tools/Godot.app/Contents/MacOS/Godot --path game --audio-driver Dummy --script ../tests/settings.gd
```

[Ölçüm özeti ve paket SHA256'sı](settings-check.json).

![Yenilemeden sonraki gerçek turda korunan web ayarları](settings-after-reload.png)


## Tarayıcı ses çıkışı — 11 Eylül 2026

Üretim menüsünün ortam sesi, ayrı localhost origininde ve geçici gerçek
MaleCNS sunucusuyla ölçüldü. Oyun turu başlatılmadı; sunucu yalnızca ilk
bağlantı bilgilerini gönderdi, tur ve öğrenme sayıları sıfır kaldı.

Geçici test HTML'ine, Godot yüklenmeden önce bir ölçüm betiği eklendi.
`AudioDestinationNode` hedefine bağlanan `GainNode` ve `AudioWorkletNode`
çıkışlarının her birine ek bir
[AnalyserNode ölçüm dalı](https://developer.mozilla.org/en-US/docs/Web/API/AnalyserNode)
bağlandı; özgün ses bağlantıları korundu. Oyun paketi, WASM ve Godot
JavaScript dosyası değiştirilmedi. Her aşamada çıkış başına 40 pencere ×
2.048 mono örnek alındı; örnekleme hızı 48 kHz, pencere aralığı yaklaşık
50 ms, gözlem süresi yaklaşık 2,04 saniyeydi. Bu, sürekli stereo kayıt değildir.

| Menü ses düzeyi | Ortam sesinin RMS değeri | Tepe değer | Diğer çıkış RMS |
| --- | ---: | ---: | ---: |
| 0,45 | 0,005007 | 0,008601 | 0 |
| 0 | 0 | 0 | 0 |
| Yeniden 0,45 | 0,004381 | 0,008093 | 0 |
| 0 kaydedilip sayfa yenilendi | 0 | 0 | 0 |

Tüm aşamalarda ses bağlamı `running` durumundaydı ve ses saati yaklaşık
2,04 saniye ilerledi. Böylece sıfır örneklerin askıya alınmış ses bağlamından
kaynaklanmadığı kontrol edildi. Sıfır düzeyindeki iki aşamada, iki çıkıştan
alınan örneklerin tamamı sıfırdı. Farklı anlarda alınan pozitif RMS değerleri
fiziksel ses yüksekliği ölçümü değildir.

[Ham sayısal ölçüm özeti ve paket SHA256'sı](audio-check.json).
Mac'in sistem sesi kapalı kaldı; dinleme, mikrofon veya kişisel ses kaydı
yapılmadı. Bu kontrol Chrome'daki menü ortam sesini kapsar; her konumsal
korku klibi veya başka tarayıcılar için aynı sonucu garanti etmez.

Üretim kodunda hata çıkmadı; değişiklik ve yeniden yayın gerekmedi.
Mevcut **112 ses/oynanış kontrolü** geçti. Semgrep'in üretim/test kapsamı
44 hedefte 216 kuralla tamamlandı: **0 bulgu**, hata veya uyarı yok.
Geçici test sekmesi ve sunucu kapatıldı.
