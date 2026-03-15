const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

const UID = "sJ8Pxusw9gR0tNR44RhkIge7OiG2";
const TUYA_BASE = "https://openapi.tuyaus.com";
const MY_BOT_TOKEN = "8514127849:AAF8_F7SBfm51SGHtp9X5lva7yexdnFyapo";
const MY_CHAT_ID = "8724548311";
const KAKAO_REST_KEY = "8987f9dd586416344444c7a59b5f0e73";

// ═══ Haversine 거리 계산 (미터) ═══
function haversineM(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => d * Math.PI / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function getConfig() {
  return {
    accessId: process.env.TUYA_ACCESS_ID || "",
    accessSecret: process.env.TUYA_ACCESS_SECRET || "",
    deviceId: process.env.TUYA_DEVICE_ID || "",
  };
}

// Tuya HMAC-SHA256 signing
function tuyaSign(accessId, accessSecret, t, accessToken, method, path, body) {
  const contentHash = crypto
    .createHash("sha256")
    .update(body || "")
    .digest("hex");
  const stringToSign = [method, contentHash, "", path].join("\n");
  const signStr = accessId + (accessToken || "") + t + stringToSign;
  return crypto
    .createHmac("sha256", accessSecret)
    .update(signStr)
    .digest("hex")
    .toUpperCase();
}

async function getTuyaToken(accessId, accessSecret) {
  const t = Date.now().toString();
  const path = "/v1.0/token?grant_type=1";
  const sign = tuyaSign(accessId, accessSecret, t, "", "GET", path, "");

  const {data} = await axios.get(TUYA_BASE + path, {
    headers: {
      client_id: accessId,
      sign: sign,
      t: t,
      sign_method: "HMAC-SHA256",
    },
  });

  if (!data.success) throw new Error("Token: " + JSON.stringify(data));
  return data.result.access_token;
}

async function getDeviceStatus(accessId, accessSecret, token, deviceId) {
  const t = Date.now().toString();
  const path = "/v1.0/devices/" + deviceId + "/status";
  const sign = tuyaSign(accessId, accessSecret, t, token, "GET", path, "");

  const {data} = await axios.get(TUYA_BASE + path, {
    headers: {
      client_id: accessId,
      access_token: token,
      sign: sign,
      t: t,
      sign_method: "HMAC-SHA256",
    },
  });

  if (!data.success) throw new Error("Status: " + JSON.stringify(data));
  return data.result;
}

async function pollDoorLogic() {
  const {accessId, accessSecret, deviceId} = getConfig();

  // Get Tuya API token
  const token = await getTuyaToken(accessId, accessSecret);

  // Get device status
  const statusArr = await getDeviceStatus(accessId, accessSecret, token, deviceId);

  // Find door contact state
  let doorContactState = null;
  for (const s of statusArr) {
    if (s.code === "doorcontact_state") {
      doorContactState = s.value;
    }
  }

  if (doorContactState === null) {
    return {success: false, msg: "doorcontact_state not found", raw: statusArr};
  }

  // Tuya doorcontact_state: true = closed (magnet contact), false = open
  const isOpen = !doorContactState;

  // Read current state to detect change
  const todayRef = db.doc("users/" + UID + "/data/iot");
  const doc = await todayRef.get();
  const currentDoor = doc.exists ? (doc.data().door || {}) : {};

  const stateChanged =
    currentDoor.isOpen === undefined || currentDoor.isOpen !== isOpen;

  const doorUpdate = {
    isOpen: isOpen,
    state: isOpen ? "open" : "closed",
    lastPolled: admin.firestore.FieldValue.serverTimestamp(),
    sensorId: "front_door",
  };

  // Only update lastChanged when state actually changes
  if (stateChanged) {
    doorUpdate.lastChanged = admin.firestore.FieldValue.serverTimestamp();
  }

  await todayRef.set({door: doorUpdate}, {merge: true});

  // ═══ 기상 감지: 문 열림 + 7시 이후 + 오늘 wake 미기록 ═══
  let wakeTime = null;
  if (stateChanged && isOpen) {
    wakeTime = await checkWakeAndNotify(doc);
  }

  // ═══ 외출 20분 확정 체크 ═══
  let outingTime = null;
  outingTime = await checkMovementPending(doc);

  return {success: true, isOpen: isOpen, stateChanged: stateChanged, wakeTime: wakeTime, outingTime: outingTime, raw: statusArr};
}

// ═══════════════════════════════════════════════════════════
//  기상 감지 — CF에서 자동 처리 (앱 불필요)
// ═══════════════════════════════════════════════════════════

async function checkWakeAndNotify(iotDoc) {
  const kstNow = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const kstHour = kstNow.getUTCHours();
  const kstMin = kstNow.getUTCMinutes();

  // 7시 이전 무시
  if (kstHour < 7) return null;

  const dateStr = kstNow.toISOString().slice(0, 10);
  const timeStr = String(kstHour).padStart(2, "0") + ":" + String(kstMin).padStart(2, "0");

  // 오늘 wake 이미 기록되었는지 확인
  const todayDoc = await db.doc("users/" + UID + "/data/today").get();
  const todayData = todayDoc.exists ? todayDoc.data() : {};
  const tr = (todayData.timeRecords || {})[dateStr] || {};

  if (tr.wake) return null; // 이미 기상 기록됨

  // Firestore에 기상 기록 (today + study dual-write)
  const wakeUpdate = {timeRecords: {}};
  wakeUpdate.timeRecords[dateStr] = {wake: timeStr};

  await Promise.all([
    db.doc("users/" + UID + "/data/today").set(wakeUpdate, {merge: true}),
    db.doc("users/" + UID + "/data/study").set(wakeUpdate, {merge: true}),
  ]);

  // 텔레그램 (양쪽 발송)
  const msg = "⏰ 자동 기상 " + timeStr;
  await Promise.all([
    axios.post("https://api.telegram.org/bot" + MY_BOT_TOKEN + "/sendMessage",
      {chat_id: MY_CHAT_ID, text: msg}).catch(() => {}),
    axios.post("https://api.telegram.org/bot" + GF_BOT_TOKEN + "/sendMessage",
      {chat_id: GF_CHAT_ID, text: msg}).catch(() => {}),
  ]);

  // FCM data message → 앱 깨우기
  const iotData = iotDoc.exists ? iotDoc.data() : {};
  if (iotData.fcmToken) {
    try {
      await admin.messaging().send({
        token: iotData.fcmToken,
        data: {type: "wake", time: timeStr},
        android: {priority: "high"},
      });
      console.log("FCM wake sent:", timeStr);
    } catch (e) {
      console.error("FCM error:", e.message);
    }
  }

  console.log("Wake recorded:", timeStr);
  return timeStr;
}

// ═══════════════════════════════════════════════════════════
//  외출 20분 확정 — 빅스비 OUT 후 20분 경과 시 확정 처리
// ═══════════════════════════════════════════════════════════

async function checkMovementPending(iotDoc) {
  const iotData = iotDoc.exists ? iotDoc.data() : {};
  const movement = iotData.movement || {};

  if (!movement.pending) return null;

  const leftAt = movement.leftAt; // Firestore Timestamp
  if (!leftAt || !leftAt.toDate) return null;

  const leftTime = leftAt.toDate();
  const now = new Date();
  const diffMin = (now - leftTime) / (1000 * 60);

  if (diffMin < 20) return null; // 20분 미경과

  // KST 날짜/시간
  const kstNow = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const dateStr = kstNow.toISOString().slice(0, 10);
  const outTimeStr = movement.leftAtLocal || "??:??";

  // 하루 첫 외출만 기록 (중복 방지)
  const studyDoc = await db.doc("users/" + UID + "/data/study").get();
  const studyData = studyDoc.exists ? studyDoc.data() : {};
  const tr = (studyData.timeRecords || {})[dateStr] || {};
  if (tr.outing) {
    // 이미 외출 기록됨 → pending만 해제
    await db.doc("users/" + UID + "/data/iot").update({"movement.pending": false});
    return null;
  }

  // data/study에 외출 시간 기록
  const outUpdate = {timeRecords: {}};
  outUpdate.timeRecords[dateStr] = {outing: outTimeStr};
  await db.doc("users/" + UID + "/data/study").set(outUpdate, {merge: true});

  // 텔레그램
  // ═══ 공부 장소 매칭 ═══
  const studyLocations = iotData.studyLocations || [];
  const lastLoc = iotData.lastLocation || {};
  let locationType = "out";
  let locationName = null;

  if (lastLoc.latitude && lastLoc.longitude && studyLocations.length > 0) {
    for (const loc of studyLocations) {
      const dist = haversineM(lastLoc.latitude, lastLoc.longitude, loc.lat, loc.lng);
      const radius = loc.radius || 200;
      if (dist <= radius) {
        locationType = "studying";
        locationName = loc.name;
        break;
      }
    }
  }

  // movement 타입 업데이트
  const movementUpdate = {
    "movement.pending": false,
    "movement.type": locationType,
    "movement.confirmedAt": admin.firestore.FieldValue.serverTimestamp(),
  };
  if (locationName) movementUpdate["movement.locationName"] = locationName;
  await db.doc("users/" + UID + "/data/iot").update(movementUpdate);

  const locLabel = locationName ? " @ " + locationName : "";
  const emoji = locationType === "studying" ? "📚" : "🚶";
  const msg = emoji + " 외출 확정 " + outTimeStr + " (20분 경과)" + locLabel;
  await Promise.all([
    axios.post("https://api.telegram.org/bot" + MY_BOT_TOKEN + "/sendMessage",
      {chat_id: MY_CHAT_ID, text: msg}).catch(() => {}),
    axios.post("https://api.telegram.org/bot" + GF_BOT_TOKEN + "/sendMessage",
      {chat_id: GF_CHAT_ID, text: msg}).catch(() => {}),
  ]);

  // FCM → 앱 상태 업데이트
  if (iotData.fcmToken) {
    try {
      await admin.messaging().send({
        token: iotData.fcmToken,
        data: {type: locationType === "studying" ? "studying" : "outing", time: outTimeStr, location: locationName || ""},
        android: {priority: "high"},
      });
      console.log("FCM outing sent:", outTimeStr);
    } catch (e) {
      console.error("FCM outing error:", e.message);
    }
  }

  console.log("Outing confirmed:", outTimeStr);
  return outTimeStr;
}

// Scheduled: every 1 minute
exports.pollDoorSensor = functions.pubsub
  .schedule("every 1 minutes")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    try {
      const result = await pollDoorLogic();
      console.log("Poll:", JSON.stringify(result));
    } catch (err) {
      console.error("Poll error:", err.message);
    }
    return null;
  });

