# FLYFEAR tamamlanan geliştirme hedefi

## Sürekli geliştirme

- Kullanıcı yayın sırası: her doğrulanmış güncellemede önce canlı siteyi
  güncelle ve doğrula, sonra GitHub'a pushla. Açık oyunları ve öğrenme
  kayıtlarını koru; yayımlanmayan değişikliği yayında diye bildirme.
  Web paketini tools/export_web.py ile üret; yeni yayın klasörüne mevcut
  statik dosyaları da taşı, eski sürümlü dosyaları silme. Yalnızca temiz
  tarayıcıyla yetinme; normal yenileme ve eski önbellekle açılışı doğrula.
- [x] %100 yüklemede takılma Chrome'da yeniden üretildi ve giderildi:
  önbellekteki eski iş parçacıklı JavaScript, yeni tek iş parçacıklı WASM
  ile karışıyordu. Motor/ses dosyaları ve oyun paketi içerik özetli
  adreslerle yayımlanıyor. Başlatma hataları yeniden deneme ekranına
  düşüyor; indirme bitince “Oyun açılıyor…” gösteriliyor. Aynı takılan
  canlı Chrome sekmesi önbelleği temizlenmeden normal yenilemeyle açıldı.
  Mobil Chrome emülasyonunda canlı menü ve ayrı yerel beyinde oyun
  başlangıcı geçti. 13 Python testi, altı JS yükleyici senaryosu ve
  Semgrep başarılı. Kanıt: reports/web/loading-cache-check.json.
- [x] Mobil web uyumluluğu tamamlandı. Kabul: dar/dikey ve
  yatay ekranda okunur, kaydırılabilir menü/ayarlar; eşzamanlı dokunmatik
  hareket ve bakış; etkileşim, fener, duraklat/devam ve değerlendirme
  düğmeleri; bırakma/iptal/odak kaybında takılı hareket olmaması; yön
  değişiminde taşma olmaması. Masaüstü kontrolleri ve kişisel kayıtlar
  korunur. Gerçek web paketi ayrı test beyniyle mobil tarayıcı emülasyonunda
  sınandı. 12 Python testi ve 189 Godot kontrolü geçti; bunun 27 kontrolü
  mobil girdiler/düzene ait. Dört ekran boyutu ve 3× piksel yoğunluğunda
  gerçek web paketi doğrulandı; fiziksel iOS/Android cihazı sınanmadı.
  Canlı yayın doğrulandı; beyin süreci, mevcut WSS ve öğrenme dosyaları
  korundu. Kanıt: reports/web/mobile-check.json. Önce yayın, sonra push.

- [x] Tarayıcıda oynanabilir Godot sürümü ve HTTPS/WSS yayını.
  Normal masaüstü/web oyunu her turda öğrenir; web ziyaretçileri ayrı
  sinir durumlarıyla ortak kalıcı karar katmanını günceller. İki istemci,
  yeniden başlatma, veri sınırları ve canlı oyun doğrulandı.
  Kanıt: reports/web/README.md. Kalıcı adres: https://furkancakir.dev/flyfear/.

- [x] Üç odada değişken anahtar araması: doğrulanmış yüzeylerden seçim,
  aynı tohumla tekrar üretim, ardışık tekrarı engelleme, devamda konumun
  korunması ve anahtarla birlikte taşınıp sönen ışık. Her konumdan gerçek
  fizik ile çıkışa ulaşma kontrolü: reports/KEY-SEARCH.md.

- [x] Genel performans optimizasyonu: ağ çizimini değişikliklerde yenile;
  HUD yazılarını 10 Hz güncelle; yalnızca gösterilecek anatomik kayıtları
  Python nesnelerine dönüştür; bağlantı derecesindeki büyük geçici kopyayı
  kaldır; sinir ölçümü JSON'unu küçült. Önce/sonra profil, tam durum
  eşitliği ve regresyon kontrolleri: reports/optimization/README.md.

- [x] Kullanıcı tercihi doğrultusunda görselliği öne alan yoğun, döndürülebilir
  beyin görünümü: 4.096 gerçek soma, 6.000 gerçek bağ, V ile büyük görünüm,
  yakınlaştırma, hücre grubu renkleri/filtreleri ve nöron seçimi. Küçük
  panelde dört ölçülmüş çıktı ve zaman grafiği. İlk çizimin FPS kaybı native
  MultiMesh/toplu çizgilerle giderildi. Kanıt: reports/brain-view/README.md.

