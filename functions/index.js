/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions/v1");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const firestore = admin.firestore();
const fieldValue = admin.firestore.FieldValue;

const ensureJson = (body) => {
  if (!body) {
    return {};
  }

  if (typeof body === "string") {
    try {
      return JSON.parse(body);
    } catch (error) {
      throw new Error("Body must be valid JSON.");
    }
  }

  return body;
};

const sanitiseData = (data) => {
  if (!data || typeof data !== "object") {
    return undefined;
  }

  const clean = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) {
      continue;
    }
    clean[key] = typeof value === "string" ? value : JSON.stringify(value);
  }

  return Object.keys(clean).length ? clean : undefined;
};

const normaliseTokens = (tokens = []) => {
  const list = Array.isArray(tokens) ? tokens : [tokens];
  const filtered = list.filter((token) => {
    return typeof token === "string" && token.trim().length > 0;
  });
  return Array.from(new Set(filtered));
};

const applyDefaultApns = (message = {}) => {
  const apns = {...(message.apns || {})};
  const payload = {...(apns.payload || {})};
  const aps = {...(payload.aps || {})};
  if (typeof aps.sound !== "string" || !aps.sound.trim()) {
    aps.sound = "default";
  }
  return {
    ...message,
    apns: {
      ...apns,
      payload: {
        ...payload,
        aps,
      },
    },
  };
};

const chunkArray = (items, chunkSize = 200) => {
  if (!Array.isArray(items) || chunkSize < 1) {
    return [];
  }
  const chunks = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    chunks.push(items.slice(i, i + chunkSize));
  }
  return chunks;
};

const truncate = (value, max = 120) => {
  if (!value || typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed.length) {
    return null;
  }
  if (trimmed.length <= max) {
    return trimmed;
  }
  return `${trimmed.substring(0, max - 3)}...`;
};

const loadUsers = async (userIds = []) => {
  const uniqueIds = Array.from(new Set(userIds.filter((id) => {
    return typeof id === "string" && id;
  })));
  if (!uniqueIds.length) {
    return new Map();
  }

  const idChunks = chunkArray(uniqueIds, 200);
  const map = new Map();

  const chunkSnapshots = await Promise.all(idChunks.map(async (chunk) => {
    const refs = chunk.map((userId) => {
      return firestore.collection("users").doc(userId);
    });
    try {
      return await firestore.getAll(...refs);
    } catch (error) {
      logger.error("Failed to load user chunk.", {userIds: chunk, error});
      return refs.map(() => null);
    }
  }));

  chunkSnapshots.forEach((snapshots, chunkIndex) => {
    const chunkIds = idChunks[chunkIndex];
    snapshots.forEach((snapshot, snapshotIndex) => {
      const userId = chunkIds[snapshotIndex];
      if (snapshot && snapshot.exists) {
        map.set(userId, {id: userId, ...snapshot.data()});
      }
    });
  });

  return map;
};

const fetchRelationship = async (relationshipId) => {
  if (!relationshipId) {
    return null;
  }

  try {
    const snapshot = await firestore
        .collection("relationships")
        .doc(relationshipId)
        .get();
    if (!snapshot.exists) {
      return null;
    }
    return {id: snapshot.id, ...snapshot.data()};
  } catch (error) {
    logger.error("Failed to load relationship.", {relationshipId, error});
    return null;
  }
};

const collectTokensForUsers = async (userIds = []) => {
  const userMap = await loadUsers(userIds);
  const tokens = [];
  const tokenOwners = new Map();

  userMap.forEach((user, userId) => {
    const userTokens = normaliseTokens(user.fcmTokens || user.fcmToken || []);
    userTokens.forEach((token) => {
      tokens.push(token);
      if (!tokenOwners.has(token)) {
        tokenOwners.set(token, new Set());
      }
      tokenOwners.get(token).add(userId);
    });
  });

  return {tokens: normaliseTokens(tokens), tokenOwners};
};

const getRelationshipUserIds = (relationship) => {
  if (!relationship) {
    return [];
  }
  const ids = [relationship.user1Id, relationship.user2Id].filter((id) => id);
  return Array.from(new Set(ids));
};

const moodDetails = {
  happy: {title: "Mutlu", emoji: "😊"},
  missing: {title: "Özledim", emoji: "🥺"},
  sad: {title: "Üzgün", emoji: "😔"},
  excited: {title: "Heyecanlı", emoji: "🤩"},
  tired: {title: "Yorgun", emoji: "🥱"},
  love: {title: "Aşık", emoji: "😍"},
};

