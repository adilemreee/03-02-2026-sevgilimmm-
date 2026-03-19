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
const crypto = require("crypto");

admin.initializeApp();
const firestore = admin.firestore();
const fieldValue = admin.firestore.FieldValue;

const defaultNotificationPreferences = Object.freeze({
  chat: true,
  memory: true,
  plan: true,
  specialDay: true,
});

const notificationPreferenceByType = Object.freeze({
  message_new: "chat",
  story_reply: "chat",
  memory_new: "memory",
  memory_comment: "memory",
  memory_like: "memory",
  photo_added: "memory",
  photo_new: "memory",
  note_shared: "memory",
  note_new: "memory",
  note_update: "memory",
  song_shared: "memory",
  song_new: "memory",
  movie_new: "memory",
  place_recommendation: "memory",
  place_new: "memory",
  secret_vault_alert: "memory",
  secret_vault_new: "memory",
  story_new: "memory",
  story_like: "memory",
  mood_update: "memory",
  on_this_day_memory: "memory",
  plan_new: "plan",
  plan_update: "plan",
  plan_completed: "plan",
  plan_reminder: "plan",
  plan_tomorrow: "plan",
  surprise_new: "plan",
  surprise_opened: "plan",
  surprise_reveal_due: "plan",
  inactive_couple_nudge: "plan",
  special_day_upcoming: "specialDay",
  special_day_plan_missing: "specialDay",
  special_day_surprise_missing: "specialDay",
  special_day_new: "specialDay",
  special_day_update: "specialDay",
  special_day_reminder: "specialDay",
});

const specialDayReminderStages = Object.freeze([30, 14, 3, 1, 0]);
const specialDayUpcomingLeadDays = 7;
const specialDayPlanMissingStages = Object.freeze([3, 1]);
const specialDaySurpriseMissingStages = Object.freeze([3]);
const surpriseReminderStages = Object.freeze([0, 1, 3, 24]);
const fallbackLovedOneName = "Aşkın";
const defaultNotificationCooldownSeconds = 5 * 60;
const notificationCooldownSecondsByType = Object.freeze({
  message_new: 90,
  story_reply: 90,
  memory_comment: 180,
  memory_like: 180,
  note_update: 15 * 60,
  plan_update: 15 * 60,
  mood_update: 15 * 60,
  plan_reminder: 60 * 60,
  plan_tomorrow: 12 * 60 * 60,
  surprise_reveal_due: 6 * 60 * 60,
  special_day_upcoming: 12 * 60 * 60,
  special_day_plan_missing: 12 * 60 * 60,
  special_day_surprise_missing: 12 * 60 * 60,
  special_day_reminder: 12 * 60 * 60,
  on_this_day_memory: 12 * 60 * 60,
  inactive_couple_nudge: 24 * 60 * 60,
});
const genericNotificationIdentityKeys = Object.freeze([
  "memoryId",
  "photoId",
  "noteId",
  "songId",
  "movieId",
  "placeId",
  "itemId",
  "planId",
  "specialDayId",
  "surpriseId",
  "storyId",
  "messageId",
  "statusId",
  "commentId",
  "relationshipId",
]);
const notificationIdentityKeysByType = Object.freeze({
  message_new: ["relationshipId", "senderId"],
  story_reply: ["relationshipId", "senderId", "storyId"],
  memory_comment: ["memoryId", "commentedBy", "commentId"],
  memory_like: ["memoryId", "likedBy"],
  mood_update: ["relationshipId", "updatedBy", "mood"],
  plan_reminder: ["planId", "relationshipId"],
  plan_tomorrow: ["planId", "reminderKey"],
  special_day_upcoming: ["specialDayId", "reminderKey"],
  special_day_plan_missing: ["specialDayId", "reminderKey"],
  special_day_surprise_missing: ["specialDayId", "reminderKey"],
  special_day_reminder: ["specialDayId", "reminderKey"],
  surprise_reveal_due: ["surpriseId", "reminderKey"],
  on_this_day_memory: ["memoryId", "dateKey", "relationshipId"],
  inactive_couple_nudge: ["relationshipId", "weekKey"],
});

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

const normaliseNotificationPreferences = (value) => {
  const raw = value && typeof value === "object" ? value : {};
  return {
    chat: typeof raw.chat === "boolean" ?
      raw.chat :
      defaultNotificationPreferences.chat,
    memory: typeof raw.memory === "boolean" ?
      raw.memory :
      defaultNotificationPreferences.memory,
    plan: typeof raw.plan === "boolean" ?
      raw.plan :
      defaultNotificationPreferences.plan,
    specialDay: typeof raw.specialDay === "boolean" ?
      raw.specialDay :
      defaultNotificationPreferences.specialDay,
  };
};

const getNotificationPreferenceKey = (type) => {
  if (typeof type !== "string" || !type.trim()) {
    return null;
  }
  return notificationPreferenceByType[type.trim().toLowerCase()] || null;
};

const getNotificationCooldownSeconds = (type) => {
  if (typeof type !== "string" || !type.trim()) {
    return 0;
  }

  const normalisedType = type.trim().toLowerCase();
  if (Object.prototype.hasOwnProperty.call(
      notificationCooldownSecondsByType,
      normalisedType,
  )) {
    return notificationCooldownSecondsByType[normalisedType];
  }

  return defaultNotificationCooldownSeconds;
};

const appendFingerprintParts = (parts, metadata = {}, keys = []) => {
  keys.forEach((key) => {
    const value = metadata[key];
    if (value === undefined || value === null) {
      return;
    }

    const stringValue = String(value).trim();
    if (!stringValue.length) {
      return;
    }

    parts.push(`${key}=${stringValue}`);
  });
};

const buildNotificationCooldownFingerprint = (metadata = {}) => {
  const type = typeof metadata?.type === "string" ?
    metadata.type.trim().toLowerCase() :
    "";
  if (!type) {
    return null;
  }

  const parts = [`type=${type}`];
  const preferredKeys = notificationIdentityKeysByType[type] ||
    genericNotificationIdentityKeys;

  appendFingerprintParts(parts, metadata, preferredKeys);

  if (parts.length === 1) {
    appendFingerprintParts(parts, metadata, genericNotificationIdentityKeys);
  }

  return parts.join("|");
};

const buildNotificationCooldownDocId = (fingerprint) => {
  return crypto.createHash("sha1").update(fingerprint).digest("hex");
};

const normaliseTokens = (tokens = []) => {
  const list = Array.isArray(tokens) ? tokens : [tokens];
  const filtered = list.filter((token) => {
    return typeof token === "string" && token.trim().length > 0;
  });
  return Array.from(new Set(filtered));
};

