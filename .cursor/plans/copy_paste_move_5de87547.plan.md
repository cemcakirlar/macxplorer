---
name: Copy Paste Move
overview: Command-C dosyayı kopyalar, Command-V açık klasöre kopyasını yazar, Option-Command-V taşır. Aynı adda Finder’ın Stop, Keep Both ve Replace seçenekleri çıkar. Replace, eskisini sessizce silmez.
todos:
  - id: transfer-names
    content: Keep Both adı ve Stop, Keep Both, Replace kararı; disk yazmayan testler
    status: completed
  - id: transfer-write
    content: "FileTransfer: kopya, aynı disk taşıma, çapraz diskte kopyadan sonra Çöp, Replace için trashItem"
    status: completed
  - id: transfer-ui
    content: Command-C, Command-V, Option-Command-V, çakışma uyarısı ve undo
    status: completed
isProject: false
---

# Copy, Paste, Move Item Here

Bu dilim panodan kopyalama ve taşıma. Sürükle-bırak ve New Folder yazılmaz. Command-X yok.

## Finder davranışı

Command-C, odaktaki listenin veya yan çubuğun seçimini dosya URL’si olarak panoya yazar. Seçim boşken açık klasör kopyalanmaz. Option-Command-C bugünkü yol kopyası olarak kalır; [PathClipboard.swift](Macxplorer/Services/PathClipboard.swift) metin yazmaya devam eder.

Command-V, panodaki dosyaları açık klasöre kopyalar. Kaynak yerinde kalır. Option-Command-V aynı yere taşır. Hedef, seçili alt klasör değil, açık klasördür. Panoda dosya URL’si yoksa yapıştır kapalıdır.

Aynı ad varsa tek uyarı, üç düğme:

- **Stop.** O öğe ve listedekilerin gerisi yazılmaz. Bu işlemde daha önce yazılanlar durur.
- **Keep Both.** Var olan durur. Yeni ad Finder’ın İngilizce kuralıdır: `Notlar.txt` için `Notlar copy.txt`, o da doluysa `Notlar copy 2.txt`. Uzantı son parçadır (`file.tar.gz` içinde `file.tar copy.gz`).
- **Replace.** Varsayılan düğme değildir. Var olan öğe `trashItem` ile Çöp’e gider, sonra yeni öğe o adı alır. Çöp’e gitmezse yeni öğe yazılmaz ve var olan durur.

Return, Keep Both’u seçer.

Aynı diskte taşıma `moveItem` ile tek öğedir. Başka diske taşıma önce kopyalar; kopya yerindeyse kaynak Çöp’e gider. Kopya tamamlanmazsa kaynak durur.

Undo, kopyaları Çöp’e taşır. Taşınan öğeyi eski yerine koyar; o ad doluysa üzerine yazmaz.

## Yazma

Tek servis `FileTransfer`. Sürükle-bırak da bunu çağırır; ikinci bir yazıcı yoktur.

Saf fonksiyonlar: Keep Both adı ve Stop / Keep Both / Replace kararı. Disk yazmayan testler.

Kopya ve taşıma `NSFileCoordinator` kullanır. `removeItem` yok.

## Nereye bağlanır

- [MacxplorerApp.swift](Macxplorer/MacxplorerApp.swift): **Copy**, **Paste**, **Move Item Here**. Kısayollar Command-C, Command-V, Option-Command-V. Copy Path Option-Command-C olarak kalır.
- Uyarı: [ContentView.swift](Macxplorer/ContentView.swift) içindeki ortak uyarıya üç düğmeli çakışma uyarısı eklenir.
- Odaktaki liste ve yan çubuk, Copy için seçimi verir. Paste hedefi `model.selectedURL`.