const describeMood = (value) => {
  if (!value || typeof value !== "string") {
    return {title: null, emoji: ""};
  }
  const clean = value.trim();
  if (!clean.length) {
    return {title: null, emoji: ""};
  }
  const details = moodDetails[clean];
  if (details) {
    return details;
  }
  const formatted = clean.replace(/[_-]+/g, " ");
  const title = formatted.charAt(0).toUpperCase() + formatted.slice(1);
  return {title, emoji: ""};
};

const toDate = (value) => {
  if (!value) {
    return null;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const formatDateTime = (value) => {
  const date = toDate(value);
  if (!date) {
    return null;
  }

  try {
    const formatter = new Intl.DateTimeFormat("tr-TR", {
      day: "numeric",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
    return formatter.format(date);
  } catch (error) {
    logger.warn("Failed to format date.", {error});
  }
  return date.toISOString();
};

const describeTimeUntil = (targetDate, now = new Date()) => {
  const date = toDate(targetDate);
  if (!date) {
    return null;
  }

  const diffMs = date.getTime() - now.getTime();
  if (diffMs <= 0) {
    return "Az sonra";
  }

  const diffMinutes = Math.round(diffMs / (1000 * 60));
  if (diffMinutes < 60) {
    return `${diffMinutes} dakika içinde`;
  }

  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) {
    return `${diffHours} saat içinde`;
  }

  const diffDays = Math.round(diffHours / 24);
  return `${diffDays} gün içinde`;
};

const createDateKey = (date) => {
  const value = toDate(date);
  if (!value) {
    return null;
  }
  return value.toISOString().split("T")[0];
};

const computeNextSpecialDayDate = (specialDay, now = new Date()) => {
  const baseDate = toDate(specialDay?.date);
  if (!baseDate) {
    return null;
  }

  if (!specialDay.isRecurring) {
    return baseDate;
  }

  const candidate = new Date(
      now.getFullYear(),
      baseDate.getMonth(),
      baseDate.getDate(),
  );

  if (candidate < now) {
    return new Date(
        now.getFullYear() + 1,
        baseDate.getMonth(),
        baseDate.getDate(),
    );
  }
  return candidate;
};

const invalidTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
  "messaging/unregistered",
  "messaging/invalid-recipient",
]);

const isInvalidTokenError = (error) => {
  if (!error) {
    return false;
  }

  if (typeof error.code === "string" && invalidTokenCodes.has(error.code)) {
    return true;
  }

  if (typeof error.message === "string") {
    return Array.from(invalidTokenCodes).some((code) => {
      return error.message.includes(code);
    });
  }

  return false;
};

const findTokenOwners = async (tokens = []) => {
  const cleanTokens = normaliseTokens(tokens);
  if (!cleanTokens.length) {
    return new Map();
  }

  const tokenOwners = new Map();

  await Promise.all(cleanTokens.map(async (token) => {
    const owners = new Set();
    try {
      const [arraySnapshot, singleSnapshot] = await Promise.all([
        firestore.collection("users")
            .where("fcmTokens", "array-contains", token)
            .limit(50)
            .get(),
        firestore.collection("users")
            .where("fcmToken", "==", token)
            .limit(50)
            .get(),
      ]);

      arraySnapshot.forEach((doc) => owners.add(doc.id));
      singleSnapshot.forEach((doc) => owners.add(doc.id));
    } catch (error) {
      logger.error("Failed to resolve token owners.", {token, error});
    }

    if (owners.size > 0) {
      tokenOwners.set(token, owners);
    }
  }));

  return tokenOwners;
};

const pruneInvalidTokens = async (tokenOwners, failedTokens = []) => {
  if (!failedTokens.length) {
    return;
  }

  const updates = [];
  failedTokens.forEach((token) => {
    const owners = tokenOwners.get(token);
    if (!owners) {
      return;
    }

    owners.forEach((userId) => {
      updates.push(
          firestore.collection("users").doc(userId).update({
            fcmTokens: fieldValue.arrayRemove(token),
          }),
      );
    });
  });

  if (!updates.length) {
    return;
  }

  try {
    await Promise.all(updates);
    logger.info("Invalid tokens pruned.", {count: failedTokens.length});
  } catch (error) {
    logger.error("Failed to prune invalid tokens.", error);
  }
};

const sendPushToUsers = async ({userIds = [], notification, data}) => {
  if (!notification || !notification.title || !notification.body) {
    throw new Error("Notification title and body are required.");
  }

  const {tokens, tokenOwners} = await collectTokensForUsers(userIds);
  if (!tokens.length) {
    logger.info("No tokens found for users.", {userIds});
    return null;
  }

  const messaging = admin.messaging();
  const cleanData = sanitiseData(data);

  const response = await messaging.sendEachForMulticast(
      applyDefaultApns({
        tokens,
        notification,
        data: cleanData,
      }),
  );

  if (response.failureCount > 0) {
    const failedTokens = response.responses.reduce((list, result, index) => {
      if (!result.success) {
        list.push(tokens[index]);
      }
      return list;
    }, []);

    await pruneInvalidTokens(tokenOwners, failedTokens);
  }

  logger.info("Push notification sent.", {
    title: notification.title,
    recipients: userIds,
    sent: response.successCount,
    failed: response.failureCount,
  });

  return response;
};

exports.sendPushNotification = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.set("Allow", "POST");
    return res.status(405).json({error: "Only POST is allowed."});
  }

  try {
    const payload = ensureJson(req.body);
    const {token, tokens, topic, title, body, data} = payload;

    if (!title || !body) {
      return res.status(400).json({
        error: "Missing notification title or body.",
      });
    }

    const messaging = admin.messaging();
    const notification = {title, body};
    const messageData = sanitiseData(data);

    if (Array.isArray(tokens) && tokens.length > 0) {
      const cleanTokens = normaliseTokens(tokens);
      if (!cleanTokens.length) {
        return res.status(400).json({
          error: "No valid tokens provided.",
        });
      }

      const response = await messaging.sendEachForMulticast(
          applyDefaultApns({
            tokens: cleanTokens,
            notification,
            data: messageData,
          }),
      );

      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        if (!result.success && isInvalidTokenError(result.error)) {
          invalidTokens.push(cleanTokens[index]);
        }
      });

      if (invalidTokens.length) {
        const tokenOwners = await findTokenOwners(invalidTokens);
        await pruneInvalidTokens(tokenOwners, invalidTokens);
      }

      logger.info("Multicast notification dispatched.", {
        successCount: response.successCount,
        failureCount: response.failureCount,
        invalidTokensPruned: invalidTokens.length,
      });

      return res.status(200).json({
        success: true,
        sent: response.successCount,
        failed: response.failureCount,
      });
    }

    if (typeof token === "string" && token.length > 0) {
      const cleanToken = normaliseTokens(token)[0];
      if (!cleanToken) {
        return res.status(400).json({
          error: "No valid token provided.",
        });
      }

      try {
        await messaging.send(
            applyDefaultApns({
              token: cleanToken,
              notification,
              data: messageData,
            }),
        );
      } catch (sendError) {
        if (isInvalidTokenError(sendError)) {
          const tokenOwners = await findTokenOwners([cleanToken]);
          await pruneInvalidTokens(tokenOwners, [cleanToken]);
        }
        throw sendError;
      }

      logger.info("Notification sent to single device.");
      return res.status(200).json({success: true});
    }

    if (typeof topic === "string" && topic.length > 0) {
      await messaging.send(
          applyDefaultApns({
            topic,
            notification,
            data: messageData,
          }),
      );

      logger.info("Notification broadcast to topic.", {topic});
      return res.status(200).json({success: true, topic});
    }

    return res.status(400).json({
      error: "Provide at least one token, tokens array, or topic.",
    });
  } catch (error) {
    logger.error("Failed to send push notification.", error);
    return res.status(500).json({error: error.message});
  }
});

