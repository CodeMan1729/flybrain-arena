# Kritik oyun/sinek düzeltmeleri — 10 Eylül 2026

- Sineğin arama dönüşünün belirli sinir çıktılarında sıfırlanması giderildi.
- Beyin bağlantısı/güncel veri kaybolduğunda eski hızla sürüklenme durduruldu.
- Kısa fare dönüşlerinin 10 Hz tepki örneklemesinde kaybolması, 120 ms zamanlı pencereyle giderildi; eski hareket yeni tura taşınmıyor.
- Anahtar/kapı etkileşimine aradaki katı engel kontrolü eklendi.
- Normal oyunda pencere odağı kaybolursa oyuncu, sinek ve olay kararları duraklıyor; kullanıcı devam ettiriyor.

Önce hatalar [regresyon testinde](before.log) yeniden üretildi. Sonra [8 odaklı kontrol](after.log), [9 Python testi ve 35 adımlı gerçek oyun turu](full-tests.log) geçti. Son görünür 1920×1080 tur: **115.23 FPS**, p99 **13.360 ms**, **35 kontrol geçti**. [Görünür ölçüm](game-learn-benchmark.json), [bellek izi](runtime-learn.json).

Sinir modeli, bağlantı haritası ve öğrenme algoritması değiştirilmedi; mevcut öğrenme dosyaları sıfırlanmadı. Yeni öğrenme başarısı deneyi yapılmadı. Önceki v2 performans tablosu o sürümün tarihsel ölçümüdür; bu bakımın ölçümü yukarıdadır.

Çalıştırma: proje kökünde `./test.sh`. Hızlı regresyon: `./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/gameplay.gd`.
