# FLYFEAR öğrenme v3 — 10 Eylül 2026

Bu sürüm üç korku olayının seçimini gerçek sinir etkinliği, oyun içi hareket tepkisi ve oyuncunun isteğe bağlı doğrudan değerlendirmesiyle kişiselleştirir. Öğrenilen parametreler yerelde kalır. Tam MaleCNS grafiği sabittir; ödül öğrenmesi dış karar katmanındadır.

## Değişiklik ve kök neden

Sekiz downstream sinir grubunu 0,2'ye bölüp kırpmak önceki sürümde bağlamı siliyordu. Eski 128 eğitim örneğinde iki kanal tamamen −1, diğerleri de çoğunlukla −1 idi. v3 sekiz grubun gerçek −1…1 etkinliğini korur, karar katmanında sabit merkezleme/kazanç uygular. Yeni 320 eğitim örneğinde her bağlam kanalı değişir; gerçek kenarlar silindiğinde 12 ham sinir ölçümü hâlâ sıfıra iner.

Küçük doğrusal UCB katmanı korunur; yeni bağımlılık veya büyük ağ eklenmedi. Ridge 0,1, %10 keşif, bütün eylemlerde 0,97 yaşlandırma kullanılır. Seçilmeyen eylemlerin de yaşlanması yeni tercihlerin yeniden denenmesini sağlar. Ön eğitim düşük ağırlıklı başlangıç katsayılarıdır; binlerce kişisel gözlem gücünde kilit oluşturmaz.

## Sen oynarken öğrenme

Uygulanan olaydan sonraki 8 saniyede **1 Etkilemedi / 2 Gerildim / 3 Korktum** tuşları 0 / 0,5 / 1 etiketini iletir. Değerlendirme hemen öğrenilir ve kaydedilir; öğrenme ağırlığı hareket vekilinin üç katıdır. Hareket puanı önceden öğrenilmişse o örnek düzeltilir, ikinci kez sayılmaz. Arada başka güncellemeler yapılmışsa düzeltmeye aynı yaşlandırma çarpanı uygulanır. Kimlik, süre, tür ve tekrar kontrolleri vardır.

Değerlendirme verilmezse eski 2 saniyelik hareket penceresi otomatik öğrenmeye devam eder. Hareket puanı korkunun kesin ölçümü değildir; doğrudan değerlendirme bu belirsizliği azaltmak için eklenmiştir. Bu teslimde gerçek insan korku etiketleri toplanmadı. Testte otomatik basılan tuşlar ayrı validation kayıtlarındadır.

Kişisel dosya `logs/sessions/learning-v3.json`, şema 3. Her ödül/düzeltme atomik kaydedilir. Eski `learning.json` korunur; uyumsuz eski katsayılar yeni sinir ölçeğinde kullanılmış gibi gösterilmez. Ana menü yapay ön eğitim ile kişisel hareket/değerlendirme sayılarını ayrı gösterir. Sıfırlama yedek alır, öğrenilen bilgiyi temizler ve temiz durumu kalıcılaştırır.

## Eğitim protokolü

- **48 yapay oyuncu × 12 tur = 576 tur; 8.640 ödüllü olay.** Her tur 60 karar, karar arası 3 simülasyon saniyesi. Kişiler sırayla çalışır; sonraki turda yeni girdi sırası ve etiket gürültüsü kullanılır.
- Oyuncuların farklı olay tercihleri, konum/bakış/hız bağlamı, 0,12 standart sapmalı etiket gürültüsü ve tekrarlandıkça azalan tepkileri vardır. Bunlar betikte açıkça tanımlanan yapay kurallardır.
- **320 eğitim + 160 geliştirme + 160 son doğrulama = 640 gerçek tam-graf sinir hesabı.** 166.700 nöron / 25.582.938 bağlantı. Sonraki politika kararları bu izleri yeniden kullanır; tam grafiğin tekrar tekrar hesaplandığı iddia edilmez.
- 24 geliştirme kişisinden sonra, son değerlendirmede **ayrı 24 kişi (28000–28023) ve ayrı sinir girdileri (202612)** kullanıldı. Son kişi verileri genel ön eğitime eklenmedi.
- Her yeni kişi için 12 tur / 180 olay kişiselleşme. Sonra tercih vektörü değiştirilir; 6 tur / 90 olay uyum sınanır. Öğrenciler yalnızca seçtikleri olayın gürültülü etiketini görür.
- Her dondurulmuş değerlendirme 360 karar / **90 olay**. Tüm koşullar aynı 5/60 saniye, 8 saniye genel, 16 saniye tekrar sınırını kullanır. Değerlendirme ağırlıkları değişmez, keşif kapalıdır.

Sinir hesaplarının bağlantı SHA256'sı: `8ad2164f2ba44b8be7dc0ce7a1be70890f963b6c84ae272f4cb84e1b04ba8d48`. Koleksiyon sırasında bağlantı ağırlıkları değişmedi. Kaynak hash'leri [sonuç dosyasında](confirmation-summary.json), her gerçek sinir örneği [iz dosyasında](traces.json).

## Son bağımsız doğrulama

Değerler **yapay beklenen tepki puanı**; insan korku seviyesi değildir. Eğitim gürültülü etiketlerle, değerlendirme simülatörün beklenen tepkisiyle yapılır.

