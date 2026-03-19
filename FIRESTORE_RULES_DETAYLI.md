# Firestore Rules Derinlemesine Analiz

Bu doküman, projedeki Swift servisleri, modeller, widget kullanımı ve `functions/index.js` içindeki Cloud Functions akışları incelenerek hazırlandı. Amaç sadece örnek bir rules dosyası vermek değil; uygulamanın gerçek veri modeline göre hangi koleksiyonların nasıl korunması gerektiğini netleştirmek.

## İncelenen Kod Alanları

- `sevgilim/Services/*.swift`
- `sevgilim/Models/*.swift`
- `sevgilim/Utilities/SecretVaultPINManager.swift`
- `sevgilim/Utilities/PushNotificationManager.swift`
- `functions/index.js`
- `sevgilim/firebase/firestore.rules`

## Koddan Çıkan Gerçek Firestore Şeması

Projede aktif kullanılan koleksiyonlar ve alt koleksiyonlar:

| Yol | Amaç | İstemci Yazıyor mu? | Cloud Functions Yazıyor mu? |
|---|---|---:|---:|
| `users/{userId}` | Kullanıcı profili, token, ilişki bağı | Evet | Evet |
| `users/{userId}/notifications/{notificationId}` | Bildirim geçmişi | Kısmen (`isRead`, `delete`) | Evet |
| `users/{userId}/notificationCooldowns/{docId}` | Bildirim spam önleme | Hayır | Evet |
| `relationships/{relationshipId}` | Çift ilişkisi, tema, sohbet temizleme, PIN hash | Evet | Evet |
| `relationships/{relationshipId}/typing/current` | Yazıyor göstergesi | Evet | Hayır |
| `invitations/{invitationId}` | Partner davet akışı | Evet | Hayır |
| `messages/{messageId}` | Mesajlar | Evet | Evet tetikleniyor |
| `photos/{photoId}` | Fotoğraf/video meta verisi | Evet | Evet tetikleniyor |
| `memories/{memoryId}` | Anılar, yorumlar, beğeniler | Evet | Evet tetikleniyor |
| `notes/{noteId}` | Ortak notlar | Evet | Evet tetikleniyor |
| `plans/{planId}` | Ortak planlar | Evet | Evet tetikleniyor |
| `movies/{movieId}` | İzlenen filmler | Evet | Evet tetikleniyor |
| `places/{placeId}` | Mekanlar | Evet | Evet tetikleniyor |
| `songs/{songId}` | Şarkılar | Evet | Evet tetikleniyor |
| `specialDays/{specialDayId}` | Özel günler | Evet | Evet tetikleniyor |
| `stories/{storyId}` | 24 saatlik hikayeler | Evet | Evet tetikleniyor |
| `surprises/{surpriseId}` | Kilitli/açılabilir sürprizler | Evet | Evet tetikleniyor |
| `moodStatuses/{statusId}` | Ruh hali durumları | Evet | Evet tetikleniyor |
| `secretVault/{itemId}` | Gizli kasa meta verisi | Evet | Evet tetikleniyor |
| `userLocations/{userId}` | Anlık konum yakınlık verisi | Evet | Hayır |

## Mevcut `firestore.rules` Dosyasında Bulduğum Sorunlar

Depodaki mevcut rules dosyası doğrudan deploy edilirse uygulama akışlarıyla çakışan noktalar var:

1. `messages`, `photos`, `memories`, `plans`, `notes`, `specialDays`, `movies`, `places`, `stories`, `surprises`, `moodStatuses` için `allow read, write: if ... resource.data.relationshipId ...` yazılmış.
   `create` aşamasında `resource.data` henüz yoktur; bu yüzden create işlemleri pratikte bloke olur.

2. Kod `secretVault` koleksiyonunu kullanıyor, rules dosyası `secretVaultItems` yazıyor.
   Bu yüzden gizli kasa kuralları yanlış koleksiyona uygulanıyor.

3. Kod `invitations` koleksiyonunu kullanıyor, rules dosyası `partnerInvitations` yazıyor.
   Davet akışı mevcut rules ile korunmuyor.