const buildNotificationBody = (parts = []) => {
  const filtered = parts.filter((part) => {
    return typeof part === "string" && part.trim().length > 0;
  });
  if (!filtered.length) {
    return null;
  }
  return filtered.join(" • ");
};

exports.onMemoryCreated = functions.firestore
    .document("memories/{memoryId}")
    .onCreate(async (snapshot, context) => {
      const memory = snapshot.data();
      if (!memory?.relationshipId || !memory?.createdBy) {
        return null;
      }

      const relationship = await fetchRelationship(memory.relationshipId);
      if (!relationship) {
        return null;
      }

      const partnerId = relationship.user1Id === memory.createdBy ?
        relationship.user2Id :
        relationship.user1Id;
      if (!partnerId || partnerId === memory.createdBy) {
        return null;
      }

      const users = await loadUsers([memory.createdBy]);
      const creator = users.get(memory.createdBy);
      const creatorName = creator?.name || "Partnerin";
      const body =
          buildNotificationBody([
            memory.title,
            memory.location,
          ]) || "Yeni anıyı keşfetmek ister misin?";

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: `${creatorName} yeni bir anı ekledi`,
          body,
        },
        data: {
          type: "memory_new",
          memoryId: context.params.memoryId,
          relationshipId: memory.relationshipId,
          createdBy: memory.createdBy,
        },
      });
    });