- [x] Kullanıcının istediği harita genişletmesi: arşiv ve makine odası,
  iki odayı arkadan bağlayan servis koridoru, yeni mobilyalar ve yönlendirmeler.
  Anahtar arşivde; zafer alanı çıkış kapısının arkasına sınırlandı.
  Gerçek fizik rotası ve yeni geçit/duvar kontrolleri eklendi.
  Kanıt: reports/expanded-map/README.md.

- [x] Kullanıcının istediği korku sesi geliştirmesi: özgün nefes, gıcırtı ve
  tok vuruşlar mevcut işitsel olay ailesine eklendi. Art arda aynı klip yok;
  tohum klip/konum/tonu tekrar üretir. Bütçe, kazanç sınırı, sessizlik,
  duraklatma ve odak kaybı korundu. 11 Python, 15 ayar, 32 ses/oynanış ve
  35 tam tur kontrolü; ayrıca görünür ses testleri geçti. Kanıt:
  reports/scare-tests.log, reports/scare-audio-metrics.json ve ses önizlemesi.

- [x] Kalıcı oyuncu ayarları: ses, efekt yoğunluğu, fare hassasiyeti, karar
  aralığı, mod, tohum ve tam ekran tercihi yeniden açılışta korunuyor.
  Bozuk dosya yedeksiz ezilmiyor; başarısız yazma önceki kaydı koruyor;
  geçersiz değerler güvenli sınırlarda; otomatik testler kişisel ayarlardan
  izole. 10 Python testi + 15 ayar + 20 oynanış + 35 tam tur kontrolü geçti.
  Ayrı iki görünür süreçte tam ekran, sessizlik ve menü değerleri doğrulandı.
  Kanıt: reports/settings-tests.log ve reports/settings-fullscreen.png.
- [x] Kişisel oturumun kapanışında değişen reports/manual-run.log Git
  kapsamından çıkarıldı; dosya yerelde korundu.
- [x] TAB ölçüm panelinde sağ kenar taşması yeniden üretildi ve düzeltildi.
  Yerleşik satır kaydırma, bütün sayıları ve durum mesajını korur; bir boş
  satır kaldırılarak alt beyin görünümüyle çakışma önlendi. Başlangıçta
  562 px genişleyen panel artık 510 px sınırında. Headless, 1080p pencere
  ve oyunun tam ekran geçişinde metin/boyut/görünür satır kontrolleri geçti;
  112 oynanış ve 24 beyin görünümü kontrolü de geçti. Web dosyaları beyin
  hizmeti yeniden başlatılmadan güncellendi. Kanıt: reports/HUD-LAYOUT.md.
- [x] Öğrenme bilgileri henüz alınmamışken yanıltıcı sıfırlar kaldırıldı.
  Menü “Beyne bağlanılıyor” gösterir; gerçek sıfır geldiğinde sıfır görünür.
  Kesintide son sayılar korunur ve mevcut başlık boşluğuna “Son alınan
  kayıt” etiketi yerleşir; yeniden bağlantıda güncel sayılar gösterilir.
  Dört durumun geçişi mevcut tests/hud.gd üretim arayüzü kontrolüne eklendi
  ve geçti; panel yerleşimi ile 17 ayar kontrolü de geçti. Web paketi
  doğrulanarak öğrenme hizmeti yeniden başlatılmadan yayımlandı; canlı
  menüdeki sayılar sağlık özetine uydu. Semgrep: 200 kural, 0 bulgu.
- [x] Kayıtlı tam ekran tercihiyle doğrudan açılış iki bağımsız görünür
  Godot sürecinde doğrulandı. İlk süreç tercihi üretim yoluyla kaydetti;
  ikinci süreç dosyayı açılışta yükledi. Menü/HUD yazıları eksiksiz, sessiz
  ayar korunmuş ve dosya baytları değişmemişti. Hata yeniden üretilemedi;
  üretim kodu değiştirilmedi. Mevcut HUD testine isteğe bağlı iki süreçli
  kontrol eklendi: görünür 3+3, headless 2 ve mevcut 17 ayar kontrolü geçti.
  Kanıt: reports/HUD-LAYOUT.md ve reports/fullscreen-startup-menu.png.
- [x] Web görünürlük geçişi, gerçek üretim paketi ve ayrı yerel beyinle
  doğrulandı: açık tepki penceresinden 18,04 ms sonra pause; 105,40 sn
  yeni mesaj/ödül yok; görünürlükte menü duraklatılmış kaldı. Yeniden
  bağlantı paused:true ile açıldı, açık DEVAM ET kararı yeniden başlattı.
  Mac kilitli olduğundan Chrome görünürlüğü DevTools ile kontrol edildi;
  fiziksel sekme tıklaması sınanmadı. Eski olayın duraklama/devam sonrası
  öğrenilememesi mevcut public sunucu testine eklendi ve geçti; 112
  oynanış kontrolü de geçti. Üretim değişikliği gerekmedi. Kanıt:
  reports/web/README.md ve reports/web/visibility-check.json.