4. Kodda aktif olan ama rules dosyasında hiç tanımlanmamış yollar var:
   - `users/{userId}/notifications`
   - `users/{userId}/notificationCooldowns`
   - `relationships/{relationshipId}/typing`
   - `userLocations/{userId}`

5. `users/{userId}` için `allow read: if isSignedIn()` çok geniş.
   Bu haliyle login olan herkes teorik olarak tüm kullanıcı dökümanlarını okuyabilir.

6. `relationships/{relationshipId}` için `allow read, write: if isRelationshipMember(relationshipId)` çok gevşek.
   Bu yaklaşım, hassas alanlarda alan bazlı doğrulama yapmadığı için `secretVaultPINHash`, `chatClearedAt`, `user1Name`, `user2Name` gibi alanlar fazla serbest kalıyor.

## Güvenlik Tasarım Kararı

Bu projede en kritik nokta `acceptInvitation` akışı:

- Şu an istemci, tek batch içinde:
  - `relationships/{newId}` oluşturuyor
  - hem alıcının hem göndericinin `users/{userId}.relationshipId` alanını güncelliyor
  - `invitations/{invitationId}` durumunu değiştiriyor

Bu akış güvenli rules yazmayı zorlaştırıyor. Çünkü bir kullanıcının başka bir kullanıcının `users/{otherUserId}` dökümanını güncellemesine izin vermek gerekir. Bu da fazla yetki açar.

### Önerilen üretim yaklaşımı

`acceptInvitation` işlemini Callable Cloud Function veya HTTPS Function'a taşı:

1. İstemci sadece daveti kabul eder.
2. Sunucu:
   - daveti doğrular
   - relationship dökümanını oluşturur
   - iki kullanıcının `relationshipId` alanını günceller
   - invitation durumunu `accepted` yapar

Bu dokümandaki rules seti bu güvenli modeli baz alır.

## Önerilen `firestore.rules`

