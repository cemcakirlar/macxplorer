---
name: Review findings fix
overview: v1.4.0 incelemesindeki yazma hatalarını önce testle kilitle, sonra imleç, aynı öğe kararı ve sağ tık menüsünü spec’e çek. ContentView’daki yazma akışı en sona kalır.
todos:
  - id: restore-error
    content: Replace geri koymasını try? olmadan yüzeye çıkar ve FileTransferTests ekle
    status: completed
  - id: case-rename
    content: Harf değişimini tek moveItem yap, geçici adı sil, testi güncelle
    status: completed
  - id: drop-cursor
    content: DropDecision imleci disk ve Option ile seçsin; dropUpdated panoyu okusun
    status: completed
  - id: same-item-paste
    content: Aynı öğe kopyası decision üzerinden geçsin; Replace kendisini çöpe atmasın
    status: completed
  - id: context-menu
    content: Sağ tıktan New Folder, Copy, Paste ve Move Item Here kaldır
    status: completed
  - id: extract-editing
    content: Yazma akışını ContentView dışına al; uyari metni ve undo kaydını tek yere indir
    status: completed
isProject: false
---

# Review bulgularını düzelt

Sıra sabit. Her dilim bir öncekinin testleri yeşilken başlar. Tahmini süre: yazma hataları yaklaşık 45 dakika, imleç ve menü yaklaşık 30 dakika, ContentView ayrımı bir öğleden sonra.

## 1. Replace sonrası geri koyma

[`Macxplorer/Services/FileTransfer.swift`](Macxplorer/Services/FileTransfer.swift) satır 151: kopya veya taşıma düşerse, Çöp’e giden eski öğe `try? operations.move` ile geri konuyor. Geri koyma da düşerse hata yutuluyor.

- `try?` kalksın. Geri koyma başarılıysa asıl yazma hatası fırlasın; eski dosya yerinde kalsın.
- Geri koyma düşerse `FileTransferError.occupantLeftInTrash(name)` fırlasın.
- [`ContentView.swift`](Macxplorer/ContentView.swift) `writeTransfer` bu hatayı “eski öğe Çöp’te kaldı” diye göstersin.
- [`FileTransferTests.swift`](MacxplorerTests/FileTransferTests.swift): iki test. Biri geri koymanın eski baytları yerine getirdiğini, biri geri koyma da düşünce hedefin değişmediğini ve hatanın `occupantLeftInTrash` olduğunu doğrular.

## 2. Harf değişiminde geçici ad yok

Spec: “Geçici ada taşıma yok.” [`FileRename.moveChangingCase`](Macxplorer/Services/FileRename.swift) `.macxplorer-rename-<uuid>` kullanıyor. İkinci geri alma da düşerse dosya gizli adla kalıyor.

- Büyük/küçük harf değişimi, mevcut `NSFileCoordinator` bloğunun içinde tek `moveItem` olsun: kaynak URL’den yeni ada.
- `moveChangingCase` silinsin.
- OS tek adımı reddederse dosya eski adında kalır ve uyarı çıkar. İkinci bir geçici ad yazılmaz.
- [`FileRenameTests.swift`](MacxplorerTests/FileRenameTests.swift): başarısız tek taşıma eski adı bırakır ve dizinde `.macxplorer-rename-` yoktur. Geçici klasörde `Report` → `report` canlı testi harfin değiştiğini doğrular.

## 3. Bırakma imleci yazmayla aynı olsun

[`FileDrop.swift`](Macxplorer/Views/FileDrop.swift) satır 18 Option yokken hep `.move` öneriyor. Yazma [`DropDecision`](Macxplorer/Models/DropDecision.swift) ile başka diskte kopyalıyor.

- `DropDecision` içine saf fonksiyon: dosya satırı ve kayıp favori `.forbidden`; Option veya başka disk `.copy`; aynı disk `.move`.
- `dropUpdated`, sürükleme panosundaki dosya URL’lerini senkron okur (`NSPasteboard(name: .drag)`) ve hedef klasörle `FileTransfer.Operations.live.sameVolume` karşılaştırır.
- Pano URL vermezse imleç Move demesin (`.copy`). Bırakınca yazma kuralı değişmez: `receiveDrop` bugünkü `DropDecision.item` ile kalır.
- Disk yazmayan testler bu üç imleci kilitler. Uygulamada kontrol: aynı diske bırakınca Move, başka diske bırakınca Copy.

## 4. Aynı klasöre yapıştırma Stop’u dinlesin

[`ContentView.swift`](Macxplorer/ContentView.swift) satır 704, öğe zaten hedefteyse uyarıyı atlayıp `name copy` yazıyor ve `choice` okumuyor.

- Aynı öğeyi taşıma: no-op kalsın.
- Aynı öğeyi kopyalama: `TransferNames.decision` üzerinden geçsin. Stop bu öğeyi ve sonrakileri yazmasın. Keep Both `name copy` yazsın.
- Replace, kaynak ile hedefin aynı dosyasıysa Çöp’e atmasın. `FileTransfer` yazmadan `sameItem` hatası versin; uyarı “bu öğenin yerine kendisi konamaz” desin.
- Karar [`TransferNames`](Macxplorer/Models/TransferNames.swift) veya yanındaki saf fonksiyonda testlensin. View’ın içindeki dal tek başına bu kuralı tutmasın.

## 5. Sağ tıkta fazla komutlar

Planlar New Folder, Copy, Paste ve Move Item Here’ı uygulama menüsüne bağlıyor. [`ItemContextMenu.swift`](Macxplorer/Views/ItemContextMenu.swift) satır 63 bunları bir de sağ tıkta sunuyor.

- Bu dört düğme ve `ItemActions` içindeki karşılıkları kalksın.
- [`MacxplorerApp.swift`](Macxplorer/MacxplorerApp.swift) menü komutları durur.
- [`FileListView.swift`](Macxplorer/Views/FileListView.swift) ve [`ContentView.swift`](Macxplorer/ContentView.swift) artık bu dört kapanışı menüye vermez.

## 6. ContentView yazma akışını bıraksın

1–5 yeşil olduktan sonra. Davranış değişmez; taşıma.

- Rename, çöp, yeni klasör ve transfer döngüsü [`ContentView.swift`](Macxplorer/ContentView.swift) içinden yeni bir türe gider (ör. `Macxplorer/Editing/FileEditing.swift`). View uyarıyı gösterir ve sonucu uygular.
- “Name already taken” cümleleri tek yerde kurulur. Dört undo relay’deki `registerUndo` + `Task { @MainActor }` ortak bir yardımcıya iner; redo verisi rename, çöp, klasör ve transfer için ayrı kalır.
- Hedef: `ContentView.swift` yaklaşık 500 satırın altında.

Doğrulama: `xcodebuild test` şeması Macxplorer. Sonra uygulamada üç tıklama: başka diske bırakınca Copy rozeti, aynı klasöre yapıştırınca üç düğme, Replace sonrası yazma düşünce eski dosyanın yerinde kaldığı bir birim testi.