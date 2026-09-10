# FLYFEAR tamamlanan geliştirme hedefi

## Sürekli geliştirme

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
- [ ] Sıradaki hedef: beyin panelinde uzun metinlerin sağ kenardan taşmasını
  1080p ve tam ekranda doğrula, gerçek ölçümleri kaybetmeden düzelt; görüntü
  ve taşma kontrolüyle sınayıp yayımla.

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