exports.onMemoryCommented = functions.firestore
    .document("memories/{memoryId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.exists ? change.before.data() : {};
      const afterData = change.after.exists ? change.after.data() : null;

      if (!afterData?.relationshipId) {
        return null;
      }

      const beforeComments = Array.isArray(beforeData?.comments) ?
        beforeData.comments :
        [];
      const afterComments = Array.isArray(afterData?.comments) ?
        afterData.comments :
        [];

      if (afterComments.length <= beforeComments.length) {
        return null;
      }

      const beforeIds = new Set(
          beforeComments
              .map((comment) => {
                return typeof comment?.id === "string" ? comment.id : null;
              })
              .filter(Boolean),
      );

      let newComment = afterComments.find((comment) => {
        if (!comment || typeof comment !== "object") {
          return false;
        }
        if (typeof comment.id === "string" && comment.id) {
          return !beforeIds.has(comment.id);
        }
        return false;
      });

      if (!newComment && afterComments.length) {
        const newEntries = afterComments.slice(beforeComments.length);
        newComment = newEntries.length ?
          newEntries[newEntries.length - 1] :
          afterComments[afterComments.length - 1];
      }

      if (!newComment || typeof newComment !== "object") {
        return null;
      }

      const commenterId = typeof newComment.userId === "string" ?
        newComment.userId.trim() :
        "";
      if (!commenterId) {
        return null;
      }

      const relationship = await fetchRelationship(afterData.relationshipId);
      if (!relationship) {
        return null;
      }

      const recipients = getRelationshipUserIds(relationship)
          .filter((id) => id && id !== commenterId);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([commenterId]);
      const commenter = users.get(commenterId);
      const fallbackName = typeof newComment.userName === "string" ?
        newComment.userName.trim() :
        null;
      const commenterName = commenter?.name || fallbackName || "Partnerin";

      const memoryTitleRaw = typeof afterData.title === "string" ?
        afterData.title.trim() :
        "";
      const memoryTitle = memoryTitleRaw.length ? memoryTitleRaw : null;
      const commentTextRaw = typeof newComment.text === "string" ?
        newComment.text.trim() :
        "";
      const commentPreview = truncate(commentTextRaw, 140);
      const body =
          buildNotificationBody([
            memoryTitle,
            commentPreview,
          ]) || commentPreview || memoryTitle || "Anına yeni bir yorum var.";

      const commentId = typeof newComment.id === "string" ?
        newComment.id :
        undefined;

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${commenterName} anına yorum yaptı`,
          body,
        },
        data: {
          type: "memory_comment",
          memoryId: context.params.memoryId,
          relationshipId: afterData.relationshipId,
          commentedBy: commenterId,
          commentId,
        },
      });
    });

exports.onPhotoCreated = functions.firestore
    .document("photos/{photoId}")
    .onCreate(async (snapshot, context) => {
      const photo = snapshot.data();
      if (!photo?.relationshipId || !photo?.uploadedBy) {
        return null;
      }

      const relationship = await fetchRelationship(photo.relationshipId);
      if (!relationship) {
        return null;
      }

      const partnerId = relationship.user1Id === photo.uploadedBy ?
        relationship.user2Id :
        relationship.user1Id;
      if (!partnerId || partnerId === photo.uploadedBy) {
        return null;
      }

      const users = await loadUsers([photo.uploadedBy]);
      const uploader = users.get(photo.uploadedBy);
      const uploaderName = uploader?.name || "Partnerin";
      const body =
          buildNotificationBody([
            photo.title,
            photo.location,
          ]) || "Hemen fotoğrafa bak!";

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: `${uploaderName} yeni bir fotoğraf ekledi`,
          body,
        },
        data: {
          type: "photo_new",
          photoId: context.params.photoId,
          relationshipId: photo.relationshipId,
          uploadedBy: photo.uploadedBy,
        },
      });
    });

exports.onNoteCreated = functions.firestore
    .document("notes/{noteId}")
    .onCreate(async (snapshot, context) => {
      const note = snapshot.data();
      if (!note?.relationshipId || !note?.createdBy) {
        return null;
      }

      const relationship = await fetchRelationship(note.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      const recipients = members.filter((id) => id !== note.createdBy);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([note.createdBy]);
      const creator = users.get(note.createdBy);
      const creatorName = creator?.name || "Partnerin";

      const contentPreview = truncate(note.content, 140);
      const contentPreviewPart =
          contentPreview && contentPreview !== note.title ?
          contentPreview :
          null;
      const body =
          buildNotificationBody([
            note.title,
            contentPreviewPart,
          ]) || "Yeni bir not bıraktı.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${creatorName} sana bir not bıraktı`,
          body,
        },
        data: {
          type: "note_new",
          noteId: context.params.noteId,
          relationshipId: note.relationshipId,
          createdBy: note.createdBy,
        },
      });
    });

