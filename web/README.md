# FLYFEAR web sürümü

Oyun: [furkancakir.dev/flyfear/](https://furkancakir.dev/flyfear/).
Godot oyunu WebGL 2 ile tarayıcıda çizilir. Tam MaleCNS ağı ve ortak öğrenen
karar katmanı Python hizmetinde çalışır. Yeni bir oyun motoru veya ücretli API yoktur.

Telefonda sol alanda hareket, sağ alanda bakış kontrol edilir; iki parmak aynı
anda kullanılabilir. Etkileşim, fener, duraklatma, beyin ve değerlendirme
düğmeleri ekrandadır. Menü ve ayarlar dikey kaydırılır; ekran çevrilince oyun
duraklar ve eski dokunmalar temizlenir. Masaüstü klavye/fare düzeni korunur.
Web paketi tek iş parçacıklı Godot şablonunu ve masaüstü/mobil doku biçimlerini
kullanır. Mobil çizim tamponu 1,5× piksel oranıyla sınırlandırılır; arayüz
CSS boyutunda kalır. [Mobil doğrulama](../reports/web/mobile-check.json)
tarayıcı emülasyonuna aittir; fiziksel iOS/Android performans ölçümü değildir.

## Derleme

macOS kurulumunu `./setup.sh` ile tamamladıktan sonra:

```sh
.venv/bin/python tools/export_web.py
```

Betik Godot 4.5.2 web şablonları eksikse resmi sürüm arşivini indirir,
depodaki SHA512 ile doğrular ve yalnızca web şablonlarını çıkarır.
İlk şablon arşivi yaklaşık 1,29 GB; oyuncuya gönderilen sıkıştırılmış oyun
yaklaşık 9 MiB'dir. `build/web/` yayımlanacak dosyaları içerir ve Git'e girmez.
Motorun JS/WASM/ses dosyaları aynı içerik özetini, PCK ayrı bir içerik
özetini dosya adında taşır. Böylece eski Chrome/CDN önbelleği yeni motorla
karışmaz; yalnızca oyun değişince motorun adresi korunur. Yeni yayın
klasörünü mevcut statik dosyalardan başlatıp bu çıktıyla güncelleyin ve
doğrulama sonrası `public` bağlantısını atomik değiştirin. Eski sürümlü
dosyaları açık yükleyiciler için koruyun; otomatik temizleme yapılmaz.
Yalnızca `index.html` dışa aktarmak yerine bu betiği kullanın.

## Sunucu kurulumu

`flyfear.service` ve `nginx-location.conf` kişisel altyapı bilgisi içermeyen
kurulum örnekleridir. Mevcut HTTPS sanal sunucusuna yalnızca oyun konumlarını ekleyin.
Nginx yapılandırmasını değiştirmeden önce yedekleyin, `nginx -t` başarılı
olmadan yeniden yüklemeyin.

Hizmet `flyfear` adlı yetkisiz sistem kullanıcısıyla çalışır. `/opt/flyfear/`
içinde Python 3.12 sanal ortamı, mevcut `requirements.txt` bağımlılıkları,
`brain/` ve aşağıdaki doğrulanmış çalışma verileri bulunmalıdır:

```text
data/weights.npz
data/ids.npy
data/annotations.feather
data/manifest.json
data/mapping.json
data/learning-prior.json
```

Kaynak veriler ve lisansları ana README'de açıklanır. Yerel `logs/`, kişisel
öğrenme dosyaları, SSH anahtarları veya sistem yapılandırmaları aktarılmaz.
`/opt/flyfear/public/`, doğrulanmış `build/web/` çıktısını gösterir.

Yalnızca hizmet kullanıcısının yazabildiği `/var/lib/flyfear/` oluşturun.
`/etc/flyfear.env` içinde kendi tam HTTPS origin'inizi belirtin:

```dotenv
FLYFEAR_PUBLIC_ORIGIN=https://oyun.example
```

Bu dosya deponun dışında tutulur. Arka uç sadece `127.0.0.1:8765` dinler;
internete yalnızca Nginx üzerinden HTTPS/WSS sunulur. Başlatma sırası:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now flyfear
sudo nginx -t
sudo systemctl reload nginx
```

`/flyfear/health` hazır olma durumunu, nöron sayısını ve toplam öğrenme
sayacını döndürür. Kişisel oyun geçmişi döndürmez. WebSocket yolu
`/flyfear/ws` ve aynı origin zorunludur. Oyun sayfasındaki COOP/COEP
başlıkları Godot iş parçacıkları ve 3B ses için gereklidir. Sağlık yolu
da WebSocket sunucusuna HTTP/1.1 ile bağlanmalıdır.

## Öğrenme, saklama ve sınırlar

- Normal web ve masaüstü oyunları her zaman öğrenir. Sabit/rastgele
  kontrol koşulları yalnızca yerel araştırma testlerinde açılır.
- Büyük bağlantı grafiği paylaşılır; her bağlantının 166.700 nöronluk
  durumu ve rastgele seçim akışı ayrıdır. Bütün geçerli ödüller ortak
  dış karar katmanına, aynı süreçte sırayla uygulanır.
- Model her geçerli ödülde geçici dosya + fsync + atomik yeniden adlandırma
  ile saklanır. Model dosyası bozuksa sessizce sıfırlanmaz. Yazma hatasında
  hizmet oyun kabulünü durdurur. Kalıcı klasör işletim sistemi yedeklerine
  dahil edilmelidir; aynı klasöre birden fazla yazıcı süreç çalıştırılmaz.
- Olay özellikleri, puan ve tur özeti yaklaşık 20 MB dönen günlükte tutulur.
  Ham hareket akışı, IP, tarayıcı kimliği veya istemcinin eklediği kimlik
  alanları günlüğe alınmaz. Ağ sağlayıcısının teknik işlemesi
  [veri kullanımında](privacy.html) ayrıca açıklanır.
- Oyuncular ortak belleği sıfırlayamaz veya başkalarının tur geçmişini
  göremez. Her bağlantıda mesaj boyutu/hızı, olay bütçesi ve karar aralığı
  sınırlıdır; boş bağlantı 90 saniye sonra kapanır.
- Başlangıç sınırı sekiz bağlı istemci, aynı anda iki sinir hesabıdır.
  Bu, sekiz aktif oyuncuyla doğrulanmış bir performans garantisi değildir.
  İki eşzamanlı oyuncunun durum ayrımı ve ortak kaydı test edilmiştir.
  Daha yüksek trafik için ölçüm ve merkezi tek model yazıcısını koruyan
  bir süreç düzeni gerekir.
- İnternet kesilince web oyunu duraklar. Geç kalan karar uygulanmaz;
  hazır olduğunda kullanıcı devam eder. Güncel masaüstü Chrome/Edge/Firefox
  ve WebGL 2 hedeflenir. Dokunmatik başlangıç Chrome mobil emülasyonunda
  doğrulandı; fiziksel iOS/Android cihazı ve Safari sınanmadı.

## Doğrulama

`./test.sh` tüm yerel testleri çalıştırır. `tests/test_public.py` gerçek
bağlantı verisiyle iki eşzamanlı sinir durumunu, ortak öğrenmeyi, yeniden
başlatmada kalıcılığı, origin ve kapasite sınırlarını, tekrar eden
değerlendirmeyi, kimlik alanlarının kayda sızmamasını ve mesaj hızını sınar.
[Yayın kontrol raporu](../reports/web/README.md).
Yükleyicinin altı başarı/hata/yeniden deneme kontrolü, kurulu Node ile
`node tests/web_loader.mjs` komutunda çalışır; ek paket gerekmez.
Sürüm değişimi ve eski dosyaların korunması normal Python testlerine dahildir.

Resmi kaynak: [Godot 4.5 web dışa aktarma](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html).