- [x] Yeniden bağlantıdaki eski/yanlış menü başlığı düzeltildi. Başlık tek
  yerde oyun durumundan üretiliyor; güncel bağlantı bilgisi mevcut durum
  satırında. Üç oyun durumu × iki bağlantı durumu için önce başarısız olan
  regresyon kontrolü geçti; toplam 3 HUD, 17 ayar ve 112 oynanış kontrolü
  başarılı. Gerçek yerel web/beyin ile ilk bağlantı ve duraklatılmış
  yeniden bağlantı sınandı; kendiliğinden başlama/öğrenme yok. Statik
  web paketi hizmet yeniden başlatılmadan yayımlandı; HTTPS hash eşleşti.
  Kanıt: reports/web/README.md ve reports/web/reconnected-menu.png.
- [x] Web ayarları aynı izole Chrome origininde yenilemeden sonra korundu:
  ses 0, yoğunluk 0, hassasiyet 0,0016; menü ve IndexedDB kaydı eşleşti.
  170,59 saniyelik gerçek turda 56 olay engellendi; ödül ve öğrenme yok.
  17 headless ve 18 grafik Godot ayar kontrolü geçti; yeni kontrol kayıtlı
  hassasiyetin iki eksende üretim girdisine uygulanmasını sınar. Mac kilitli
  olduğu için Chrome fare yakalaması ve fiziksel fare dönüşü sınanamadı.
  Üretim kodu değişmedi; kişisel ayarlar ve canlı ortak bellek kullanılmadı.
  Kanıt: reports/web/README.md ve reports/web/settings-check.json.
- [x] Web ses ayarı gerçek WebAudio örnekleriyle doğrulandı: 0,45 düzeyinde
  ortam sesi var; sıfırda iki çıkışın örnekleri sıfır; yeniden açınca ses
  geri geliyor, yenilemede sessizlik korunuyor. Her aşamada ses saati
  ilerledi; sıfır sonuç askıdaki bir tarayıcıdan alınmadı. Ayrı origin ve
  geçici gerçek beyin kullanıldı; tur/öğrenme başlatılmadı. Sistem sesi
  kapalı kaldı. Üretim kodu değişmedi. Kapsam: Chrome menü ortam sesi,
  çıkış başına 40 mono örnek penceresi; fiziksel dinleme veya tüm korku
  klipleri için web doğrulaması değildir. Kanıt: reports/web/audio-check.json.
- [x] Oyun sırasında kaybolan tuş bırakma olayı düzeltildi. Ortak duraklatma
  yolu W/A/S/D için bırakma girdisi üretir. Eski web paketinde W basımı →
  gizlenme → açık devam sonrası 2,99 birim istenmeyen yürüyüş görüldü;
  yeni pakette aynı konum sabit kaldı, yeni tuşla 3,2 birim/sn hareket sürdü.
  Eski kodda başarısız olan regresyon testi geçti; toplam 158 Godot kontrolü
  başarılı. DOM tuş olayı ve Chrome görünürlük emülasyonu kullanıldı;
  fiziksel klavye/sekme geçişi sınanmadı. Kişisel/ortak öğrenme kullanılmadı.
  Statik web paketi yayımlandı; HTTPS özeti eşleşti, beyin süreci değişmedi.
  Kanıt: reports/web/focus-input-check.json ve reports/web/README.md.
- [x] Menüde kaybolan tuş bırakma olayı ilk turda ve devamda yeniden üretildi
  ve düzeltildi. Tuş temizliği mevcut player.reset_motion() içine taşındı;
  devam yolu da aynı işlevi kullanır, olay tamponu hareket başlamadan
  boşalır. Web'de 2,72 / 3,09 birim istenmeyen hareket iki durumda da sıfır;
  yeni girdiler çalışıyor. Eski kodda iki regresyon başarısızken yeni kodda
  toplam 162 Godot kontrolü geçti. DOM girdisi/görünürlük emülasyonu
  kullanıldı; fiziksel klavye ve elle sekme değişimi sınanmadı. Statik
  paket yayımlandı; HTTPS özeti eşleşti, beyin süreci değişmedi. Kanıt:
  reports/web/focus-input-check.json içindeki menu_activation ve web raporu.