exports.onSongCreated = functions.firestore
    .document("songs/{songId}")
    .onCreate(async (snapshot, context) => {
      const song = snapshot.data();
      if (!song?.relationshipId || !song?.addedBy) {
        return null;
      }

      const relationship = await fetchRelationship(song.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      const recipients = members.filter((id) => id !== song.addedBy);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([song.addedBy]);
      const adder = users.get(song.addedBy);
      const adderName = adder?.name || "Partnerin";

      const notePreview = truncate(song.note, 140);
      const headline = buildNotificationBody([
        song.title,
        song.artist,
      ]);

      const body =
          buildNotificationBody([
            headline,
            notePreview,
          ]) ||
          notePreview ||
          "Birlikte dinlemek için yeni bir şarkı ekledi.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${adderName} yeni bir şarkı ekledi`,
          body,
        },
        data: {
          type: "song_new",
          songId: context.params.songId,
          relationshipId: song.relationshipId,
          addedBy: song.addedBy,
        },
      });
    });

exports.onMovieCreated = functions.firestore
    .document("movies/{movieId}")
    .onCreate(async (snapshot, context) => {
      const movie = snapshot.data();
      if (!movie?.relationshipId || !movie?.addedBy) {
        return null;
      }

      const relationship = await fetchRelationship(movie.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      const recipients = members.filter((id) => id !== movie.addedBy);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([movie.addedBy]);
      const adder = users.get(movie.addedBy);
      const adderName = adder?.name || "Partnerin";

      const ratingText = movie.rating ? `Puan: ${movie.rating}/5` : null;
      const body =
          buildNotificationBody([
            movie.title,
            ratingText,
            formatDateTime(movie.watchedDate),
            truncate(movie.notes, 140),
          ]) || "Listemize yeni bir film ekledi.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${adderName} yeni bir film ekledi`,
          body,
        },
        data: {
          type: "movie_new",
          movieId: context.params.movieId,
          relationshipId: movie.relationshipId,
          addedBy: movie.addedBy,
        },
      });
    });

exports.onPlaceCreated = functions.firestore
    .document("places/{placeId}")
    .onCreate(async (snapshot, context) => {
      const place = snapshot.data();
      if (!place?.relationshipId || !place?.addedBy) {
        return null;
      }

      const relationship = await fetchRelationship(place.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      const recipients = members.filter((id) => id !== place.addedBy);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([place.addedBy]);
      const adder = users.get(place.addedBy);
      const adderName = adder?.name || "Partnerin";

      const body =
          buildNotificationBody([
            place.name,
            place.address,
            truncate(place.note, 140),
          ]) || "Beraber keşfetmek için yeni bir yer ekledi.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${adderName} yeni bir yer ekledi`,
          body,
        },
        data: {
          type: "place_new",
          placeId: context.params.placeId,
          relationshipId: place.relationshipId,
          addedBy: place.addedBy,
        },
      });
    });