const selectTokenOwnersForUsers = ({userIds = [], tokenOwners = new Map()}) => {
  const allowedUserIds = new Set(userIds);
  const filteredTokenOwners = new Map();

  tokenOwners.forEach((owners, token) => {
    const filteredOwners = Array.from(owners).filter((userId) => {
      return allowedUserIds.has(userId);
    });

    if (filteredOwners.length) {
      filteredTokenOwners.set(token, new Set(filteredOwners));
    }
  });

  return {
    tokens: Array.from(filteredTokenOwners.keys()),
    tokenOwners: filteredTokenOwners,
  };
};

const mergeApnsPayload = (message = {}, {badge} = {}) => {
  const apns = {...(message.apns || {})};
  const payload = {...(apns.payload || {})};
  const aps = {...(payload.aps || {})};
  if (typeof aps.sound !== "string" || !aps.sound.trim()) {
    aps.sound = "default";
  }
  if (typeof badge === "number") {
    aps.badge = badge;
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

const applyDefaultApns = (message = {}, options = {}) => {
  return mergeApnsPayload(message, options);
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

const resolveDisplayName = (...values) => {
  for (const value of values) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return fallbackLovedOneName;
};

const countUnreadMessages = async ({relationshipId, senderId}) => {
  if (!relationshipId || !senderId) {
    return null;
  }

  try {
    const snapshot = await firestore.collection("messages")
        .where("relationshipId", "==", relationshipId)
        .where("senderId", "==", senderId)
        .where("isRead", "==", false)
        .get();
    return snapshot.size;
  } catch (error) {
    if (error?.code === 9 || error?.code === "failed-precondition") {
      logger.warn("Missing index for unread message count query.", {
        relationshipId,
        senderId,
        error: error.message,
      });
    } else {
      logger.error("Failed to count unread messages.", {
        relationshipId,
        senderId,
        error,
      });
    }
    return null;
  }
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

const collectTokensForUsers = async (userIds = [], preferenceKey = null) => {
  const userMap = await loadUsers(userIds);
  const tokens = [];
  const tokenOwners = new Map();
  const matchedUserIds = [];

  userMap.forEach((user, userId) => {
    if (preferenceKey) {
      const preferences = normaliseNotificationPreferences(
          user.notificationPreferences,
      );
      if (!preferences[preferenceKey]) {
        return;
      }
    }

    matchedUserIds.push(userId);
    const userTokens = normaliseTokens(user.fcmTokens || user.fcmToken || []);
    userTokens.forEach((token) => {
      tokens.push(token);
      if (!tokenOwners.has(token)) {
        tokenOwners.set(token, new Set());
      }
      tokenOwners.get(token).add(userId);
    });
  });

  return {
    tokens: normaliseTokens(tokens),
    tokenOwners,
    matchedUserIds,
  };
};

const getRelationshipUserIds = (relationship) => {
  if (!relationship) {
    return [];
  }
  const ids = [relationship.user1Id, relationship.user2Id].filter((id) => id);
  return Array.from(new Set(ids));
};

const moodDetails = {
  happy: {title: "aşkımmmmm aşırıı mutluyumm", emoji: "😊"},
  missing: {title: "Çokkk aşırııı özledim", emoji: "🥺"},
  sad: {title: "Üzgüntülüyüm", emoji: "😔"},
  excited: {title: "kalbim kıpır kıpırr", emoji: "🤩"},
  tired: {title: "Yorgunumm aşkım", emoji: "🥱"},
  love: {title: "Aşığımm sana", emoji: "😍"},
  horny: {title: "azgıntıyım bayılcam...", emoji: "😈"},
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

const pad2 = (value) => String(value).padStart(2, "0");

const startOfDay = (value) => {
  const date = toDate(value);
  if (!date) {
    return null;
  }
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
};

const differenceInCalendarDays = (targetDate, baseDate = new Date()) => {
  const target = startOfDay(targetDate);
  const base = startOfDay(baseDate);
  if (!target || !base) {
    return null;
  }
  const diffMs = target.getTime() - base.getTime();
  return Math.round(diffMs / (1000 * 60 * 60 * 24));
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

const formatDateOnly = (value) => {
  const date = toDate(value);
  if (!date) {
    return null;
  }

  try {
    const formatter = new Intl.DateTimeFormat("tr-TR", {
      day: "numeric",
      month: "long",
    });
    return formatter.format(date);
  } catch (error) {
    logger.warn("Failed to format date only.", {error});
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
  return `${value.getFullYear()}-${pad2(value.getMonth() + 1)}-${pad2(
      value.getDate(),
  )}`;
};

const createWeekKey = (date) => {
  const value = startOfDay(date);
  if (!value) {
    return null;
  }

  const day = value.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  const monday = new Date(
      value.getFullYear(),
      value.getMonth(),
      value.getDate() + diff,
  );
  return createDateKey(monday);
};

const computeNextSpecialDayDate = (specialDay, now = new Date()) => {
  const baseDate = toDate(specialDay?.date);
  if (!baseDate) {
    return null;
  }

  if (!specialDay.isRecurring) {
    return baseDate;
  }

  const today = startOfDay(now);
  const candidate = new Date(
      now.getFullYear(),
      baseDate.getMonth(),
      baseDate.getDate(),
      12,
  );

  if (today && startOfDay(candidate) < today) {
    return new Date(
        now.getFullYear() + 1,
        baseDate.getMonth(),
        baseDate.getDate(),
        12,
    );
  }
  return candidate;
};

const getSpecialDayReminderStage = (daysUntil) => {
  if (typeof daysUntil !== "number") {
    return null;
  }
  return specialDayReminderStages.includes(daysUntil) ? `${daysUntil}d` : null;
};

const getSpecialDayPlanMissingStage = (daysUntil) => {
  if (typeof daysUntil !== "number") {
    return null;
  }
  return specialDayPlanMissingStages.includes(daysUntil) ?
    `${daysUntil}d` :
    null;
};

const getSpecialDaySurpriseMissingStage = (daysUntil) => {
  if (typeof daysUntil !== "number") {
    return null;
  }
  return specialDaySurpriseMissingStages.includes(daysUntil) ?
    `${daysUntil}d` :
    null;
};

const describeSpecialDayCountdown = (daysUntil) => {
  if (daysUntil === 0) {
    return "Bugün";
  }
  if (daysUntil === 1) {
    return "Yarın";
  }
  return `${daysUntil} gün kaldı`;
};

const hasNearbyScheduledDate = (dates = [], targetDate) => {
  return dates.some((scheduledDate) => {
    const difference = differenceInCalendarDays(scheduledDate, targetDate);
    return typeof difference === "number" && Math.abs(difference) <= 1;
  });
};

const getSurpriseReminderStage = (hoursUntil) => {
  if (typeof hoursUntil !== "number" || hoursUntil < 0) {
    return null;
  }

  for (const stage of surpriseReminderStages) {
    if (hoursUntil <= stage) {
      return `${stage}h`;
    }
  }

  return null;
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

const buildDeliveryStateByUser = ({
  userIds = [],
  tokenOwners = new Map(),
  tokens = [],
  response = null,
}) => {
  const states = new Map();

  userIds.forEach((userId) => {
    states.set(userId, {
      deliveryState: "inbox_only",
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
    });
  });

  tokenOwners.forEach((owners) => {
    owners.forEach((userId) => {
      if (!states.has(userId)) {
        states.set(userId, {
          deliveryState: "inbox_only",
          tokenCount: 0,
          successCount: 0,
          failureCount: 0,
        });
      }
      states.get(userId).tokenCount += 1;
    });
  });

  if (response) {
    tokens.forEach((token, index) => {
      const owners = tokenOwners.get(token);
      if (!owners) {
        return;
      }

      owners.forEach((userId) => {
        const state = states.get(userId);
        if (!state) {
          return;
        }

        if (response.responses[index]?.success) {
          state.successCount += 1;
        } else {
          state.failureCount += 1;
        }
      });
    });
  }

  states.forEach((state) => {
    if (state.tokenCount === 0) {
      state.deliveryState = "inbox_only";
      return;
    }

    if (state.successCount > 0) {
      state.deliveryState = "sent";
      return;
    }

    if (response && state.failureCount >= state.tokenCount) {
      state.deliveryState = "failed";
      return;
    }

    state.deliveryState = "queued";
  });

  return states;
};

const claimNotificationCooldownForUsers = async ({
  userIds = [],
  metadata = {},
}) => {
  const fingerprint = buildNotificationCooldownFingerprint(metadata);
  const cooldownSeconds = getNotificationCooldownSeconds(metadata?.type);

  if (!fingerprint || cooldownSeconds <= 0 || !userIds.length) {
    return {
      allowedUserIds: userIds,
      suppressedUserIds: [],
      cooldownSeconds,
      fingerprint,
    };
  }

  const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + cooldownSeconds * 1000),
  );

  const results = await Promise.all(userIds.map(async (userId) => {
    const ref = firestore.collection("users")
        .doc(userId)
        .collection("notificationCooldowns")
        .doc(buildNotificationCooldownDocId(`${userId}|${fingerprint}`));

    try {
      const allowed = await firestore.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const currentExpiry = toDate(snapshot.get("expiresAt"));

        if (currentExpiry && currentExpiry.getTime() > Date.now()) {
          return false;
        }

        transaction.set(ref, {
          type: metadata.type || "unknown",
          fingerprint,
          relationshipId: metadata.relationshipId || null,
          lastSentAt: fieldValue.serverTimestamp(),
          expiresAt,
        }, {merge: true});
        return true;
      });

      return {userId, allowed};
    } catch (error) {
      logger.warn("Cooldown check failed, allowing notification.", {
        userId,
        type: metadata?.type,
        error: error.message,
      });
      return {userId, allowed: true};
    }
  }));

  return {
    allowedUserIds: results
        .filter((result) => result.allowed)
        .map((result) => result.userId),
    suppressedUserIds: results
        .filter((result) => !result.allowed)
        .map((result) => result.userId),
    cooldownSeconds,
    fingerprint,
  };
};

const persistNotificationHistory = async ({
  userIds = [],
  notification,
  metadata,
  deliveryStates = new Map(),
}) => {
  if (!userIds.length || !notification?.title || !notification?.body) {
    return;
  }

  const batch = firestore.batch();

  userIds.forEach((userId) => {
    const state = deliveryStates.get(userId) || {};
    const ref = firestore.collection("users")
        .doc(userId)
        .collection("notifications")
        .doc();

    const doc = {
      userId,
      type: metadata?.type || "unknown",
      title: notification.title,
      body: notification.body,
      metadata: metadata || {},
      isRead: false,
      createdAt: fieldValue.serverTimestamp(),
      deliveryState: state.deliveryState || "inbox_only",
      tokenCount: state.tokenCount || 0,
      successCount: state.successCount || 0,
      failureCount: state.failureCount || 0,
    };

    if (metadata?.relationshipId) {
      doc.relationshipId = metadata.relationshipId;
    }

    batch.set(ref, doc);
  });

  try {
    await batch.commit();
  } catch (error) {
    logger.error("Failed to persist notification history.", {
      userIds,
      type: metadata?.type,
      error,
    });
  }
};

const isUnreadNotificationDocument = (data) => {
  return !!data && data.isRead !== true;
};

const sendPushToUsers = async ({
  userIds = [],
  notification,
  data,
  badge,
  preferenceKey,
}) => {
  if (!notification || !notification.title || !notification.body) {
    throw new Error("Notification title and body are required.");
  }

  const resolvedPreferenceKey =
      preferenceKey || getNotificationPreferenceKey(data?.type);
  const {tokenOwners, matchedUserIds} = await collectTokensForUsers(
      userIds,
      resolvedPreferenceKey,
  );
  const cleanData = sanitiseData(data);

  if (!matchedUserIds.length) {
    logger.info("No eligible recipients found for notification.", {
      userIds,
      preferenceKey: resolvedPreferenceKey,
      type: cleanData?.type,
    });
    return null;
  }

  const {
    allowedUserIds,
    suppressedUserIds,
  } = await claimNotificationCooldownForUsers({
    userIds: matchedUserIds,
    metadata: cleanData,
  });

  if (!allowedUserIds.length) {
    logger.info("Notification suppressed by cooldown.", {
      userIds: matchedUserIds,
      suppressedUserIds,
      type: cleanData?.type,
    });
    return null;
  }

  const {
    tokens: filteredTokens,
    tokenOwners: filteredTokenOwners,
  } = selectTokenOwnersForUsers({
    userIds: allowedUserIds,
    tokenOwners,
  });

  if (!filteredTokens.length) {
    await persistNotificationHistory({
      userIds: allowedUserIds,
      notification,
      metadata: cleanData,
      deliveryStates: buildDeliveryStateByUser({
        userIds: allowedUserIds,
        tokenOwners: filteredTokenOwners,
        tokens: filteredTokens,
      }),
    });

    logger.info("No tokens found for users.", {
      userIds: allowedUserIds,
      preferenceKey: resolvedPreferenceKey,
    });
    return null;
  }

  const messaging = admin.messaging();

  const response = await messaging.sendEachForMulticast(
      applyDefaultApns({
        tokens: filteredTokens,
        notification,
        data: cleanData,
      }, {badge}),
  );

  if (response.failureCount > 0) {
    const failedTokens = response.responses.reduce((list, result, index) => {
      if (!result.success) {
        list.push(filteredTokens[index]);
      }
      return list;
    }, []);

    await pruneInvalidTokens(filteredTokenOwners, failedTokens);
  }

  await persistNotificationHistory({
    userIds: allowedUserIds,
    notification,
    metadata: cleanData,
    deliveryStates: buildDeliveryStateByUser({
      userIds: allowedUserIds,
      tokenOwners: filteredTokenOwners,
      tokens: filteredTokens,
      response,
    }),
  });

  logger.info("Push notification sent.", {
    title: notification.title,
    recipients: allowedUserIds,
    sent: response.successCount,
    failed: response.failureCount,
    preferenceKey: resolvedPreferenceKey,
  });

  return response;
};

exports.syncUnreadNotificationCount = functions.firestore
    .document("users/{userId}/notifications/{notificationId}")
    .onWrite(async (change, context) => {
      const beforeData = change.before.exists ? change.before.data() : null;
      const afterData = change.after.exists ? change.after.data() : null;
      const unreadBefore = isUnreadNotificationDocument(beforeData);
      const unreadAfter = isUnreadNotificationDocument(afterData);

      if (unreadBefore === unreadAfter) {
        return null;
      }

      const userId = context.params.userId;
      const userRef = firestore.collection("users").doc(userId);
      const delta = unreadAfter ? 1 : -1;

      try {
        await firestore.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(userRef);
          const currentRaw = snapshot.get("unreadNotificationCount");
          const currentCount = Number.isFinite(currentRaw) ? currentRaw : 0;
          const nextCount = Math.max(0, currentCount + delta);

          transaction.set(userRef, {
            unreadNotificationCount: nextCount,
            unreadNotificationCountUpdatedAt: fieldValue.serverTimestamp(),
          }, {merge: true});
        });
      } catch (error) {
        logger.error("Failed to sync unread notification count.", {
          userId,
          delta,
          error,
        });
      }

      return null;
    });

exports.sendPushNotification = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.set("Allow", "POST");
    return res.status(405).json({error: "Only POST is allowed."});
  }

  try {
    const payload = ensureJson(req.body);
    const {token, tokens, topic, title, body, data, badge} = payload;

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
          }, {badge}),
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
            }, {badge}),
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
      const creatorName = resolveDisplayName(creator?.name);
      const body =
          buildNotificationBody([
            memory.title,
            memory.location,
          ]) || "Yeni anıyı birlikte hatırlamak ister misin?";

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: `${creatorName} seninle yeni bir anı paylaştı`,
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
      const commenterName = resolveDisplayName(commenter?.name, fallbackName);

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
          ]) || commentPreview || memoryTitle || "Anına tatlı bir yorum geldi.";

      const commentId = typeof newComment.id === "string" ?
        newComment.id :
        undefined;

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${commenterName} anına bir şeyler yazdı`,
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

exports.onMemoryLiked = functions.firestore
    .document("memories/{memoryId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.exists ? change.before.data() : {};
      const afterData = change.after.exists ? change.after.data() : null;

      if (!afterData?.relationshipId || !afterData?.createdBy) {
        return null;
      }

      const beforeLikes = new Set(Array.isArray(beforeData?.likes) ?
        beforeData.likes :
        []);
      const afterLikes = new Set(Array.isArray(afterData?.likes) ?
        afterData.likes :
        []);

      const newLikes = Array.from(afterLikes).filter((userId) => {
        return !beforeLikes.has(userId) && userId !== afterData.createdBy;
      });
      if (!newLikes.length) {
        return null;
      }

      const likerId = newLikes[0];
      const users = await loadUsers([likerId]);
      const liker = users.get(likerId);
      const likerName = resolveDisplayName(liker?.name);
      const body =
          buildNotificationBody([
            afterData.title,
            "Kocaman bir kalp bıraktı",
          ]) || "Anına kocaman bir kalp geldi.";

      return sendPushToUsers({
        userIds: [afterData.createdBy],
        notification: {
          title: `${likerName} anına kalp bıraktı`,
          body,
        },
        data: {
          type: "memory_like",
          memoryId: context.params.memoryId,
          relationshipId: afterData.relationshipId,
          likedBy: likerId,
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
      const uploaderName = resolveDisplayName(uploader?.name);
      const body =
          buildNotificationBody([
            photo.title,
            photo.location,
          ]) || "Birlikte bakılacak yeni bir fotoğraf var.";

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: `${uploaderName} galerine yeni bir kare bıraktı`,
          body,
        },
        data: {
          type: "photo_added",
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
      const creatorName = resolveDisplayName(creator?.name);

      const contentPreview = truncate(note.content, 140);
      const contentPreviewPart =
          contentPreview && contentPreview !== note.title ?
          contentPreview :
          null;
      const body =
          buildNotificationBody([
            note.title,
            contentPreviewPart,
          ]) || "Sana içten bir not bıraktı.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${creatorName} sana tatlı bir not bıraktı`,
          body,
        },
        data: {
          type: "note_shared",
          noteId: context.params.noteId,
          relationshipId: note.relationshipId,
          createdBy: note.createdBy,
        },
      });
    });