// Manual test endpoint
exports.checkDoorManual = functions.https.onRequest(async (req, res) => {
  try {
    const result = await pollDoorLogic();
    res.status(200).json(result);
  } catch (err) {
    console.error("Manual check error:", err);
    res.status(500).json({success: false, error: err.message});
  }
});

// ═══════════════════════════════════════════════════════════
//  🦉 헤드위그 — 여자친구 봇 (즉시 응답, 앱 불필요)
// ═══════════════════════════════════════════════════════════

const GF_BOT_TOKEN = "8613977898:AAEuuoTVARS-a9nrDp85NWHHOYM0lRvmZmc";
const GF_CHAT_ID = "8624466505";
const HEDWIG_KEYWORDS = ["위치", "어디", "어디야", "where", "뭐해", "/where", "/status"];

// 카카오 역지오코딩 — GPS → 보편적 장소명
// "금정역 근처", "이마트 광정점 근처" 같이 알아듣기 쉽게
async function reverseGeocode(lat, lng) {
  try {
    const headers = {Authorization: "KakaoAK " + KAKAO_REST_KEY};
    const params = {x: lng, y: lat, radius: 500, sort: "distance"};

    // 1) 랜드마크 카테고리 검색 (지하철 > 대형마트 > 학교 > 병원 순)
    const categories = [
      {code: "SW8", label: "역"},      // 지하철
      {code: "MT1", label: ""},         // 대형마트
      {code: "SC4", label: ""},         // 학교
      {code: "CT1", label: ""},         // 문화시설
      {code: "HP8", label: ""},         // 병원
    ];

    for (const cat of categories) {
      try {
        const {data} = await axios.get("https://dapi.kakao.com/v2/local/search/category.json", {
          params: {...params, category_group_code: cat.code},
          headers,
        });
        const places = data.documents || [];
        if (places.length > 0) {
          const p = places[0];
          const dist = parseInt(p.distance);
          const name = p.place_name;
          if (dist <= 100) return name;
          return name + " 근처 (" + dist + "m)";
        }
      } catch (_) {}
    }

    // 2) fallback: 행정동
    const {data} = await axios.get("https://dapi.kakao.com/v2/local/geo/coord2regioncode.json", {
      params: {x: lng, y: lat}, headers,
    });
    const regions = data.documents || [];
    const hDoc = regions.find((d) => d.region_type === "H") || regions[0];
    if (hDoc) return hDoc.region_1depth_name + " " + hDoc.region_2depth_name;
  } catch (e) {
    console.error("Kakao geocode error:", e.message);
  }
  return null;
}