exports.onSecretVaultItemCreated = functions.firestore
    .document("secretVault/{itemId}")
    .onCreate(async (snapshot, context) => {
      const item = snapshot.data();
      if (!item?.relationshipId || !item?.uploadedBy) {
        return null;
      }

      const relationship = await fetchRelationship(item.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      const recipients = members.filter((id) => id !== item.uploadedBy);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([item.uploadedBy]);
      const uploader = users.get(item.uploadedBy);
      const uploaderName = uploader?.name || "Partnerin";

      const mediaType = typeof item.type === "string" &&
        item.type.toLowerCase() === "video" ?
        "video" :
        "fotoğraf";
      const notePreview = truncate(item.note, 140);
      const body =
          buildNotificationBody([
            item.title,
            notePreview,
          ]) || `Gizli kasaya yeni ${mediaType} ekledi.`;

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${uploaderName} gizli kasaya yeni ${mediaType} ekledi`,
          body,
        },
        data: {
          type: "secret_vault_new",
          itemId: context.params.itemId,
          relationshipId: item.relationshipId,
          uploadedBy: item.uploadedBy,
          mediaType: mediaType,
        },
      });
    });

exports.onSurpriseCreated = functions.firestore
    .document("surprises/{surpriseId}")
    .onCreate(async (snapshot, context) => {
      const surprise = snapshot.data();
      if (!surprise?.relationshipId) {
        return null;
      }

      const relationship = await fetchRelationship(surprise.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      if (!members.length) {
        return null;
      }

      const users = await loadUsers([surprise.createdBy, surprise.createdFor]);
      const creator = users.get(surprise.createdBy);
      const creatorName = creator?.name || "Partnerin";

      const baseRecipients = surprise.createdFor ?
        [surprise.createdFor] :
        members;
      const recipients = baseRecipients
          .filter((id) => id && id !== surprise.createdBy);
      if (!recipients.length) {
        return null;
      }

      const revealHint = describeTimeUntil(surprise.revealDate);
      const body =
          buildNotificationBody([
            surprise.title,
            revealHint,
          ]) || "Sana özel yeni bir sürpriz hazırlandı.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${creatorName} sana bir sürpriz hazırladı 🎁`,
          body,
        },
        data: {
          type: "surprise_new",
          surpriseId: context.params.surpriseId,
          relationshipId: surprise.relationshipId,
          createdBy: surprise.createdBy,
          createdFor: surprise.createdFor,
        },
      });
    });

exports.onStoryCreated = functions.firestore
    .document("stories/{storyId}")
    .onCreate(async (snapshot, context) => {
      const story = snapshot.data();
      if (!story?.relationshipId || !story?.createdBy) {
        return null;
      }

      const relationship = await fetchRelationship(story.relationshipId);
      if (!relationship) {
        return null;
      }

      const partnerId = relationship.user1Id === story.createdBy ?
        relationship.user2Id :
        relationship.user1Id;
      if (!partnerId || partnerId === story.createdBy) {
        return null;
      }

      const creatorName = story.createdByName || "Partnerin";

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: `${creatorName} yeni bir story paylaştı`,
          body: "Story'yi açmak için dokun.",
        },
        data: {
          type: "story_new",
          storyId: context.params.storyId,
          relationshipId: story.relationshipId,
          createdBy: story.createdBy,
        },
      });
    });

exports.onStoryLike = functions.firestore
    .document("stories/{storyId}")
    .onWrite(async (change, context) => {
      const beforeData = change.before.exists ? change.before.data() : {};
      const afterData = change.after.exists ? change.after.data() : null;

      if (!afterData) {
        return null;
      }

      const beforeLikes = new Set(beforeData.likedBy || []);
      const afterLikes = new Set(afterData.likedBy || []);

      const newLikes = Array.from(afterLikes).filter((userId) => {
        return !beforeLikes.has(userId) && userId !== afterData.createdBy;
      });

      if (!newLikes.length) {
        return null;
      }

      const storyOwnerId = afterData.createdBy;
      if (!storyOwnerId) {
        return null;
      }

      const users = await loadUsers(newLikes);
      const liker = users.get(newLikes[0]);
      const likerName = liker?.name || "Partnerin";

      return sendPushToUsers({
        userIds: [storyOwnerId],
        notification: {
          title: `${likerName} hikayeni beğendi`,
          body: "Story'ine yeniden göz at!",
        },
        data: {
          type: "story_like",
          storyId: context.params.storyId,
          likedBy: newLikes[0],
          relationshipId: afterData.relationshipId,
        },
      });
    });