| Koşul | Ortalama yapay tepki |
|---|---:|
| Kişisel eğitimsiz v3 | 0.2662 |
| Yalnızca yapay ön eğitim | 0.3200 |
| Rastgele kontrol | 0.2675 |
| Sabit sinir politikası | 0.2722 |
| Kişiselleşmiş eski v2 | 0.3690 |
| Kişiselleşmiş v3, ön eğitimli | 0.3693 |
| Kişiselleşmiş v3, ön eğitimsiz | 0.3697 |
| Sıfır ödül kontrolü | 0.2662 |
| Karıştırılmış ödül kontrolü | 0.2683 |

Kişiselleşmiş v3 rastgele kontrolü **38.0%** geçti; eşleştirilmiş fark `0.1018`, bootstrap aralığı `[0.09359750311589386, 0.10938070547211474]`. Fark 24 kişinin tamamında pozitiftir. Ön eğitim tek başına soğuk başlangıcın ortalama **20.2%** üstündedir; 24 kişiden 15'inde daha iyidir, her kişiye fayda garantisi yoktur.

**Sabit tercihlerde v2 ile v3'ün son başarımı birbirine yakındır.** Fark `0.0003` ve aralık sıfırı içerir; burada belirgin v3 üstünlüğü gösterilmedi. Ödülsüz ve karıştırılmış etiket koşulları kişisel öğrenme kazanımını üretmez.

| Tercih değiştikten sonraki koşul | Ortalama yapay tepki |
|---|---:|
| v3, eski bilgiyle yeni tercih | 0.2368 |
| v2, 90 yeni olaydan sonra | 0.3380 |
| v3, 90 yeni olaydan sonra | 0.3708 |
| v3, diske yazılıp yeniden yüklendi | 0.3708 |
| v3, bellek sıfırlandı | 0.2464 |
| v3, sinir özellikleri kapatıldı | 0.2915 |

Yeni tercihe uyumdan sonra v3 eski v2'nin **9.7%** üstündedir. Eşleştirilmiş fark `0.0328`, aralık `[0.02016459575293355, 0.04596953059627796]`; 24 kişinin 22'sinde pozitiftir. Yeniden yükleme sonucu aynen korur. Sıfırlama ve sinir özelliği ablasyonu başarımı azaltır; bias ve önceki tercih bilgisi nedeniyle ablasyonun sonucu sıfır olmak zorunda değildir.

Aralıklar 24 üretilmiş kişilik arasında bootstrap ile hesaplandı; gerçek insan popülasyonuna ait güven aralığı değildir. [Geliştirme sonucu](summary.json) ve daha erken [pilot](pilot/summary.json) de korunur. [Tur eğrisi ham örneklerinde](confirmation-curves.jsonl) alışma, ham eğitim puanını zamanla düşürebilir; bu yüzden kazanım dondurulmuş eş koşullarda değerlendirilir.

## Oyuna aktarılan dosya

[Ön eğitim katsayıları](../../data/learning-prior.json), 48 eğitim kişisinin genel modelidir. Son doğrulama kişilerine özel katsayılar oyuna aktarılmadı. Başlatıcı kişisel v3 dosyası yoksa bu ön bilgiyi yükler. Kişisel sayaç 0, yapay başlangıç sayacı 8.640 olur. Yeni gerçek ödüller ve değerlendirmeler bu başlangıcı değiştirebilir.

Aktarım öncesi rastgeleye göre öğrenme, değişen tercihte eski modele göre kazanım, yeniden yükleme eşitliği, ödül kontrolleri, eş olay sayıları ve kaynak hash'leri doğrulandı. Kullanıcının eski kayıtları üzerine yazılmadı.

## Doğrulama ve yeniden çalıştırma

`./test.sh`: **10/10 Python/yerel sunucu testi**, **20/20 Godot ses/oynanış kontrolü** ve tam beyinle baştan sona **35/35 oyun kontrolü** geçti. [Tam test çıktısı](full-tests.log).

Yeni testler kanal doyumunu, erken/geç değerlendirmeyi, çift saymayan ağırlık düzeltmesini, aradaki yaşlandırmayı, geçersiz/tekrar kimlikleri, kalıcı kaynak sayaçlarını ve ön eğitim/kişisel sayaç ayrımını kapsar. Gerçek **InputEventKey → üretim Godot istemcisi → localhost WebSocket → beyin katmanı → kaydedilmiş tek değerlendirme** yolu da sınandı. Görünür çalıştırma: [günlük](rendered-feedback.log), [değerlendirme öncesi](feedback-open.png), [değerlendirme alındıktan sonra](feedback-accepted.png).

```sh
.venv/bin/python tools/train.py --collect
.venv/bin/python tools/train.py
.venv/bin/python tools/train.py --collect --confirm
.venv/bin/python tools/train.py --confirm
```

Aday `reports/learning-v3/candidate-prior.json` içine yazılır; araç kişisel dosyaya veya oyunun ön eğitimine otomatik dokunmaz. Sürümler, ham sonuçlar, tohumlar ve kaynak hash'leri birlikte saklanır.

## Sınırlar

Simülatör önceden tanımlanmış tercih/bağlam/alışma kurallarını kullanır. Sinir izleri tekrar kullanıldığı için uçuşun veya beynin tüm tarihinin etkileşimli yeniden simülasyonu değildir. Farklı bir insan, farklı tepki biçimi, gerçek uzun dönem alışma ve genel korkutma başarısı burada ölçülmedi. Öğrenilen şey üç olayın tercihidir; biyolojik sinaps plastisitesi, öğrenilmiş uçuş veya öğrenilmiş olay zamanlaması değildir. Senin için kişiselleşme ancak oyun sırasında alınan gerçek tepki ve değerlendirmelerle gerçekleşir.