// "HH:mm" → KST 기준 몇 분 전인지 계산
function minAgoFromHHMM(hhMm) {
  if (!hhMm || typeof hhMm !== "string") return null;
  const parts = hhMm.split(":");
  if (parts.length !== 2) return null;
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  if (isNaN(h) || isNaN(m)) return null;
  const kstNow = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const nowMin = kstNow.getUTCHours() * 60 + kstNow.getUTCMinutes();
  return nowMin - (h * 60 + m);
}

function formatMinAgo(min) {
  if (min === null) return "";
  if (min < 1) return "방금";
  if (min < 60) return `${min}분 전`;
  return `${Math.floor(min / 60)}시간째`;
}

async function buildHedwigMessage(timeRecord, lastLocation, movement) {
  const kstNow = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const kstHour = kstNow.getUTCHours();

  const wake = timeRecord && timeRecord.wake;       // "HH:mm"
  const wokeToday = !!wake;

  // 1. 수면 (11PM~7AM + 오늘 Wake 미발생)
  if ((kstHour >= 23 || kstHour < 7) && !wokeToday) {
    return "💤 자고 있어요... 쉿!\n🦉 헤드위그 🪶";
  }

  // 2. 기상 직후 (Wake 후 30분 이내)
  const wakeMinAgo = minAgoFromHHMM(wake);
  if (wokeToday && wakeMinAgo !== null && wakeMinAgo >= 0 && wakeMinAgo <= 30) {
    return `☀️ 방금 일어났어요! (${wakeMinAgo}분 전)\n🦉 헤드위그 🪶`;
  }

  // 3. 빅스비 movement 기반 외출/귀가 (우선)
  if (movement) {
    const mType = movement.type || "";
    const mPending = movement.pending || false;
    const leftLocal = movement.leftAtLocal || "";
    const returnedLocal = movement.returnedAtLocal || "";

    // 3a. 확인 중 (pending)
    if (mPending && mType === "pending") {
      const outMin = minAgoFromHHMM(leftLocal);
      let msg = `🚶 잠깐 나간 것 같아요... (확인 중)`;
      if (outMin !== null && outMin >= 0) msg += `\n⏱ ${formatMinAgo(outMin)} 출발`;
      msg += "\n🦉 헤드위그 🪶";
      return msg;
    }

    // 3b. 외출 확정
    if (mType === "out") {
      const outMin = minAgoFromHHMM(leftLocal);
      const justLeft = outMin !== null && outMin <= 5;
      let msg = justLeft
        ? `🧹💨 방금 나갔어요! (${formatMinAgo(outMin)})`
        : `🧹 외출 중` + (outMin !== null ? ` (${formatMinAgo(outMin)} 출발)` : "");
      if (lastLocation && lastLocation.latitude && lastLocation.longitude) {
        const place = await reverseGeocode(lastLocation.latitude, lastLocation.longitude);
        if (place) msg += `\n📍 ${place}`;
        msg += `\n🗺 https://www.google.com/maps?q=${lastLocation.latitude},${lastLocation.longitude}`;
      }
      msg += "\n🦉 헤드위그 🪶";
      return msg;
    }

    // 3c. 귀가 완료
    if (mType === "home") {
      const homeMin = minAgoFromHHMM(returnedLocal);
      const homeStr = homeMin !== null ? formatMinAgo(homeMin) : "";
      return `🏰 집에 있어요` + (homeStr ? ` (귀가 ${homeStr})` : "") + "\n🦉 헤드위그 🪶";
    }
  }

  // 4. fallback: timeRecords 기반 (레거시)
  const outing = timeRecord && timeRecord.outing;
  const returnHome = timeRecord && timeRecord.returnHome;

  if (outing && !returnHome) {
    const outMin = minAgoFromHHMM(outing);
    let msg = `🧹 외출 중` + (outMin !== null ? ` (${formatMinAgo(outMin)} 출발)` : "");
    if (lastLocation && lastLocation.latitude && lastLocation.longitude) {
      const place = await reverseGeocode(lastLocation.latitude, lastLocation.longitude);
      if (place) msg += `\n📍 ${place}`;
      msg += `\n🗺 https://www.google.com/maps?q=${lastLocation.latitude},${lastLocation.longitude}`;
    }
    msg += "\n🦉 헤드위그 🪶";
    return msg;
  }

  if (returnHome) {
    const homeMin = minAgoFromHHMM(returnHome);
    const homeStr = homeMin !== null ? formatMinAgo(homeMin) : "";
    return `🏰 집에 있어요` + (homeStr ? ` (귀가 ${homeStr})` : "") + "\n🦉 헤드위그 🪶";
  }

  return "🏰 집에 있어요\n🦉 헤드위그 🪶";
}