exports.onNoteUpdated = functions.firestore
    .document("notes/{noteId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      if (!afterData?.relationshipId) {
        return null;
      }

      const changes = [];
      if ((beforeData.title || "") !== (afterData.title || "")) {
        changes.push("Başlık güncellendi");
      }

      if ((beforeData.content || "") !== (afterData.content || "")) {
        changes.push("İçerik güncellendi");
      }

      if (!changes.length) {
        return null;
      }

      const relationship = await fetchRelationship(afterData.relationshipId);
      if (!relationship) {
        return null;
      }

      const actorId = afterData.updatedBy || afterData.lastUpdatedBy;
      const recipients = actorId ?
        getRelationshipUserIds(relationship).filter((id) => id !== actorId) :
        getRelationshipUserIds(relationship);
      if (!recipients.length) {
        return null;
      }

      const updaterUsers = actorId ? await loadUsers([actorId]) : new Map();
      const updaterName = actorId ?
        resolveDisplayName(updaterUsers.get(actorId)?.name) :
        fallbackLovedOneName;
      const body =
          buildNotificationBody([
            afterData.title,
            changes.join(" • "),
          ]) || "Notta küçük bir değişiklik var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${updaterName} nota yeniden dokundu`,
          body,
        },
        data: {
          type: "note_update",
          noteId: context.params.noteId,
          relationshipId: afterData.relationshipId,
          updatedBy: actorId || "",
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
      const adderName = resolveDisplayName(adder?.name);

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
          "Birlikte dinlemek isteyebileceğin bir şarkı var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${adderName} size bir şarkı bıraktı`,
          body,
        },
        data: {
          type: "song_shared",
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
      const adderName = resolveDisplayName(adder?.name);

      const ratingText = movie.rating ? `Puan: ${movie.rating}/5` : null;
      const body =
          buildNotificationBody([
            movie.title,
            ratingText,
            formatDateTime(movie.watchedDate),
            truncate(movie.notes, 140),
          ]) || "Listenize yeni bir film düştü.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${adderName} birlikte izlemek için film ekledi`,
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
      const adderName = resolveDisplayName(adder?.name);

      const body =
          buildNotificationBody([
            place.name,
            place.address,
            truncate(place.note, 140),
          ]) || "Beraber keşfedilecek yeni bir yer var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${adderName} gidilecek güzel bir yer ekledi`,
          body,
        },
        data: {
          type: "place_recommendation",
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
      const uploaderName = resolveDisplayName(uploader?.name);

      const mediaType = typeof item.type === "string" &&
        item.type.toLowerCase() === "video" ?
        "video" :
        "fotoğraf";
      const notePreview = truncate(item.note, 140);
      const body =
          buildNotificationBody([
            item.title,
            notePreview,
          ]) || `Gizli kasada seni bekleyen yeni bir ${mediaType} var.`;

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${uploaderName} gizli kasaya bir şey bıraktı`,
          body,
        },
        data: {
          type: "secret_vault_alert",
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
      const creatorName = resolveDisplayName(creator?.name);

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
          ]) || "Açılacağı zamanı bekleyen bir sürpriz var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${creatorName} sana minicik bir sürpriz hazırladı 🎁`,
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

exports.onSurpriseOpened = functions.firestore
    .document("surprises/{surpriseId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      if (!afterData?.relationshipId || !afterData?.createdBy) {
        return null;
      }

      if (beforeData?.isOpened || !afterData.isOpened) {
        return null;
      }

      const recipients = [afterData.createdBy].filter((id) => {
        return id && id !== afterData.createdFor;
      });
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([afterData.createdFor]);
      const openerName = resolveDisplayName(
          users.get(afterData.createdFor)?.name,
      );
      const body =
          buildNotificationBody([
            afterData.title,
            afterData.openedAt ? formatDateTime(afterData.openedAt) : null,
          ]) || "Hazırladığın sürpriz açıldı.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${openerName} sürprizini açtı`,
          body,
        },
        data: {
          type: "surprise_opened",
          surpriseId: context.params.surpriseId,
          relationshipId: afterData.relationshipId,
          createdBy: afterData.createdBy,
          createdFor: afterData.createdFor,
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

      const creatorName = resolveDisplayName(story.createdByName);

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: `${creatorName} yeni bir an paylaştı`,
          body: "Bakmak için dokun.",
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
      const likerName = resolveDisplayName(liker?.name);

      return sendPushToUsers({
        userIds: [storyOwnerId],
        notification: {
          title: `${likerName} story'ne kalp bıraktı`,
          body: "Tatlı bir beğeni geldi.",
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
      const updaterName = resolveDisplayName(updatedUser?.name);

      const moodInfo = describeMood(afterMood);
      const emojiSuffix = moodInfo.emoji ? ` ${moodInfo.emoji}` : "";
      const body = moodInfo.title ?
        `Şu an şöyle hissediyor: ${moodInfo.title}${emojiSuffix}` :
        "Aşkının ruh haline bak.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${updaterName} ruh halini seninle paylaştı${emojiSuffix}`,
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
        "Sana bir fotoğraf gönderdi" :
        "Sana bir mesaj bıraktı";
      const preview = message.text || fallbackText;
      const body = preview.length > 120 ?
        `${preview.substring(0, 117)}...` :
        preview;
      const senderName = resolveDisplayName(message.senderName);
      const isStoryReply = typeof message.storyImageURL === "string" &&
        message.storyImageURL.trim().length > 0;
      const replyBody = message.text && message.text.trim().length ?
        message.text.trim() :
        "Story'ne cevap bıraktı.";
      const unreadCount = await countUnreadMessages({
        relationshipId: message.relationshipId,
        senderId: message.senderId,
      });
      const badgeCount = typeof unreadCount === "number" && unreadCount > 0 ?
        unreadCount :
        1;

      return sendPushToUsers({
        userIds: [partnerId],
        notification: {
          title: isStoryReply ?
            `${senderName} story'ne cevap verdi` :
            `${senderName} sana yazdı`,
          body: isStoryReply ? truncate(replyBody, 120) || replyBody : body,
        },
        data: {
          type: isStoryReply ? "story_reply" : "message_new",
          messageId: context.params.messageId,
          relationshipId: message.relationshipId,
          senderId: message.senderId,
          unreadCount: String(badgeCount),
        },
        badge: badgeCount,
      });
    });

exports.onSpecialDayCreated = functions.firestore
    .document("specialDays/{specialDayId}")
    .onCreate(async (snapshot, context) => {
      const specialDay = snapshot.data();
      if (!specialDay?.relationshipId || !specialDay?.createdBy) {
        return null;
      }

      const relationship = await fetchRelationship(specialDay.relationshipId);
      if (!relationship) {
        return null;
      }

      const recipients = getRelationshipUserIds(relationship)
          .filter((id) => id && id !== specialDay.createdBy);
      if (!recipients.length) {
        return null;
      }

      const users = await loadUsers([specialDay.createdBy]);
      const creator = users.get(specialDay.createdBy);
      const creatorName = resolveDisplayName(creator?.name);
      const targetDate = computeNextSpecialDayDate(specialDay);
      const daysUntil = differenceInCalendarDays(targetDate);
      const body =
          buildNotificationBody([
            specialDay.title,
            formatDateOnly(targetDate),
            typeof daysUntil === "number" && daysUntil >= 0 ?
              describeSpecialDayCountdown(daysUntil) :
              null,
          ]) || "Takviminize tatlı bir gün eklendi.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${creatorName} takviminize özel bir gün ekledi`,
          body,
        },
        data: {
          type: "special_day_new",
          specialDayId: context.params.specialDayId,
          relationshipId: specialDay.relationshipId,
          createdBy: specialDay.createdBy,
        },
      });
    });