- [x] İki public istemciden biri gerçek sinir hesabının içinde koptuğunda
  kalan istemci 414,20 ms'de karar aldı (web sınırı 5 sn). Sinir çıktısı
  bağımsız referansla eşleşti; yeni bağlantı kabul edildi. Uygulanmadan
  kesilen karar ve onaydan sonra yarım kalan tepki penceresi ödül üretmedi;
  öğrenme dosyası bayt düzeyinde korundu. Mevcut public testine kontrollü
  matris bekletmesi eklendi; yalnızca testte tek hesaplama yuvasına düşürme
  aynı kontrolü beklendiği gibi zaman aşımına uğrattı. 12 Python testi ve
  son public tekrarı geçti; Semgrep 44 hedef/216 kural/0 bulgu. Üretim
  hatası bulunmadı; canlı hizmet ve kişisel bellek kullanılmadı. Kanıt:
  reports/web/README.md içindeki hesaplama sırasında kesinti bölümü.
- [x] Öğrenme dosyası yazılamadığında diskteki model korunuyor, fakat
  kaydedilemeyen değişiklik RAM'de kalıp tur kaydında 2 yerine 3 güncelleme
  gösteriyordu. Değişiklik ve kayıt tek yoldan yapılır; hata halinde aynı
  ortak karar nesnesi önceki durumuna döner. Ödül, düzeltme ve yerel
  sıfırlama bu yolu kullanır. Geçici dosya yolundaki gerçek yazma hatası
  eski kodda sayaç kontrolünü başarısız kıldı; yeni kodda 12 Python testi
  geçti. Başarılı ödül yanıtı yok, iki bağlantı kapanıyor, model baytları
  korunuyor ve yeniden başlatmada son geçerli model yükleniyor. Semgrep:
  44 hedef/216 kural/0 bulgu. Bağlı oyuncu yokken canlı hizmet güncellendi;
  ortak model/tur baytları değişmedi, HTTPS/WSS hazır, 11 öğrenme/2 tur
  korundu. Hata enjeksiyonu yalnızca geçici yerel kayıtlarda yapıldı.
  Kanıt: reports/web/README.md içindeki kayıt hatası bölümü.
- [ ] Sıradaki hedef: olay uygulama onayındaki istek kimliği türünü
  doğrula. Kabul: ayrı public testinde mantıksal veya ondalıklı kimlik
  geçerli tamsayı kimliğin yerine geçemez, olay bütçesi/tepki penceresi
  açmaz; doğru tamsayı onayı çalışır. Kişisel/canlı öğrenme kullanılmaz;
  yalnızca yeniden üretilen tür doğrulama hatasını düzelt.

## Önceki tamamlanan hedefler

- [x] Gerçek MaleCNS tam grafiği, yerel bağımsız Godot/Python akışı korundu.
- [x] Downstream sinir özellikleriyle ödüle duyarlı dış karar katmanı; eş bütçe ve dondurulmuş değerlendirme.
- [x] Sekiz tohum, ayrı eğitim/değerlendirme girdileri, ödülsüz/karıştırılmış ödül, retention/reset ve özellik ablasyonu.
- [x] Her geçerli ödülde atomik bellek; kalıcı tur geçmişi, yeni tur/yeniden bağlantıda devam.
- [x] Gerçek soma konumları ve ölçülmüş etkinlikle köşede açılıp kapanan beyin paneli.
- [x] Fiziksel uçan sinek: gövde/kanat, dünya çarpışması, oyuncu görüşü ve sinir çıktılı uçuş modülasyonu.
- [x] Kayıt koruması, duraklatılmış yeniden bağlantı, eksik ödül penceresi ve test zamanlaması düzeltmeleri.
- [x] Python/üretim istemci testleri, headless ve ayrı gerçek 1080p sabit/öğrenen turlar.
- [x] Güncel README ve olumlu/olumsuz bulguları ayıran performans raporu.

Kanıtlar: reports/PERFORMANCE.md. Öğrenme dış karar katmanındadır; biyolojik öğrenme iddiası yoktur.

## Öğrenme v3

- [x] Downstream sinir ölçeğindeki bilgi kaybını düzelt.
- [x] Tüm eylemleri yaşlandır; kişisel doğrudan değerlendirmeyi daha güçlü öğren.
- [x] Aynı olayın otomatik puanını, çift öğrenmeden düzelt; atomik kaydet.
- [x] 48 yapay oyuncu / 8.640 olayla ön eğitim; ayrı geliştirme ve son doğrulama.
- [x] Bağımsız doğrulama sonuçlarına göre ön eğitimi oyuna aktar.
- [x] Üretim istemcisi, tam tur, görünür geri bildirim ve güncel rapor.
