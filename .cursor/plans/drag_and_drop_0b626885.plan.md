---
name: Drag and Drop
overview: Bırakılan öğe aynı diskte taşınır, başka diskte kopyalanır, Option basılıysa kopyalanır. Yazma kuralları Copy ve Paste ile aynı servistir. Geçersiz bırakma hiçbir şey yazmaz.
todos:
  - id: drop-decision
    content: "Bırakma kararı: disk, Option, dosya satırı, kendi altı; disk yazmayan testler"
    status: completed
  - id: drop-write
    content: FileTransfer üzerinden kopya ve taşıma; servis yoksa Copy planındaki kurallarla eklenir
    status: completed
  - id: drop-ui
    content: Liste ve yan çubuk bırakma hedefleri, çakışma uyarısı ve undo
    status: completed
isProject: false
---

# Sürükle-bırak

Bu dilim yalnızca sürükleme. Copy ve Paste komutları burada yazılmaz. Command-X ve alias yok.

## Finder davranışı

Option yokken aynı disk taşır, başka disk kopyalar. Option her zaman kopyalar. Option, bırakma anında `NSEvent.modifierFlags` ile okunur.

Bırakma yeri:

- Listenin boş yeri: açık klasör.
- Listedeki veya yan çubuktaki klasör satırı: o klasör.
- Dosya satırı: yazılmaz.
- Öğenin kendi üstü veya kendi alt klasörü: yazılmaz.

İçerik uygulama içinden veya Finder’dan dosya URL’si olarak gelebilir. Dışarı sürükleme, gerçek dosya URL’sini verir; Finder kendi kuralını uygular.

Aynı ad, kopya ve taşıma [Copy, Paste, Move Item Here planındaki](Macxplorer/Services/FileRename.swift) yazma kurallarıdır. Servis yoksa bu dilim onu ekler. Varsa ikinci bir yazıcı yazılmaz.

Kurallar:

- **Stop** kalanları da yazmaz.
- **Keep Both** `Notlar copy.txt`, sonra `Notlar copy 2.txt` kullanır.
- **Replace** eskisini `trashItem` ile Çöp’e koyar, sonra yeni öğe o adı alır. Çöp başarısızsa eski dosya durur.
- Aynı diskte taşıma `moveItem`. Başka diskte taşıma önce kopyalar; kopya duruyorsa kaynak Çöp’e gider.
- `removeItem` yok.

Undo, kopyayı Çöp’e taşır veya taşınan öğeyi eski yerine koyar. Eski ad doluysa üzerine yazmaz.

## Nereye bağlanır

- Liste: [FileListView.swift](Macxplorer/Views/FileListView.swift). Klasör satırı hedef olur, dosya satırı olmaz, boş alan açık klasördür.
- Yan çubuk: [SidebarTreeView.swift](Macxplorer/Views/SidebarTreeView.swift). Klasör ve mevcut favori hedef olur. Kayıp favori olmaz.
- Karar saf fonksiyondadır: hedef klasör, aynı disk mi, Option var mı, bırakılan yol hedefin kendisi veya altı mı. Disk yazmayan testler bu kararı kilitler.
- Çakışma uyarısı [ContentView.swift](Macxplorer/ContentView.swift) içindeki üç düğmeli uyarıdır. Keep Both varsayılandır.
