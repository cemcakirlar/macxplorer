---
name: New Folder
overview: Açık klasörde untitled folder oluşturur, ad doluysa bir sonrakini seçer, sonra mevcut satır içi Rename’i başlatır. Var olan bir öğenin üzerine yazmaz.
todos:
  - id: folder-name
    content: untitled folder adını seçen saf fonksiyon ve disk yazmayan testler
    status: completed
  - id: folder-write
    content: Koordineli createDirectory; çakışmada sonraki ad, üzerine yazmama testi
    status: completed
  - id: folder-ui
    content: Shift-Command-N, listeyi yenileme, Rename alanı ve Çöp ile undo
    status: completed
isProject: false
---

# New Folder

Bu dilim yalnızca yeni klasör. Copy, Paste ve sürükle-bırak yazılmaz.

## Finder davranışı

Shift-Command-N, açık klasöre yazar. Seçili öğenin içine yazmaz. Seçim boş olsa da açık klasör yeter. Açık klasör yoksa komut kapalıdır.

Ad:

- `untitled folder`
- O ad doluysa `untitled folder 2`, sonra `untitled folder 3`

Var olan dosya veya klasör durur. Oluşturma bitince liste yenilenir, yeni klasör seçilir ve [ContentView.swift](Macxplorer/ContentView.swift) içindeki `beginRename` açılır. Escape o anda adı `untitled folder` olarak bırakır; klasörü silmez.

Undo New Folder, o klasör hâlâ oluşturulan yoldaysa onu Çöp’e taşır (`trashItem`). Rename daha sonra ayrı bir undo kaydıdır. Yol değişmişse başka bir öğe çöpe gitmez.

## Yazma

Saf fonksiyon, kardeş adlardan ilk boş `untitled folder` adını seçer. Testler disk yazmaz.

Servis, üst klasörde `NSFileCoordinator` ile `createDirectory` çağırır. Ad çakışırsa bir sonraki ada geçer. `removeItem` yok.

## Nereye bağlanır

- Komut: [MacxplorerApp.swift](Macxplorer/MacxplorerApp.swift) içindeki Copy Path komutunun yanına **New Folder**, kısayol Shift-Command-N. Odak değeri Copy Path ile aynı kalıp. Global olarak açık klasör yokken kapalı.
- [BrowserModel.swift](Macxplorer/ViewModels/BrowserModel.swift) oluşturulan klasörü açar ve seçer. Rename alanı [ContentView.swift](Macxplorer/ContentView.swift) `beginRename` ile başlar.
