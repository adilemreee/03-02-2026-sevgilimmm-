# Storage Rules Derinlemesine Analiz

Bu doküman, projedeki gerçek upload path'leri ve medya akışları incelenerek hazırlandı. Amaç, Storage tarafında hangi klasörlerin hangi kullanıcı tarafından, hangi boyut ve mime-type ile yazılması gerektiğini netleştirmek.

## İncelenen Kod Alanları

- `sevgilim/Services/StorageService.swift`
- `sevgilim/Services/MessageService.swift`
- `sevgilim/Services/StoryService.swift`
- `sevgilim/Services/SurpriseService.swift`
- `sevgilim/Services/SecretVaultService.swift`
- `sevgilim/firebase/storage.rules`

## Koddan Çıkan Gerçek Storage Path'leri

| Path | Kaynak Servis | Medya Tipi | Not |
|---|---|---|---|
| `profiles/{userId}/profile.jpg` | `StorageService.uploadProfileImage` | image | Profil resmi |
| `relationships/{relationshipId}/photos/{photoId}.jpg` | `StorageService.uploadPhoto` | image | Normal fotoğraf |
| `relationships/{relationshipId}/photos/videos/{mediaId}.{ext}` | `StorageService.uploadPhotoVideo` | video | Galeri videoları |
| `relationships/{relationshipId}/photos/{mediaId}_thumb.jpg` | `StorageService.uploadPhotoVideo` | image | Video thumbnail |
| `relationships/{relationshipId}/memories/{photoId}.jpg` | `StorageService.uploadMemoryPhoto` | image | Anı fotoğrafları |
| `relationships/{relationshipId}/messages/{uuid}.jpg` | `MessageService.sendMessageWithImage` | image | Sohbet görseli |
| `relationships/{relationshipId}/stories/{file}.jpg` | `StoryService.uploadStoryImage` | image | Story fotoğrafı |
| `relationships/{relationshipId}/stories/thumbnails/{file}.jpg` | `StoryService.uploadStoryThumbnail` | image | Story thumbnail |
| `relationships/{relationshipId}/stories/videos/{file}.{ext}` | `StoryService.uploadStoryVideo` | video | Story videosu |
| `relationships/{relationshipId}/secretVault/{mediaId}.jpg` | `StorageService.uploadSecretPhoto` | image | Gizli kasa görseli |
| `relationships/{relationshipId}/secretVault/{mediaId}.{ext}` | `StorageService.uploadSecretVideo` | video | Gizli kasa videosu |
| `relationships/{relationshipId}/secretVault/{mediaId}_thumb.jpg` | `StorageService.uploadSecretPhoto/uploadSecretVideo` | image | Gizli kasa thumbnail |
| `surprises/{relationshipId}/{uuid}.jpg` | `SurpriseService.uploadSurpriseImage` | image | Sürpriz görseli |

## Mevcut `storage.rules` Dosyasında Bulduğum Sorunlar

Mevcut rules dosyasında birkaç ciddi gevşeklik var:

1. `stories` path'leri için sadece `isSignedIn()` kontrolü var.
   Bu, giriş yapan herhangi bir kullanıcının başka bir ilişkinin story dosyalarına erişebilmesi anlamına gelir.

2. `surprises/{relationshipId}/{fileName}` için `allow read, write: if isSignedIn();` yazılmış.
   Bu en riskli kısım. Her login olan kullanıcı herhangi bir relationship altına sürpriz medyası yazabilir veya silebilir.

3. `profiles/{userId}` için read çok geniş (`allow read: if isSignedIn()`).
   Bu uygulamada partner profiline erişim gerekiyor ama tüm login kullanıcıların tüm profil medya yoluna erişmesine gerek yok.

4. Fotoğraf videoları ve thumbnail path'leri için ayrı boyut/mime-type doğrulaması eksik.

5. Storage path'leri ile Firestore üyelik ilişkisi her yerde aynı sertlikte uygulanmıyor.

## Tasarım İlkesi

Storage tarafında temel prensip şu olmalı:

- path relationship tabanlıysa, o `relationshipId`'ye ait kullanıcılar dışında kimse erişememeli
- path user tabanlıysa, sadece kullanıcı sahibi yazabilmeli
- mime-type ve boyut kontrolü rules içinde tekrar edilmeli
- istemci zaten sıkıştırma yapsa bile, server-side validation yine olmalı

## Önerilen `storage.rules`

```rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function signedIn() {
      return request.auth != null;
    }

    function uid() {
      return request.auth.uid;
    }

    function userExists(userId) {
      return firestore.exists(/databases/(default)/documents/users/$(userId));
    }

    function userDoc(userId) {
      return firestore.get(/databases/(default)/documents/users/$(userId));
    }

    function currentUserExists() {
      return signedIn() && userExists(uid());
    }

    function currentRelationshipId() {
      return currentUserExists() ? userDoc(uid()).data.relationshipId : null;
    }

    function isSelf(userId) {
      return signedIn() && uid() == userId;
    }

    function isRelationshipMember(relationshipId) {
      return currentUserExists()
        && currentRelationshipId() != null
        && currentRelationshipId() == relationshipId;
    }

    function sharesRelationshipWithUser(userId) {
      return currentUserExists()
        && userExists(userId)
        && currentRelationshipId() != null
        && userDoc(userId).data.relationshipId == currentRelationshipId();
    }

    function isDelete() {
      return request.resource == null;
    }

    function isImage() {
      return request.resource != null
        && request.resource.contentType.matches("image/.*");
    }

    function isVideo() {
      return request.resource != null
        && request.resource.contentType.matches("video/.*");
    }

    function withinBytes(limit) {
      return request.resource != null
        && request.resource.size <= limit;
    }

    match /profiles/{userId}/{fileName} {
      allow read: if isSelf(userId) || sharesRelationshipWithUser(userId);
      allow create, update: if isSelf(userId)
        && isImage()
        && withinBytes(10 * 1024 * 1024);
      allow delete: if isSelf(userId);
    }

    match /relationships/{relationshipId}/messages/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isImage()
        && withinBytes(10 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /relationships/{relationshipId}/memories/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isImage()
        && withinBytes(20 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /relationships/{relationshipId}/photos/videos/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isVideo()
        && withinBytes(100 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /relationships/{relationshipId}/photos/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isImage()
        && withinBytes(20 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /relationships/{relationshipId}/stories/videos/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isVideo()
        && withinBytes(50 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /relationships/{relationshipId}/stories/thumbnails/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isImage()
        && withinBytes(2 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /relationships/{relationshipId}/stories/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isImage()
        && withinBytes(10 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /relationships/{relationshipId}/secretVault/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && (
          (isImage() && withinBytes(50 * 1024 * 1024))
          || (isVideo() && withinBytes(50 * 1024 * 1024))
        );
      allow delete: if isRelationshipMember(relationshipId);
    }

    match /surprises/{relationshipId}/{fileName} {
      allow read: if isRelationshipMember(relationshipId);
      allow create, update: if isRelationshipMember(relationshipId)
        && isImage()
        && withinBytes(10 * 1024 * 1024);
      allow delete: if isRelationshipMember(relationshipId);
    }
  }
}
```

## Bu Rules Setinin Uygulamaya Göre Davranışı

### 1. Profil resimleri

Path:

```text
profiles/{userId}/profile.jpg
```

Davranış:

- sadece profil sahibi upload/update/delete yapabilir
- sadece kullanıcı kendisi veya mevcut partneri okuyabilir

Bu yaklaşım, partner profil resmini göstermeye devam eder ama tüm login kullanıcılar için açık bir profil medya alanı bırakmaz.

### 2. Mesaj görselleri

Path:

```text
relationships/{relationshipId}/messages/{uuid}.jpg
```

Davranış:

- sadece o relationship içindeki iki kullanıcı yazabilir/silebilir
- sadece image kabul edilir
- 10 MB üstü dosya engellenir

### 3. Fotoğraflar ve galeri videoları

Path'ler:

```text
relationships/{relationshipId}/photos/{photoId}.jpg
relationships/{relationshipId}/photos/{mediaId}_thumb.jpg
relationships/{relationshipId}/photos/videos/{mediaId}.{ext}
```

Davranış:

- image ve video path'leri ayrı sınır alır
- video için 100 MB limit, image için 20 MB limit vardır
- thumbnail de image path'ine düştüğü için korunur

Bu, `StorageService.uploadPhotoVideo(...)` ile birebir uyumludur.

### 4. Memory fotoğrafları

Path:

```text
relationships/{relationshipId}/memories/{photoId}.jpg
```

Davranış:

- sadece ilişki üyeleri erişir
- sadece image kabul edilir

### 5. Story medya dosyaları

Path'ler:

```text
relationships/{relationshipId}/stories/{file}.jpg
relationships/{relationshipId}/stories/thumbnails/{file}.jpg
relationships/{relationshipId}/stories/videos/{file}.{ext}
```

Davranış:

- story photo, story thumbnail ve story video ayrı kurallarla doğrulanır
- story videolarında 50 MB limit vardır
- thumbnail path'i 2 MB ile sınırlandırılır

Bu bölüm, mevcut depodaki storage rules'a göre ciddi bir sıkılaştırmadır; çünkü şu an sadece `isSignedIn()` ile korunan yerler var.

### 6. Secret Vault medya

Path:

```text
relationships/{relationshipId}/secretVault/{fileName}
```

Davranış:

- sadece ilişki üyeleri erişebilir
- image ve video kabul edilir
- her iki tip için 50 MB sınırı vardır

Bu limitler `StorageService.uploadSecretPhoto(...)` ve `StorageService.uploadSecretVideo(...)` ile uyumludur.

### 7. Surprise görselleri

Path:

```text
surprises/{relationshipId}/{uuid}.jpg
```

Davranış:

- sadece ilgili relationship üyeleri erişebilir
- sadece image kabul edilir
- 10 MB sınırı uygulanır

Mevcut rules dosyasında bu path tüm login kullanıcılara açıktı; bu düzeltilmiş oldu.

## Kritik Not: `downloadURL()` Token Davranışı

Bu uygulama birçok yerde Firebase Storage SDK ile `downloadURL()` alıp bu URL'yi doğrudan UI'da kullanıyor.

Bu şu anlama gelir:

- Storage Security Rules, SDK üzerinden yapılan erişimlerde devrededir.
- Ama `downloadURL()` içindeki token sızarsa, o URL kuralları by-pass ederek dışarıdan da kullanılabilir.

Bu yüzden hassas alanlar için ek düşünülmesi gerekenler:

1. Secret Vault gibi çok hassas medyada token sızıntısı riskini ciddiye al.
2. Gerekirse token rotation veya medya proxy yaklaşımı düşün.
3. Eski/iptal edilen medyaları gerçekten Storage'dan silmeye devam et.

## Firestore ile Birlikte Düşünülmesi Gereken Noktalar

Storage rules tek başına yeterli değildir. Path'e erişen kişinin gerçekten o ilişkiye ait olduğunu anlamak için `users/{uid}.relationshipId` alanına güveniliyor.

Bu yüzden:

- `users` Firestore rules'ı zayıfsa,
- ilişki bağlama akışı istemcide fazla açık bırakılırsa,

Storage tarafı da dolaylı olarak zayıflar.

Yani bu dosyadaki rules seti, `FIRESTORE_RULES_DETAYLI.md` içindeki önerilen Firestore yaklaşımıyla birlikte düşünülmelidir.

## Mevcut Kodla Uyum Durumu

Bu storage rules seti mevcut path yapısıyla uyumludur:

- `StorageService`
- `StoryService`
- `MessageService`
- `SurpriseService`

tarafında ekstra path değişikliği gerektirmez.

Dikkat edilmesi gereken tek nokta:

- profil resimlerini relationship dışındaki kullanıcılara da göstermek istiyorsan `profiles/{userId}` read kuralını genişletmen gerekir.
- şu anki uygulama akışında buna ihtiyaç görünmüyor.

## Deploy Öncesi Test Listesi

1. Profil resmi yükleme ve güncelleme çalışıyor mu?
2. Partner profil resmi görüntülenebiliyor mu?
3. Normal fotoğraf upload çalışıyor mu?
4. Galeri videosu + thumbnail upload çalışıyor mu?
5. Memory fotoğraf upload çalışıyor mu?
6. Chat içi görsel upload çalışıyor mu?
7. Story fotoğraf, thumbnail ve video upload çalışıyor mu?
8. Secret Vault foto/video upload çalışıyor mu?
9. Surprise görseli upload çalışıyor mu?
10. Relationship dışı farklı bir kullanıcı bu path'lere erişemiyor mu?

## Sonuç

Storage tarafında asıl açık, relationship bazlı path'lerin sadece `isSignedIn()` ile korunmuş olmasıydı. Bu dokümandaki rules seti, projedeki gerçek upload path'leriyle eşleşen ve her klasörü ilişki üyeliği + mime-type + boyut sınırı kombinasyonu ile koruyan daha üretim odaklı bir yapıdır.