Not: Aşağıdaki rules seti üretim odaklı ve sıkılaştırılmıştır. `acceptInvitation` akışını sunucuya taşıdığında doğrudan kullanılabilecek yapıdadır.

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() {
      return request.auth != null;
    }

    function uid() {
      return request.auth.uid;
    }

    function isSelf(userId) {
      return signedIn() && uid() == userId;
    }

    function userDoc(userId) {
      return get(/databases/$(database)/documents/users/$(userId));
    }

    function userExists(userId) {
      return exists(/databases/$(database)/documents/users/$(userId));
    }

    function currentUserDoc() {
      return userDoc(uid());
    }

    function currentUserExists() {
      return signedIn() && userExists(uid());
    }

    function currentRelationshipId() {
      return currentUserExists() ? currentUserDoc().data.relationshipId : null;
    }

    function relationshipDoc(relationshipId) {
      return get(/databases/$(database)/documents/relationships/$(relationshipId));
    }

    function relationshipExists(relationshipId) {
      return relationshipId is string
        && exists(/databases/$(database)/documents/relationships/$(relationshipId));
    }

    function isRelationshipMember(relationshipId) {
      return signedIn()
        && relationshipExists(relationshipId)
        && (
          relationshipDoc(relationshipId).data.user1Id == uid()
          || relationshipDoc(relationshipId).data.user2Id == uid()
        );
    }

    function sharesRelationshipWithUser(userId) {
      return currentUserExists()
        && userExists(userId)
        && currentRelationshipId() != null
        && userDoc(userId).data.relationshipId == currentRelationshipId();
    }

    function onlyChanges(allowedKeys) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(allowedKeys);
    }

    function validNotificationPreferences(prefs) {
      return prefs is map
        && prefs.keys().hasOnly(["chat", "memory", "plan", "specialDay"])
        && prefs.chat is bool
        && prefs.memory is bool
        && prefs.plan is bool
        && prefs.specialDay is bool;
    }

    function validUserCreate(userId) {
      return isSelf(userId)
        && request.resource.data.keys().hasOnly([
          "email",
          "name",
          "profileImageURL",
          "relationshipId",
          "createdAt",
          "fcmTokens",
          "notificationPreferences",
          "unreadNotificationCount"
        ])
        && request.resource.data.email is string
        && request.resource.data.name is string
        && request.resource.data.createdAt is timestamp
        && request.resource.data.fcmTokens is list
        && validNotificationPreferences(request.resource.data.notificationPreferences)
        && request.resource.data.unreadNotificationCount == 0
        && (
          !request.resource.data.keys().hasAny(["profileImageURL"])
          || request.resource.data.profileImageURL is string
        )
        && (
          !request.resource.data.keys().hasAny(["relationshipId"])
          || request.resource.data.relationshipId == null
        );
    }

    function validUserUpdate(userId) {
      return isSelf(userId)
        && onlyChanges([
          "name",
          "profileImageURL",
          "notificationPreferences",
          "fcmTokens",
          "fcmUpdatedAt",
          "relationshipId"
        ])
        && request.resource.data.email == resource.data.email
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.unreadNotificationCount == resource.data.unreadNotificationCount
        && (
          !request.resource.data.keys().hasAny(["notificationPreferences"])
          || validNotificationPreferences(request.resource.data.notificationPreferences)
        )
        && (
          request.resource.data.relationshipId == resource.data.relationshipId
          || (
            resource.data.relationshipId == null
            && request.resource.data.relationshipId is string
            && isRelationshipMember(request.resource.data.relationshipId)
          )
        );
    }

    function validInvitationRead() {
      return signedIn()
        && (
          resource.data.senderUserId == uid()
          || (
            request.auth.token.email != null
            && resource.data.receiverEmail == request.auth.token.email
          )
        );
    }

    function validInvitationCreate() {
      return signedIn()
        && request.resource.data.keys().hasOnly([
          "senderUserId",
          "senderName",
          "senderEmail",
          "receiverEmail",
          "relationshipStartDate",
          "status",
          "createdAt"
        ])
        && request.resource.data.senderUserId == uid()
        && request.resource.data.senderName is string
        && request.resource.data.senderEmail is string
        && request.resource.data.receiverEmail is string
        && request.resource.data.relationshipStartDate is timestamp
        && request.resource.data.createdAt is timestamp
        && request.resource.data.status == "pending"
        && request.auth.token.email != null
        && request.resource.data.senderEmail == request.auth.token.email;
    }

    function validInvitationResponse() {
      return signedIn()
        && request.auth.token.email != null
        && resource.data.receiverEmail == request.auth.token.email
        && resource.data.status == "pending"
        && onlyChanges(["status", "respondedAt"])
        && (
          request.resource.data.status == "accepted"
          || request.resource.data.status == "rejected"
        )
        && request.resource.data.respondedAt is timestamp;
    }

    function validRelationshipUpdate(relationshipId) {
      return isRelationshipMember(relationshipId)
        && onlyChanges([
          "startDate",
          "themeColor",
          "chatClearedAt",
          "secretVaultPINHash",
          "user1Name",
          "user2Name"
        ])
        && request.resource.data.user1Id == resource.data.user1Id
        && request.resource.data.user2Id == resource.data.user2Id
        && request.resource.data.createdAt == resource.data.createdAt
        && (
          request.resource.data.user1Name == resource.data.user1Name
          || uid() == resource.data.user1Id
        )
        && (
          request.resource.data.user2Name == resource.data.user2Name
          || uid() == resource.data.user2Id
        );
    }

    function validTypingWrite(relationshipId) {
      return isRelationshipMember(relationshipId)
        && request.resource.data.keys().hasOnly([
          "userId",
          "userName",
          "isTyping",
          "timestamp"
        ])
        && request.resource.data.userId == uid()
        && request.resource.data.userName is string
        && request.resource.data.isTyping is bool
        && request.resource.data.timestamp is timestamp;
    }

    function validMessageCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.keys().hasOnly([
          "relationshipId",
          "senderId",
          "senderName",
          "text",
          "imageURL",
          "storyImageURL",
          "timestamp",
          "isRead",
          "readAt",
          "reactions",
          "deletedForUserIds",
          "isDeletedForEveryone",
          "deletedAt"
        ])
        && request.resource.data.senderId == uid()
        && request.resource.data.senderName is string
        && request.resource.data.text is string
        && request.resource.data.timestamp is timestamp
        && request.resource.data.isRead == false
        && (
          !request.resource.data.keys().hasAny(["imageURL"])
          || request.resource.data.imageURL is string
        )
        && (
          !request.resource.data.keys().hasAny(["storyImageURL"])
          || request.resource.data.storyImageURL is string
        )
        && (
          !request.resource.data.keys().hasAny(["readAt"])
          || request.resource.data.readAt == null
        );
    }

    function validMessageUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && onlyChanges([
          "text",
          "imageURL",
          "storyImageURL",
          "isRead",
          "readAt",
          "reactions",
          "deletedForUserIds",
          "isDeletedForEveryone",
          "deletedAt"
        ])
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.senderId == resource.data.senderId
        && request.resource.data.senderName == resource.data.senderName
        && request.resource.data.timestamp == resource.data.timestamp
        && (
          !request.resource.data.diff(resource.data).affectedKeys().hasAny([
            "text",
            "imageURL",
            "storyImageURL",
            "isDeletedForEveryone",
            "deletedAt"
          ])
          || uid() == resource.data.senderId
        )
        && (
          !request.resource.data.diff(resource.data).affectedKeys().hasAny(["deletedForUserIds"])
          || request.resource.data.deletedForUserIds.hasAll([uid()])
        )
        && (
          !request.resource.data.diff(resource.data).affectedKeys().hasAny(["isRead", "readAt"])
          || request.resource.data.isRead == true
        );
    }

    function validPhotoCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.uploadedBy == uid()
        && request.resource.data.createdAt is timestamp
        && request.resource.data.date is timestamp
        && (
          request.resource.data.mediaType == "photo"
          || request.resource.data.mediaType == "video"
        );
    }

    function validMemoryCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.createdBy == uid()
        && request.resource.data.title is string
        && request.resource.data.content is string
        && request.resource.data.date is timestamp
        && request.resource.data.createdAt is timestamp
        && request.resource.data.likes is list
        && request.resource.data.comments is list;
    }

    function validMemoryUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.createdBy == resource.data.createdBy
        && request.resource.data.createdAt == resource.data.createdAt;
    }

    function validNoteCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.createdBy == uid()
        && request.resource.data.title is string
        && request.resource.data.content is string
        && request.resource.data.createdAt is timestamp
        && request.resource.data.updatedAt is timestamp;
    }

    function validNoteUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.createdBy == resource.data.createdBy
        && request.resource.data.createdAt == resource.data.createdAt;
    }

    function validPlanCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.createdBy == uid()
        && request.resource.data.title is string
        && request.resource.data.isCompleted == false
        && request.resource.data.reminderEnabled is bool
        && request.resource.data.createdAt is timestamp;
    }

    function validPlanUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.createdBy == resource.data.createdBy
        && request.resource.data.createdAt == resource.data.createdAt;
    }

    function validMovieCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.addedBy == uid()
        && request.resource.data.title is string
        && request.resource.data.watchedDate is timestamp
        && request.resource.data.createdAt is timestamp;
    }

    function validMovieUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.addedBy == resource.data.addedBy
        && request.resource.data.createdAt == resource.data.createdAt;
    }

    function validPlaceCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.addedBy == uid()
        && request.resource.data.name is string
        && request.resource.data.latitude is number
        && request.resource.data.longitude is number
        && request.resource.data.date is timestamp
        && request.resource.data.createdAt is timestamp;
    }

    function validPlaceUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.addedBy == resource.data.addedBy
        && request.resource.data.createdAt == resource.data.createdAt;
    }

    function validSongCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.addedBy == uid()
        && request.resource.data.title is string
        && request.resource.data.artist is string
        && request.resource.data.date is timestamp
        && request.resource.data.createdAt is timestamp;
    }

    function validSongUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.addedBy == resource.data.addedBy
        && request.resource.data.createdAt == resource.data.createdAt;
    }

    function validSpecialDayCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.createdBy == uid()
        && request.resource.data.title is string
        && request.resource.data.date is timestamp
        && request.resource.data.category is string
        && request.resource.data.icon is string
        && request.resource.data.color is string
        && request.resource.data.isRecurring is bool
        && request.resource.data.createdAt is timestamp;
    }

    function validSpecialDayUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.createdBy == resource.data.createdBy
        && request.resource.data.createdAt == resource.data.createdAt;
    }

    function validStoryCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.createdBy == uid()
        && request.resource.data.createdByName is string
        && request.resource.data.photoURL is string
        && request.resource.data.mediaType is string
        && request.resource.data.createdAt is timestamp
        && request.resource.data.viewedBy is list
        && request.resource.data.viewedBy.hasAll([uid()]);
    }

    function validStoryUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && onlyChanges(["viewedBy", "viewedAt", "likedBy", "likeTimestamps"])
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.createdBy == resource.data.createdBy
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.photoURL == resource.data.photoURL
        && request.resource.data.mediaType == resource.data.mediaType;
    }

    function validSurpriseCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.createdBy == uid()
        && request.resource.data.createdFor is string
        && request.resource.data.createdFor != uid()
        && request.resource.data.title is string
        && request.resource.data.message is string
        && request.resource.data.revealDate is timestamp
        && request.resource.data.createdAt is timestamp
        && request.resource.data.isOpened == false;
    }

    function validSurpriseUpdate() {
      return isRelationshipMember(resource.data.relationshipId)
        && onlyChanges(["isOpened", "openedAt", "isManuallyHidden"])
        && request.resource.data.relationshipId == resource.data.relationshipId
        && request.resource.data.createdBy == resource.data.createdBy
        && request.resource.data.createdFor == resource.data.createdFor
        && request.resource.data.createdAt == resource.data.createdAt
        && request.resource.data.title == resource.data.title
        && request.resource.data.message == resource.data.message
        && request.resource.data.revealDate == resource.data.revealDate
        && (
          !request.resource.data.diff(resource.data).affectedKeys().hasAny(["isOpened", "openedAt"])
          || (
            uid() == resource.data.createdFor
            && request.time >= resource.data.revealDate
            && request.resource.data.isOpened == true
          )
        )
        && (
          !request.resource.data.diff(resource.data).affectedKeys().hasAny(["isManuallyHidden"])
          || uid() == resource.data.createdBy
        );
    }

    function validMoodWrite(statusId) {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.userId == uid()
        && request.resource.data.mood is string
        && request.resource.data.updatedAt is timestamp
        && statusId == request.resource.data.relationshipId + "_" + uid();
    }

    function validSecretVaultCreate() {
      return isRelationshipMember(request.resource.data.relationshipId)
        && request.resource.data.uploadedBy == uid()
        && request.resource.data.downloadURL is string
        && request.resource.data.storagePath is string
        && request.resource.data.type is string
        && request.resource.data.createdAt is timestamp
        && request.resource.data.contentType is string;
    }

    function validUserLocationWrite(userId) {
      return isSelf(userId)
        && request.resource.data.keys().hasOnly([
          "latitude",
          "longitude",
          "timestamp",
          "accuracy"
        ])
        && request.resource.data.latitude is number
        && request.resource.data.longitude is number
        && request.resource.data.latitude >= -90
        && request.resource.data.latitude <= 90
        && request.resource.data.longitude >= -180
        && request.resource.data.longitude <= 180
        && request.resource.data.timestamp is timestamp;
    }

    match /users/{userId} {
      allow read: if isSelf(userId) || sharesRelationshipWithUser(userId);
      allow create: if validUserCreate(userId);
      allow update: if validUserUpdate(userId);
      allow delete: if isSelf(userId);

      match /notifications/{notificationId} {
        allow read: if isSelf(userId);
        allow update: if isSelf(userId)
          && onlyChanges(["isRead", "readAt"])
          && request.resource.data.isRead == true;
        allow delete: if isSelf(userId);
      }

      match /notificationCooldowns/{docId} {
        allow read, write: if false;
      }
    }

    match /invitations/{invitationId} {
      allow read: if validInvitationRead();
      allow create: if validInvitationCreate();
      allow update: if validInvitationResponse();
      allow delete: if false;
    }

    match /relationships/{relationshipId} {
      allow read: if isRelationshipMember(relationshipId);
      allow create: if false;
      allow update: if validRelationshipUpdate(relationshipId);
      allow delete: if false;

      match /typing/{typingId} {
        allow read: if isRelationshipMember(relationshipId);
        allow create, update: if validTypingWrite(relationshipId);
        allow delete: if isRelationshipMember(relationshipId) && resource.data.userId == uid();
      }
    }

    match /messages/{messageId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validMessageCreate();
      allow update: if validMessageUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /photos/{photoId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validPhotoCreate();
      allow update: if false;
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /memories/{memoryId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validMemoryCreate();
      allow update: if validMemoryUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /notes/{noteId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validNoteCreate();
      allow update: if validNoteUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /plans/{planId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validPlanCreate();
      allow update: if validPlanUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /movies/{movieId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validMovieCreate();
      allow update: if validMovieUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /places/{placeId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validPlaceCreate();
      allow update: if validPlaceUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /songs/{songId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validSongCreate();
      allow update: if validSongUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /specialDays/{specialDayId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validSpecialDayCreate();
      allow update: if validSpecialDayUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /stories/{storyId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validStoryCreate();
      allow update: if validStoryUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId)
        && (
          resource.data.createdBy == uid()
          || request.time > resource.data.createdAt + duration.value(24, "h")
        );
    }

    match /surprises/{surpriseId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validSurpriseCreate();
      allow update: if validSurpriseUpdate();
      allow delete: if isRelationshipMember(resource.data.relationshipId)
        && resource.data.createdBy == uid();
    }

    match /moodStatuses/{statusId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create, update: if validMoodWrite(statusId);
      allow delete: if false;
    }

    match /secretVault/{itemId} {
      allow read: if isRelationshipMember(resource.data.relationshipId);
      allow create: if validSecretVaultCreate();
      allow update: if false;
      allow delete: if isRelationshipMember(resource.data.relationshipId);
    }

    match /userLocations/{userId} {
      allow read: if isSelf(userId) || sharesRelationshipWithUser(userId);
      allow create, update: if validUserLocationWrite(userId);
      allow delete: if isSelf(userId);
    }
  }
}
```

## Bu Rules Setinin Uygulamaya Göre Davranışı

### 1. `users`

- Kullanıcı kendi dökümanını oluşturabilir.
- Kullanıcı kendi profilini, token listesini ve bildirim tercihlerini güncelleyebilir.
- Kullanıcı başka bir kullanıcının profilini ancak aynı relationship içindeyse okuyabilir.
- `unreadNotificationCount` gibi sayaç alanları istemciden değiştirilemez; bunlar Cloud Functions tarafına bırakılır.

### 2. `users/{userId}/notifications`

- Bildirim geçmişini sadece dökümanın sahibi okuyabilir.
- İstemci sadece `isRead` ve `readAt` alanını değiştirebilir.
- Bildirim oluşturma yetkisi verilmez; bunu zaten `functions/index.js` Admin SDK ile yapıyor.

### 3. `notificationCooldowns`

- Tamamen sunucu alanı.
- İstemci okumaz, yazmaz.

### 4. `invitations`

- Gönderen kendi gönderdiği daveti okuyabilir.
- Alıcı, kendi e-posta adresine gelen daveti okuyabilir.
- Alıcı sadece `pending -> accepted/rejected` dönüşümünü yapabilir.

### 5. `relationships`

- Okuma sadece ilişki üyelerine açık.
- `create` burada kapalı bırakıldı; önerilen modelde bunu Cloud Function yapmalı.
- İlişki dökümanında güncellenebilen alanlar:
  - `startDate`
  - `themeColor`
  - `chatClearedAt`
  - `secretVaultPINHash`
  - ilgili kullanıcının kendi `user1Name` veya `user2Name` alanı

### 6. `relationships/{relationshipId}/typing`

- Sadece o ilişkiye ait iki kullanıcı okuyabilir/yazabilir.
- `userId` her zaman `request.auth.uid` ile eşleşmek zorunda.

### 7. İçerik koleksiyonları (`messages`, `memories`, `notes`, `plans`, `movies`, `places`, `songs`, `specialDays`, `stories`, `surprises`, `secretVault`)

- Okuma ve yazma, `relationshipId` üzerinden çift üyeliği ile sınırlanır.
- Sahiplik mantığı koleksiyona göre değişir:
  - `messages.senderId`
  - `memories.createdBy`
  - `notes.createdBy`
  - `plans.createdBy`
  - `movies.addedBy`
  - `places.addedBy`
  - `songs.addedBy`
  - `specialDays.createdBy`
  - `stories.createdBy`
  - `surprises.createdBy`
  - `secretVault.uploadedBy`

### 8. `userLocations`

- Her kullanıcı sadece kendi konum dökümanını yazar.
- Okuma ise aynı relationship içindeki partner ile sınırlıdır.

## Kod Bazlı Ek Notlar

### `messages`

Mevcut kodda:

- mesaj gönderme
- resimli mesaj gönderme
- okundu işareti
- reaksiyon ekleme
- kendim için sil
- herkes için sil

akışları var. Bu yüzden `messages` kuralları generic bir `write` yerine daha kontrollü `create/update/delete` olarak yazıldı.

### `stories`

Kodda story oluşturma, görüntüleme, beğenme ve 24 saat sonra silme var. Bu yüzden:

- sadece üyeler okuyabilir,
- sadece oluşturucu create eder,
- update sadece `viewedBy/viewedAt/likedBy/likeTimestamps` alanlarıyla sınırlı,
- delete ya story sahibi ya da story süresi dolmuşsa ilişki üyesi tarafından yapılabilir.

### `surprises`

Sürprizler diğer koleksiyonlardan daha hassas:

- `createdBy` ile oluşturan,
- `createdFor` ile hedef kullanıcı,
- `revealDate`,
- `isOpened`,
- `isManuallyHidden`

alanları var. Burada açma ve gizleme aksiyonları ayrıştırıldı.

## Mevcut İstemci Koduyla Uyum Notu

Bu rules setini deploy edersen, aşağıdaki istemci akışını refactor etmen gerekir:

- `RelationshipService.acceptInvitation(...)`

Sebep:

- receiver kullanıcısı, sender kullanıcısının `users/{senderId}` dökümanını güncellemeye çalışıyor.
- production-grade rules içinde buna izin vermek istemeyiz.

### Ne yapmalısın?

En doğru çözüm:

1. `acceptInvitation` işini Cloud Function'a taşı.
2. İstemci sadece `invitationId` gönderip "kabul et" desin.
3. Function kalan işlemleri yapsın.

## İstersen Geçici Uyum Katmanı

Eğer kısa vadede istemci tarafındaki `acceptInvitation` batch akışını hemen bozmadan ilerlemek istersen, `users/{userId}` `allow update` kuralına geçici ve daha gevşek bir blok ekleyebilirsin. Bu öneriyi bilinçli olarak ana rules setine koymadım, çünkü başka kullanıcının `relationshipId` alanına istemciden yazma yetkisi açar.

## Deploy Öncesi Test Listesi

1. Yeni kullanıcı kayıt olabiliyor mu?
2. Kullanıcı kendi profil adını değiştirebiliyor mu?
3. Partner profili relationship içindeyken okunabiliyor mu?
4. Notification history sadece sahibi tarafından listelenebiliyor mu?
5. Typing indicator iki partner arasında çalışıyor mu?
6. Mesaj oluşturma ve `isRead` güncellemesi çalışıyor mu?
7. Memory like/comment akışları çalışıyor mu?
8. Story görüntüleme ve beğeni akışları çalışıyor mu?
9. Surprise açma akışı reveal tarihinden önce engelleniyor mu?
10. Proximity için `userLocations` okuma/yazma düzgün mü?

## Sonuç

Bu projede Firestore güvenliği için en kritik karar, relationship bağlama ve invitation acceptance akışını istemciden alıp sunucuya taşımaktır. Bunu yaptığında rules seti belirgin şekilde sadeleşir, güvenlik modeli netleşir ve yanlışlıkla fazla yetki açma ihtimali ciddi şekilde düşer.