exports.onSpecialDayUpdated = functions.firestore
    .document("specialDays/{specialDayId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      if (!afterData?.relationshipId) {
        return null;
      }

      const changes = [];
      if ((beforeData.title || "") !== (afterData.title || "")) {
        changes.push("Başlık güncellendi");
      }

      const beforeDate = computeNextSpecialDayDate(beforeData);
      const afterDate = computeNextSpecialDayDate(afterData);
      if (createDateKey(beforeDate) !== createDateKey(afterDate)) {
        changes.push(`Tarih ${formatDateOnly(afterDate) || "güncellendi"}`);
      }

      if ((beforeData.notes || "") !== (afterData.notes || "")) {
        changes.push("Notlar güncellendi");
      }

      if (!!beforeData.isRecurring !== !!afterData.isRecurring) {
        changes.push(
            afterData.isRecurring ? "Her yıl tekrarlanacak" : "Tek seferlik",
        );
      }

      if ((beforeData.category || "") !== (afterData.category || "")) {
        changes.push("Kategori güncellendi");
      }

      if (!changes.length) {
        return null;
      }

      const relationship = await fetchRelationship(afterData.relationshipId);
      if (!relationship) {
        return null;
      }

      const actorId = afterData.updatedBy || afterData.lastUpdatedBy;
      const recipients = actorId ?
        getRelationshipUserIds(relationship).filter((id) => id !== actorId) :
        getRelationshipUserIds(relationship);
      if (!recipients.length) {
        return null;
      }

      const users = actorId ? await loadUsers([actorId]) : new Map();
      const updaterName = actorId ?
        resolveDisplayName(users.get(actorId)?.name) :
        fallbackLovedOneName;
      const body =
          buildNotificationBody([
            afterData.title,
            changes.join(" • "),
          ]) || "Özel gün detaylarında küçük değişiklikler var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${updaterName} özel günü yeniden düzenledi`,
          body,
        },
        data: {
          type: "special_day_update",
          specialDayId: context.params.specialDayId,
          relationshipId: afterData.relationshipId,
          updatedBy: actorId || "",
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
      const creatorName = resolveDisplayName(creator?.name);
      const body =
          buildNotificationBody([
            plan.title,
            formatDateTime(plan.date),
          ]) || "Birlikte yapılacak yeni bir plan var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${creatorName} sizin için bir plan hazırladı`,
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

      const actorId = afterData.updatedBy || afterData.lastUpdatedBy;
      const recipients = actorId ?
        members.filter((id) => id !== actorId) :
        members;
      const users = actorId ? await loadUsers([actorId]) : new Map();
      const updaterName = actorId ?
        resolveDisplayName(users.get(actorId)?.name) :
        "Plan";

      if (beforeData.isCompleted !== afterData.isCompleted &&
        afterData.isCompleted) {
        const body =
            buildNotificationBody([
              afterData.title,
              afterData.completedAt ?
                formatDateTime(afterData.completedAt) :
                null,
              afterData.date ? formatDateTime(afterData.date) : null,
            ]) || "Bir plan tamamlandı.";

        return sendPushToUsers({
          userIds: recipients,
          notification: {
            title: actorId ?
              `${updaterName} bir planı tamamladı` :
              "Bir plan tamamlandı",
            body,
          },
          data: {
            type: "plan_completed",
            planId: context.params.planId,
            relationshipId: afterData.relationshipId,
            completedBy: actorId || "",
          },
        });
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

      if (beforeData.isCompleted !== afterData.isCompleted &&
        !afterData.isCompleted) {
        changes.push("Plan yeniden açıldı");
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

      const body =
          buildNotificationBody([
            afterData.title,
            changes.join(" • "),
          ]) || "Planınızda küçük değişiklikler var.";

      return sendPushToUsers({
        userIds: recipients,
        notification: {
          title: `${updaterName} planı yeniden düzenledi`,
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
            ]) || "Yaklaşan tatlı planı kaçırma.";

        await sendPushToUsers({
          userIds: members,
          notification: {
            title: "Birlikte planınız yaklaşıyor",
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

exports.dispatchTomorrowPlanReminders = functions.pubsub
    .schedule("every day 20:00")
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
      const now = new Date();
      const tomorrowStart = new Date(
          now.getFullYear(),
          now.getMonth(),
          now.getDate() + 1,
      );
      const dayAfterTomorrowStart = new Date(
          now.getFullYear(),
          now.getMonth(),
          now.getDate() + 2,
      );
      const reminderKey = createDateKey(tomorrowStart);

      const snapshot = await firestore.collection("plans")
          .where("reminderEnabled", "==", true)
          .where("isCompleted", "==", false)
          .where(
              "date",
              ">=",
              admin.firestore.Timestamp.fromDate(tomorrowStart),
          )
          .where(
              "date",
              "<",
              admin.firestore.Timestamp.fromDate(dayAfterTomorrowStart),
          )
          .orderBy("date")
          .limit(200)
          .get();

      if (snapshot.empty) {
        return null;
      }

      for (const doc of snapshot.docs) {
        const plan = doc.data();
        const planDate = toDate(plan.date);
        if (!planDate || plan.tomorrowReminderKey === reminderKey) {
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

        const body = buildNotificationBody([
          plan.title,
          "Yarın",
          formatDateTime(plan.date),
        ]) || "Yarın için tatlı bir plan sizi bekliyor.";

        await sendPushToUsers({
          userIds: members,
          notification: {
            title: "Yarın birlikte bir planınız var",
            body,
          },
          data: {
            type: "plan_tomorrow",
            planId: doc.id,
            relationshipId: plan.relationshipId,
            reminderKey,
          },
        });

        await doc.ref.update({
          tomorrowReminderKey: reminderKey,
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
      const activePlansSnapshot = await firestore.collection("plans")
          .where("isCompleted", "==", false)
          .limit(1000)
          .get();
      const activePlansByRelationship = new Map();
      const activeSurprisesSnapshot = await firestore.collection("surprises")
          .where("isOpened", "==", false)
          .limit(1000)
          .get();
      const activeSurprisesByRelationship = new Map();

      activePlansSnapshot.docs.forEach((planDoc) => {
        const plan = planDoc.data();
        const planDate = toDate(plan.date);
        if (!plan?.relationshipId || !planDate) {
          return;
        }

        const daysUntilPlan = differenceInCalendarDays(planDate, now);
        if (typeof daysUntilPlan !== "number" ||
          daysUntilPlan < 0 ||
          daysUntilPlan > 31) {
          return;
        }

        if (!activePlansByRelationship.has(plan.relationshipId)) {
          activePlansByRelationship.set(plan.relationshipId, []);
        }

        activePlansByRelationship.get(plan.relationshipId).push(planDate);
      });

      activeSurprisesSnapshot.docs.forEach((surpriseDoc) => {
        const surprise = surpriseDoc.data();
        const revealDate = toDate(surprise.revealDate);
        if (!surprise?.relationshipId || !revealDate) {
          return;
        }

        const daysUntilReveal = differenceInCalendarDays(revealDate, now);
        if (typeof daysUntilReveal !== "number" ||
          daysUntilReveal < 0 ||
          daysUntilReveal > 31) {
          return;
        }

        if (!activeSurprisesByRelationship.has(surprise.relationshipId)) {
          activeSurprisesByRelationship.set(surprise.relationshipId, []);
        }

        activeSurprisesByRelationship.get(surprise.relationshipId)
            .push(revealDate);
      });

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

        const daysUntil = differenceInCalendarDays(targetDate, now);
        if (daysUntil === specialDayUpcomingLeadDays) {
          const upcomingKey = createDateKey(targetDate);
          if (specialDay.lastUpcomingReminderKey !== upcomingKey) {
            const relationship = await fetchRelationship(
                specialDay.relationshipId,
            );
            if (!relationship) {
              continue;
            }

            const members = getRelationshipUserIds(relationship);
            if (!members.length) {
              continue;
            }

            const body =
                buildNotificationBody([
                  specialDay.title,
                  "Yaklaşıyor",
                  formatDateOnly(targetDate),
                ]) || "Yaklaşan özel gününü kaçırma.";

            await sendPushToUsers({
              userIds: members,
              notification: {
                title: "Yaklaşan özel gününüz var",
                body,
              },
              data: {
                type: "special_day_upcoming",
                specialDayId: doc.id,
                relationshipId: specialDay.relationshipId,
                reminderKey: upcomingKey,
              },
            });

            await doc.ref.update({
              lastUpcomingReminderKey: upcomingKey,
              lastUpcomingReminderAt: fieldValue.serverTimestamp(),
            });
          }
        }

        const planMissingStage = getSpecialDayPlanMissingStage(daysUntil);
        if (planMissingStage) {
          const nearbyPlans = activePlansByRelationship.get(
              specialDay.relationshipId,
          ) || [];
          const reminderKey =
              `${createDateKey(targetDate)}:${planMissingStage}`;
          const sentKeys = Array.isArray(specialDay.planMissingReminderKeys) ?
            specialDay.planMissingReminderKeys :
            [];

          if (!hasNearbyScheduledDate(nearbyPlans, targetDate) &&
            !sentKeys.includes(reminderKey)) {
            const relationship = await fetchRelationship(
                specialDay.relationshipId,
            );
            if (!relationship) {
              continue;
            }

            const members = getRelationshipUserIds(relationship);
            if (!members.length) {
              continue;
            }

            const body =
                buildNotificationBody([
                  specialDay.title,
                  describeSpecialDayCountdown(daysUntil),
                  "Henüz bir plan görünmüyor",
                ]) || "Özel gün için minik bir plan yapma zamanı.";

            await sendPushToUsers({
              userIds: members,
              notification: {
                title: "Özel gün için minik bir plan yapma zamanı",
                body,
              },
              data: {
                type: "special_day_plan_missing",
                specialDayId: doc.id,
                relationshipId: specialDay.relationshipId,
                reminderKey,
              },
            });

            await doc.ref.update({
              planMissingReminderKeys: fieldValue.arrayUnion(reminderKey),
              lastPlanMissingReminderAt: fieldValue.serverTimestamp(),
            });
          }
        }

        const surpriseMissingStage = getSpecialDaySurpriseMissingStage(
            daysUntil,
        );
        if (surpriseMissingStage) {
          const nearbySurprises = activeSurprisesByRelationship.get(
              specialDay.relationshipId,
          ) || [];
          const reminderKey =
              `${createDateKey(targetDate)}:${surpriseMissingStage}`;
          const sentKeys = Array.isArray(
              specialDay.surpriseMissingReminderKeys,
          ) ?
            specialDay.surpriseMissingReminderKeys :
            [];

          if (!hasNearbyScheduledDate(nearbySurprises, targetDate) &&
            !sentKeys.includes(reminderKey)) {
            const relationship = await fetchRelationship(
                specialDay.relationshipId,
            );
            if (!relationship) {
              continue;
            }

            const members = getRelationshipUserIds(relationship);
            if (!members.length) {
              continue;
            }

            const body =
                buildNotificationBody([
                  specialDay.title,
                  describeSpecialDayCountdown(daysUntil),
                  "Henüz bir sürpriz görünmüyor",
                ]) || "Özel gün için minik bir sürpriz hazırlamak ister misin?";

            await sendPushToUsers({
              userIds: members,
              notification: {
                title: "Özel gün için küçük bir sürpriz fikri olabilir",
                body,
              },
              data: {
                type: "special_day_surprise_missing",
                specialDayId: doc.id,
                relationshipId: specialDay.relationshipId,
                reminderKey,
              },
            });

            await doc.ref.update({
              surpriseMissingReminderKeys: fieldValue.arrayUnion(reminderKey),
              lastSurpriseMissingReminderAt: fieldValue.serverTimestamp(),
            });
          }
        }

        const stage = getSpecialDayReminderStage(daysUntil);
        if (typeof daysUntil !== "number" || !stage) {
          continue;
        }

        const reminderKey = `${createDateKey(targetDate)}:${stage}`;
        if (specialDay.lastReminderStageKey === reminderKey) {
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

        const body =
            buildNotificationBody([
              specialDay.title,
              describeSpecialDayCountdown(daysUntil),
              daysUntil === 0 ?
                "İstersen tatlı bir mesaj at, mini plan yap" :
                formatDateOnly(targetDate),
            ]) || (daysUntil === 0 ?
              "İstersen tatlı bir mesaj at ya da sürpriz hazırla." :
              "Tatlı bir özel gün yaklaşıyor.");

        await sendPushToUsers({
          userIds: members,
          notification: {
            title: daysUntil === 0 ?
              "Bugün sizin gününüz" :
              "Özel gününüz yaklaşıyor",
            body,
          },
          data: {
            type: "special_day_reminder",
            specialDayId: doc.id,
            relationshipId: specialDay.relationshipId,
            reminderKey,
          },
        });

        await doc.ref.update({
          lastReminderStageKey: reminderKey,
          lastReminderKey: reminderKey,
          lastReminderAt: fieldValue.serverTimestamp(),
        });
      }
      return null;
    });

exports.dispatchSurpriseRevealReminders = functions.pubsub
    .schedule("every 1 hours")
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
      const now = new Date();
      const snapshot = await firestore.collection("surprises")
          .limit(500)
          .get();

      if (snapshot.empty) {
        return null;
      }

      for (const doc of snapshot.docs) {
        const surprise = doc.data();
        if (!surprise?.relationshipId || !surprise?.createdFor) {
          continue;
        }

        if (surprise.isOpened || surprise.isManuallyHidden) {
          continue;
        }

        const revealDate = toDate(surprise.revealDate);
        if (!revealDate) {
          continue;
        }

        const diffMs = revealDate.getTime() - now.getTime();
        if (diffMs < -60 * 60 * 1000) {
          continue;
        }

        const hoursUntil = diffMs <= 0 ?
          0 :
          Math.ceil(diffMs / (1000 * 60 * 60));
        const stage = getSurpriseReminderStage(hoursUntil);
        if (!stage) {
          continue;
        }

        const reminderKey = `${createDateKey(revealDate)}:${stage}`;
        const sentKeys = Array.isArray(surprise.revealReminderStageKeys) ?
          surprise.revealReminderStageKeys :
          [];
        if (sentKeys.includes(reminderKey)) {
          continue;
        }

        const body =
            buildNotificationBody([
              surprise.title,
              hoursUntil === 0 ?
                "Açılma zamanı geldi" :
                describeTimeUntil(revealDate, now),
              formatDateTime(revealDate),
            ]) || "Seni bekleyen bir sürpriz var.";

        await sendPushToUsers({
          userIds: [surprise.createdFor],
          notification: {
            title: hoursUntil === 0 ?
              "Aşkından bir sürpriz var" :
              "Sürpriz zamanı yaklaşıyor",
            body,
          },
          data: {
            type: "surprise_reveal_due",
            surpriseId: doc.id,
            relationshipId: surprise.relationshipId,
            createdFor: surprise.createdFor,
            reminderKey,
          },
        });

        await doc.ref.update({
          revealReminderStageKeys: fieldValue.arrayUnion(reminderKey),
          lastRevealReminderAt: fieldValue.serverTimestamp(),
        });
      }

      return null;
    });

exports.dispatchMemoryFlashbacks = functions.pubsub
    .schedule("every day 09:00")
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
      const now = new Date();
      const todayKey = createDateKey(now);
      const snapshot = await firestore.collection("memories")
          .limit(500)
          .get();

      if (snapshot.empty) {
        return null;
      }

      const groupedMemories = new Map();
      snapshot.docs.forEach((doc) => {
        const memory = doc.data();
        const memoryDate = toDate(memory.date);
        if (!memory?.relationshipId || !memoryDate) {
          return;
        }

        const isSameMonth = memoryDate.getMonth() === now.getMonth();
        const isSameDay = memoryDate.getDate() === now.getDate();
        const isPastYear = memoryDate.getFullYear() < now.getFullYear();
        if (!isSameMonth || !isSameDay || !isPastYear) {
          return;
        }

        if (!groupedMemories.has(memory.relationshipId)) {
          groupedMemories.set(memory.relationshipId, []);
        }

        groupedMemories.get(memory.relationshipId).push({
          id: doc.id,
          ...memory,
        });
      });

      if (!groupedMemories.size) {
        return null;
      }

      for (const [relationshipId, memories] of groupedMemories.entries()) {
        const relationship = await fetchRelationship(relationshipId);
        if (!relationship || relationship.lastMemoryFlashbackKey === todayKey) {
          continue;
        }

        const members = getRelationshipUserIds(relationship);
        if (!members.length) {
          continue;
        }

        const sortedMemories = memories.sort((left, right) => {
          const leftDate = toDate(left.date);
          const rightDate = toDate(right.date);
          return (leftDate?.getTime() || 0) - (rightDate?.getTime() || 0);
        });
        const featuredMemory = sortedMemories[0];
        const featuredDate = toDate(featuredMemory.date);
        const yearsAgo = featuredDate ?
          now.getFullYear() - featuredDate.getFullYear() :
          null;
        const body = memories.length === 1 ?
          buildNotificationBody([
            featuredMemory.title,
            yearsAgo ?
              `${yearsAgo} yıl önce bugün` :
              "Bugün yeniden hatırlandı",
          ]) :
          buildNotificationBody([
            `${memories.length} anı bu tarihte seni bekliyor`,
            featuredMemory.title,
          ]);

        await sendPushToUsers({
          userIds: members,
          notification: {
            title: "Bugün kalbine düşen bir anı var",
            body: body || "Eski güzel bir ana yeniden göz at.",
          },
          data: {
            type: "on_this_day_memory",
            relationshipId,
            memoryId: featuredMemory.id,
            dateKey: todayKey,
          },
        });

        await firestore.collection("relationships").doc(relationshipId).update({
          lastMemoryFlashbackKey: todayKey,
          lastMemoryFlashbackAt: fieldValue.serverTimestamp(),
        });
      }

      return null;
    });

exports.dispatchInactiveCoupleNudges = functions.pubsub
    .schedule("every day 20:00")
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
      const now = new Date();
      const weekKey = createWeekKey(now);
      const inactivityThresholdMs = 7 * 24 * 60 * 60 * 1000;
      const relationshipsSnapshot = await firestore.collection("relationships")
          .limit(500)
          .get();

      if (relationshipsSnapshot.empty) {
        return null;
      }

      for (const relationshipDoc of relationshipsSnapshot.docs) {
        const relationship = {
          id: relationshipDoc.id,
          ...relationshipDoc.data(),
        };
        if (relationship.lastInactivityNudgeKey === weekKey) {
          continue;
        }

        let latestMessageDate = null;
        try {
          const latestMessageSnapshot = await firestore.collection("messages")
              .where("relationshipId", "==", relationshipDoc.id)
              .orderBy("timestamp", "desc")
              .limit(1)
              .get();

          if (!latestMessageSnapshot.empty) {
            latestMessageDate = toDate(
                latestMessageSnapshot.docs[0].data()?.timestamp,
            );
          }
        } catch (error) {
          logger.warn("Falling back to message scan for inactivity nudge.", {
            relationshipId: relationshipDoc.id,
            error: error.message,
          });

          const messagesSnapshot = await firestore.collection("messages")
              .where("relationshipId", "==", relationshipDoc.id)
              .limit(500)
              .get();

          messagesSnapshot.forEach((doc) => {
            const messageDate = toDate(doc.data()?.timestamp);
            if (!messageDate) {
              return;
            }
            if (!latestMessageDate || messageDate > latestMessageDate) {
              latestMessageDate = messageDate;
            }
          });
        }

        const fallbackDate = toDate(relationship.createdAt) || now;
        const latestActivityDate = latestMessageDate || fallbackDate;
        if (
          now.getTime() - latestActivityDate.getTime() <
          inactivityThresholdMs
        ) {
          continue;
        }

        const members = getRelationshipUserIds(relationship);
        if (!members.length) {
          continue;
        }

        await sendPushToUsers({
          userIds: members,
          notification: {
            title: "Aşkına küçük bir şey bırakmak ister misin?",
            body: "Ufak bir mesaj ya da tatlı bir not iyi gelebilir.",
          },
          data: {
            type: "inactive_couple_nudge",
            relationshipId: relationshipDoc.id,
            weekKey,
          },
        });

        await relationshipDoc.ref.update({
          lastInactivityNudgeKey: weekKey,
          lastInactivityNudgeAt: fieldValue.serverTimestamp(),
        });
      }

      return null;
    });