exports.onMoodStatusChanged = functions.firestore
    .document("moodStatuses/{statusId}")
    .onWrite(async (change, context) => {
      const beforeData = change.before.exists ? change.before.data() : null;
      const afterData = change.after.exists ? change.after.data() : null;

      if (!afterData) {
        return null;
      }

      const afterMood = afterData.mood;
      if (!afterMood) {
        return null;
      }

      const beforeMood = beforeData?.mood;
      if (beforeMood === afterMood) {
        return null;
      }

      const relationshipId = afterData.relationshipId;
      const userId = afterData.userId;
      if (!relationshipId || !userId) {
        return null;
      }

      const relationship = await fetchRelationship(relationshipId);
      if (!relationship) {
        return null;
      }

      const recipients = getRelationshipUserIds(relationship)
          .filter((id) => id && id !== userId);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([userId]);
      const updatedUser = users.get(userId);
      const updaterName = updatedUser?.name || "Partnerin";

      const moodInfo = describeMood(afterMood);
      const emojiSuffix = moodInfo.emoji ? ` ${moodInfo.emoji}` : "";
      const body = moodInfo.title ?
        `Yeni mod: ${moodInfo.title}${emojiSuffix}` :
        "Partnerinin ruh halini gör.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${updaterName} ruh halini güncelledi${emojiSuffix}`,
          body,
        },
        data: {
          type: "mood_update",
          statusId: context.params.statusId,
          relationshipId,
          updatedBy: userId,
          mood: afterMood,
          moodTitle: moodInfo.title || "",
          moodEmoji: moodInfo.emoji || "",
        },
      });
    });

exports.onMessageCreated = functions.firestore
    .document("messages/{messageId}")
    .onCreate(async (snapshot, context) => {
      const message = snapshot.data();
      if (!message?.relationshipId || !message?.senderId) {
        return null;
      }

      const relationship = await fetchRelationship(message.relationshipId);
      if (!relationship) {
        return null;
      }

      const partnerId = relationship.user1Id === message.senderId ?
        relationship.user2Id :
        relationship.user1Id;
      if (!partnerId || partnerId === message.senderId) {
        return null;
      }

      const fallbackText = message.imageURL ?
        "Yeni bir fotoğraf gönderdi" :
        "Yeni bir mesajın var";
      const preview = message.text || fallbackText;
      const body = preview.length > 120 ?
        `${preview.substring(0, 117)}...` :
        preview;
      const senderName = message.senderName || "Partnerin";

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: `${senderName} sana mesaj gönderdi`,
          body,
        },
        data: {
          type: "message_new",
          messageId: context.params.messageId,
          relationshipId: message.relationshipId,
          senderId: message.senderId,
        },
      });
    });

exports.onPlanCreated = functions.firestore
    .document("plans/{planId}")
    .onCreate(async (snapshot, context) => {
      const plan = snapshot.data();
      if (!plan?.relationshipId) {
        return null;
      }

      const relationship = await fetchRelationship(plan.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      const recipients = members.filter((id) => id !== plan.createdBy);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([plan.createdBy]);
      const creator = users.get(plan.createdBy);
      const creatorName = creator?.name || "Partnerin";
      const body =
          buildNotificationBody([
            plan.title,
            formatDateTime(plan.date),
          ]) || "Yeni plan detaylarını incele.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${creatorName} yeni bir plan ekledi`,
          body,
        },
        data: {
          type: "plan_new",
          planId: context.params.planId,
          relationshipId: plan.relationshipId,
          createdBy: plan.createdBy,
        },
      });
    });

exports.onPlanUpdated = functions.firestore
    .document("plans/{planId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      if (!afterData?.relationshipId) {
        return null;
      }

      const relationship = await fetchRelationship(afterData.relationshipId);
      if (!relationship) {
        return null;
      }

      const members = getRelationshipUserIds(relationship);
      if (!members.length) {
        return null;
      }

      const changes = [];
      if (beforeData.title !== afterData.title) {
        changes.push("Başlık güncellendi");
      }

      const beforeDate = toDate(beforeData.date);
      const afterDate = toDate(afterData.date);
      if ((beforeDate?.getTime() || 0) !== (afterDate?.getTime() || 0)) {
        const formatted = formatDateTime(afterData.date);
        changes.push(`Tarih ${formatted || "güncellendi"}`);
      }

      if ((beforeData.description || "") !== (afterData.description || "")) {
        changes.push("Notlar güncellendi");
      }

      if (beforeData.isCompleted !== afterData.isCompleted) {
        changes.push(
            afterData.isCompleted ? "Plan tamamlandı" : "Plan yeniden açıldı",
        );
      }

      if (beforeData.reminderEnabled !== afterData.reminderEnabled) {
        changes.push(
            afterData.reminderEnabled ?
            "Hatırlatıcılar açıldı" :
            "Hatırlatıcılar kapatıldı",
        );
      }

      if (!changes.length) {
        return null;
      }

      const actorId = afterData.updatedBy || afterData.lastUpdatedBy;
      const recipients = actorId ?
        members.filter((id) => id !== actorId) :
        members;

      const body =
          buildNotificationBody(changes) || "Plan üzerinde değişiklik var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `Plan güncellendi: ${afterData.title || "Yeni plan"}`,
          body,
        },
        data: {
          type: "plan_update",
          planId: context.params.planId,
          relationshipId: afterData.relationshipId,
        },
      });
    });