// Girlfriend bot webhook — Hedwig instant response
exports.girlfriendBotWebhook = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(200).send("OK");
      return;
    }

    const message = req.body && req.body.message;
    if (!message || !message.text) {
      res.status(200).send("OK");
      return;
    }

    const text = message.text.trim().toLowerCase();
    const chatId = String(message.chat.id);

    if (chatId !== GF_CHAT_ID) {
      res.status(200).send("OK");
      return;
    }

    const isQuery = HEDWIG_KEYWORDS.some((kw) => text.includes(kw));

    if (!isQuery) {
      // 키워드 아닌 메시지 → 안내
      await axios.post(
        `https://api.telegram.org/bot${GF_BOT_TOKEN}/sendMessage`,
        {chat_id: chatId, text: "🦉 부엉? \"어디야\" 로 물어봐주세요!"},
      );
      res.status(200).send("OK");
      return;
    }

    // Read Firestore: today doc (timeRecords) + iot doc (lastLocation)
    const kstDate = new Date(Date.now() + 9 * 60 * 60 * 1000);
    const todayStr = kstDate.toISOString().slice(0, 10);

    const [todayDoc, iotDoc] = await Promise.all([
      db.doc("users/" + UID + "/data/today").get(),
      db.doc("users/" + UID + "/data/iot").get(),
    ]);

    const todayData = todayDoc.exists ? todayDoc.data() : {};
    const timeRecords = todayData.timeRecords || {};
    const timeRecord = timeRecords[todayStr] || null;

    const iotData = iotDoc.exists ? iotDoc.data() : {};
    const lastLocation = iotData.lastLocation || null;
    const movement = iotData.movement || null;

    const hedwigMsg = await buildHedwigMessage(timeRecord, lastLocation, movement);

    await axios.post(
      `https://api.telegram.org/bot${GF_BOT_TOKEN}/sendMessage`,
      {chat_id: chatId, text: hedwigMsg},
    );

    // 외출 중이면 위치 핀도 전송
    const isOuting = (movement && (movement.type === "out" || (movement.pending && movement.type === "pending")))
      || (timeRecord && timeRecord.outing && !timeRecord.returnHome);
    if (isOuting && lastLocation && lastLocation.latitude && lastLocation.longitude) {
      await axios.post(
        `https://api.telegram.org/bot${GF_BOT_TOKEN}/sendLocation`,
        {
          chat_id: chatId,
          latitude: lastLocation.latitude,
          longitude: lastLocation.longitude,
        },
      );
    }

    console.log("Hedwig responded:", hedwigMsg.split("\n")[0]);
    res.status(200).send("OK");
  } catch (err) {
    console.error("girlfriendBotWebhook error:", err.message);
    res.status(200).send("OK");
  }
});