exports.dispatchPlanReminders = functions.pubsub
    .schedule("every 1 hours")
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
      const now = new Date();
      const nowTimestamp = admin.firestore.Timestamp.fromDate(now);
      const upcomingWindow = new Date(now.getTime() + 6 * 60 * 60 * 1000);
      const upcomingTimestamp = admin.firestore.Timestamp.fromDate(
          upcomingWindow,
      );

      const snapshot = await firestore.collection("plans")
          .where("reminderEnabled", "==", true)
          .where("isCompleted", "==", false)
          .where("date", ">=", nowTimestamp)
          .where("date", "<=", upcomingTimestamp)
          .orderBy("date")
          .limit(200)
          .get();

      if (snapshot.empty) {
        return null;
      }

      for (const doc of snapshot.docs) {
        const plan = doc.data();
        const planDate = toDate(plan.date);
        if (!planDate) {
          continue;
        }

        const lastSent = toDate(plan.reminderLastSentAt);
        if (lastSent &&
          now.getTime() - lastSent.getTime() < 60 * 60 * 1000) {
          continue;
        }

        const relationship = await fetchRelationship(plan.relationshipId);
        if (!relationship) {
          continue;
        }

        const members = getRelationshipUserIds(relationship);
        if (!members.length) {
          continue;
        }

        const body =
            buildNotificationBody([
              plan.title,
              describeTimeUntil(planDate, now),
              formatDateTime(plan.date),
            ]) || "Yaklaşan planı kaçırma.";

        await sendPushToUsers({
          userIds: members,
          notification: {
            title: "Yaklaşan plan hatırlatıcısı",
            body,
          },
          data: {
            type: "plan_reminder",
            planId: doc.id,
            relationshipId: plan.relationshipId,
          },
        });

        await doc.ref.update({
          reminderLastSentAt: fieldValue.serverTimestamp(),
        });
      }
      return null;
    });

exports.dispatchSpecialDayReminders = functions.pubsub
    .schedule("every day 07:00")
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
      const now = new Date();
      const snapshot = await firestore.collection("specialDays")
          .limit(500)
          .get();

      if (snapshot.empty) {
        return null;
      }

      for (const doc of snapshot.docs) {
        const specialDay = doc.data();
        if (!specialDay?.relationshipId) {
          continue;
        }

        const targetDate = computeNextSpecialDayDate(specialDay, now);
        if (!targetDate) {
          continue;
        }

        const msUntil = targetDate.getTime() - now.getTime();
        const daysUntil = Math.floor(msUntil / (1000 * 60 * 60 * 24));
        if (daysUntil < 0 || daysUntil > 7) {
          continue;
        }

        const reminderKey = createDateKey(targetDate);
        if (specialDay.lastReminderKey === reminderKey) {
          continue;
        }

        const relationship = await fetchRelationship(specialDay.relationshipId);
        if (!relationship) {
          continue;
        }

        const members = getRelationshipUserIds(relationship);
        if (!members.length) {
          continue;
        }

        const timeHint = daysUntil === 0 ?
          "Bugün" :
          `${daysUntil} gün kaldı`;
        const body =
            buildNotificationBody([
              specialDay.title,
              timeHint,
            ]) || "Özel günün yaklaşıyor.";

        await sendPushToUsers({
          userIds: members,
          notification: {
            title: "Özel gün hatırlatıcısı",
            body,
          },
          data: {
            type: "special_day_reminder",
            specialDayId: doc.id,
            relationshipId: specialDay.relationshipId,
          },
        });

        await doc.ref.update({
          lastReminderKey: reminderKey,
          lastReminderAt: fieldValue.serverTimestamp(),
        });
      }
      return null;
    });
