import * as admin from "firebase-admin";
import cors from "cors";
import Busboy from "busboy";
import Stripe from "stripe";
import { randomUUID } from "crypto";
import { onRequest, onCall } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

admin.initializeApp();
const db = admin.firestore();

const GOOGLE_MAPS_API_KEY = defineSecret("GOOGLE_MAPS_API_KEY");
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const APP_BASE_URL = defineString("APP_BASE_URL");
const corsHandler = cors({ origin: true });

type AuditMeta = {
  actorUid?: string;
  actorRole?: string;
  action: string;
  targetPath: string;
  before?: Record<string, unknown>;
  after?: Record<string, unknown>;
  requestId?: string;
};

function reqIdFromHeader(rawReq: any): string {
  const v = String(rawReq?.headers?.["x-cloud-trace-context"] ?? "");
  if (!v) return "";
  return v.split("/")[0] ?? "";
}

async function logAudit(meta: AuditMeta) {
  await db.collection("audit_logs").add({
    actorUid: meta.actorUid ?? "system",
    actorRole: meta.actorRole ?? "system",
    action: meta.action,
    targetPath: meta.targetPath,
    before: meta.before ?? null,
    after: meta.after ?? null,
    requestId: meta.requestId ?? "",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function callableActorMeta(request: any) {
  return {
    actorUid: String(request.auth?.uid ?? "system"),
    actorRole: String(request.auth?.token?.role ?? "system"),
    requestId: reqIdFromHeader(request.rawRequest),
  };
}

function sendJson(res: any, code: number, payload: unknown) {
  res.status(code);
  res.set("Content-Type", "application/json");
  res.send(JSON.stringify(payload));
}

function stripeClient() {
  return new Stripe(STRIPE_SECRET_KEY.value(), { apiVersion: "2024-06-20" as any });
}

function checkoutBaseUrl() {
  const v = String(APP_BASE_URL.value() ?? "").trim();
  return v || "http://localhost:55441";
}

// ------------------ Places Proxy ------------------
export const placesAutocomplete = onRequest(
  { secrets: [GOOGLE_MAPS_API_KEY] },
  (req, res) => {
    corsHandler(req, res, async () => {
      try {
        const input = String(req.query.input ?? "").trim();
        if (!input || input.length < 3) return sendJson(res, 200, { predictions: [] });

        const types = String(req.query.types ?? "address");
        const location = String(req.query.location ?? "29.9511,-90.0715");
        const radius = String(req.query.radius ?? "50000");

        const url = new URL("https://maps.googleapis.com/maps/api/place/autocomplete/json");
        url.searchParams.set("input", input);
        url.searchParams.set("key", GOOGLE_MAPS_API_KEY.value());
        url.searchParams.set("types", types);
        url.searchParams.set("location", location);
        url.searchParams.set("radius", radius);

        const r = await fetch(url.toString(), {
          headers: { Referer: "https://pink-fleets-book-now.web.app" },
        });
        const body = await r.json();
        return sendJson(res, 200, body);
      } catch (e: any) {
        return sendJson(res, 500, { error: String(e?.message ?? e) });
      }
    });
  }
);

export const placeDetails = onRequest(
  { secrets: [GOOGLE_MAPS_API_KEY] },
  (req, res) => {
    corsHandler(req, res, async () => {
      try {
        const placeId = String(req.query.place_id ?? "").trim();
        if (!placeId) return sendJson(res, 400, { error: "Missing place_id" });

        const fields = String(req.query.fields ?? "geometry/location");

        const url = new URL("https://maps.googleapis.com/maps/api/place/details/json");
        url.searchParams.set("place_id", placeId);
        url.searchParams.set("fields", fields);
        url.searchParams.set("key", GOOGLE_MAPS_API_KEY.value());

        const r = await fetch(url.toString(), {
          headers: { Referer: "https://pink-fleets-book-now.web.app" },
        });
        const body = await r.json();
        return sendJson(res, 200, body);
      } catch (e: any) {
        return sendJson(res, 500, { error: String(e?.message ?? e) });
      }
    });
  }
);

// ------------------ ETA (Distance Matrix) - Rider/Driver callable ------------------
export const getEta = onCall({ secrets: [GOOGLE_MAPS_API_KEY] }, async (request) => {
  // Allow any authenticated user (rider/driver/admin/dispatcher)
  if (!request.auth) throw new Error("unauthenticated");

  const { originLat, originLng, destLat, destLng } = request.data || {};
  if (
    originLat == null || originLng == null ||
    destLat == null || destLng == null
  ) {
    throw new Error("Missing origin/dest coordinates");
  }

  const oLat = Number(originLat);
  const oLng = Number(originLng);
  const dLat = Number(destLat);
  const dLng = Number(destLng);

  const url = new URL("https://maps.googleapis.com/maps/api/distancematrix/json");
  url.searchParams.set("origins", `${oLat},${oLng}`);
  url.searchParams.set("destinations", `${dLat},${dLng}`);
  url.searchParams.set("departure_time", "now");
  url.searchParams.set("key", GOOGLE_MAPS_API_KEY.value());

  const r = await fetch(url.toString());
  const body = await r.json();

  const row = body?.rows?.[0]?.elements?.[0];
  const duration = row?.duration_in_traffic ?? row?.duration;
  const distance = row?.distance;

  const durationSeconds = Number(duration?.value ?? 0);
  const durationText = String(duration?.text ?? "");
  const distanceMeters = Number(distance?.value ?? 0);
  const distanceText = String(distance?.text ?? "");

  return {
    durationSeconds,
    durationText,
    distanceMeters,
    distanceText,
    rawStatus: String(row?.status ?? ""),
  };
});

export const createCheckoutSession = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) throw new Error("unauthenticated");

    const { bookingId } = request.data || {};
    if (!bookingId) throw new Error("Missing bookingId");

    // Read booking_private for amount
    const privSnap = await db.collection("bookings_private").doc(String(bookingId)).get();
    if (!privSnap.exists) throw new Error("booking_private_not_found");

    const priv = privSnap.data() || {};
    const total = Number(priv?.pricingSnapshot?.total ?? 0); // cents
    if (!total || total <= 0) throw new Error("invalid_amount");

    const email = String(request.auth.token.email ?? "");

    const baseUrl = checkoutBaseUrl();

    const session = await stripeClient().checkout.sessions.create({
      mode: "payment",
      customer_email: email || undefined,
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: "usd",
            product_data: { name: "Pink Fleets Booking" },
            unit_amount: total,
          },
        },
      ],
      metadata: {
        bookingId: String(bookingId),
      },
      success_url: `${baseUrl}/#/booking/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/#/booking/cancelled`,
    });

    return { url: session.url };
  }
);

export const stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (req, res) => {
    const sig = req.headers["stripe-signature"];
    if (!sig || typeof sig !== "string") {
      res.status(400).send("Missing Stripe signature");
      return;
    }

    let event: Stripe.Event;

    try {
      // IMPORTANT: raw body required for signature verification
      const rawBody = (req as any).rawBody as Buffer;
      event = stripeClient().webhooks.constructEvent(
        rawBody,
        sig,
        STRIPE_WEBHOOK_SECRET.value()
      );
    } catch (err: any) {
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    // We only care about successful payments
    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const bookingId = String(session.metadata?.bookingId ?? "");
      if (bookingId) {
        const targetRef = db.collection("bookings_private").doc(bookingId);
        let changed = false;
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(targetRef);
          const before = snap.data() || {};
          const beforeStatus = String(before.paymentStatus ?? "").toLowerCase();
          if (beforeStatus === "paid") return;

          const patch = {
            paymentStatus: "paid",
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            stripe: {
              sessionId: session.id,
              paymentIntent: session.payment_intent,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          tx.set(targetRef, patch, { merge: true });
          changed = true;
        });

        if (changed) {
          const afterSnap = await targetRef.get();
          await logAudit({
            action: "stripe_webhook_checkout_completed",
            targetPath: `bookings_private/${bookingId}`,
            before: { paymentStatus: "unpaid" },
            after: {
              paymentStatus: String(afterSnap.data()?.paymentStatus ?? ""),
              stripeSessionId: session.id,
            },
            requestId: reqIdFromHeader(req),
          });
        }
      }
    }

    res.json({ received: true });
  }
);

// ------------------ Create Booking (HTTP, for Rider Web) ------------------
/* export const createBookingHttp = onRequest(async (req, res) => { // Removed duplicate
  corsHandler(req, res, async () => {
    try {
      if (req.method !== "POST") {
        sendJson(res, 405, { error: "method-not-allowed" });
        return;
      }
      const authHeader = String(req.headers.authorization ?? "");
      if (!authHeader.startsWith("Bearer ")) {
        sendJson(res, 401, { error: "unauthenticated" });
        return;
      }
      const idToken = authHeader.substring("Bearer ".length);
      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;
      const email = decoded.email || null;
      const name = decoded.name || null;
      const phone = decoded.phone_number || null;

      const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
      const {
        pickupAddress, pickupPlaceId, pickupLat, pickupLng,
        dropoffAddress, dropoffPlaceId, dropoffLat, dropoffLng,
        scheduledStartMs, durationHours, vehicleType, passengers, stops,
        riderName, riderEmail, riderPhone
      } = body || {};

      const bookingRiderName =
        typeof riderName === "string" && riderName.trim().length > 0 ? riderName.trim() : name;
      const bookingRiderEmail =
        typeof riderEmail === "string" && riderEmail.trim().length > 0 ? riderEmail.trim().toLowerCase() : email;
      const bookingRiderPhone =
        typeof riderPhone === "string" && riderPhone.trim().length > 0 ? riderPhone.trim() : phone;

      const bookingRef = admin.firestore().collection("bookings").doc();
      const bookingId = bookingRef.id;
      const nowServer = admin.firestore.FieldValue.serverTimestamp();

      // Write bookings/{bookingId}
      await bookingRef.set({
        status: "dispatching",
        riderId: uid,
        riderUid: uid,
        pickupAddress: pickupAddress ?? null,
        dropoffAddress: dropoffAddress ?? null,
        pickupLat: typeof pickupLat === "number" ? pickupLat : null,
        pickupLng: typeof pickupLng === "number" ? pickupLng : null,
        dropoffLat: typeof dropoffLat === "number" ? dropoffLat : null,
        dropoffLng: typeof dropoffLng === "number" ? dropoffLng : null,
        vehicleType: vehicleType ?? null,
        requestedVehicle: vehicleType ?? null,
        driverId: null,
        riderInfo: {
          uid,
          email,
          name,
          phone,
        },
        assigned: {},
        createdAt: nowServer,
        updatedAt: nowServer,
      });

      // Write bookings_private/{bookingId}
      await admin.firestore().collection("bookings_private").doc(bookingId).set({
        pickupAddress,
        dropoffAddress,
        pickupPlaceId: pickupPlaceId ?? null,
        dropoffPlaceId: dropoffPlaceId ?? null,
        pickupGeo: (typeof pickupLat === "number" && typeof pickupLng === "number") ? new admin.firestore.GeoPoint(pickupLat, pickupLng) : null,
        dropoffGeo: (typeof dropoffLat === "number" && typeof dropoffLng === "number") ? new admin.firestore.GeoPoint(dropoffLat, dropoffLng) : null,
        scheduledStart: typeof scheduledStartMs === "number" ? admin.firestore.Timestamp.fromMillis(scheduledStartMs) : null,
        durationHours: durationHours ?? null,
        passengers: passengers ?? null,
        vehicleType: vehicleType ?? null,
        stops: stops ?? null,
        pricingSnapshot: { total: 0, schemaVersion: 1 },
        paymentStatus: "paid",
        createdAt: nowServer,
        updatedAt: nowServer,
      });

      sendJson(res, 200, { ok: true, bookingId });
    } catch (e: any) {
      sendJson(res, 500, { ok: false, error: String(e?.message ?? e) });
    }
  });
}); */

// ------------------ Role helpers ------------------
function requireAuth(request: any) {
  if (!request.auth) throw new Error("unauthenticated");
}
function requireAuthUid(request: any): string {
  requireAuth(request);
  const uid = request.auth?.uid;
  if (!uid) throw new Error("unauthenticated");
  return String(uid);
}
function roleOf(request: any): string {
  return String(request.auth?.token?.role ?? "");
}
function requireAdmin(request: any) {
  requireAuth(request);
  if (roleOf(request) !== "admin") throw new Error("permission-denied");
}
function requireAdminOrDispatcher(request: any) {
  requireAuth(request);
  const r = roleOf(request);
  if (r !== "admin" && r !== "dispatcher") throw new Error("permission-denied");
}
function requireDriver(request: any) {
  requireAuth(request);
  const r = roleOf(request);
  if (r !== "driver") throw new Error("permission-denied");
}

function sanitizeFileName(name: string): string {
  const base = String(name || "").trim();
  if (!base) return "upload.bin";
  return base.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function normalizeStage(stage: unknown): "pre" | "post" {
  const v = String(stage ?? "").toLowerCase();
  if (v !== "pre" && v !== "post") throw new Error("invalid-stage");
  return v;
}

function normalizeType(type: unknown): "image" | "video" {
  const v = String(type ?? "").toLowerCase();
  if (v === "photo") return "image";
  if (v !== "image" && v !== "video") throw new Error("invalid-type");
  return v;
}

async function assertDriverCanUploadBooking(params: {
  bookingId: string;
  uid: string;
  role: string;
}) {
  const role = String(params.role || "").toLowerCase();
  if (role === "admin" || role === "dispatcher") return;

  const bookingSnap = await db.collection("bookings").doc(params.bookingId).get();
  if (!bookingSnap.exists) throw new Error("booking-not-found");

  const booking = bookingSnap.data() || {};
  const assigned = (booking.assigned ?? {}) as Record<string, unknown>;
  const assignedDriverId = String(assigned.driverId ?? "");

  if (!assignedDriverId || assignedDriverId !== params.uid) {
    throw new Error("permission-denied");
  }
}

function downloadUrlFor(params: { bucketName: string; storagePath: string; token: string }): string {
  const objectPath = encodeURIComponent(params.storagePath);
  return `https://firebasestorage.googleapis.com/v0/b/${params.bucketName}/o/${objectPath}?alt=media&token=${params.token}`;
}

type StoredUpload = {
  storagePath: string;
  downloadUrl: string;
  sizeBytes: number;
};

async function writeInspectionMediaObject(params: {
  bookingId: string;
  stage: "pre" | "post";
  type: "image" | "video";
  fileName: string;
  contentType: string;
  bytes: Buffer;
  uid: string;
}): Promise<StoredUpload> {
  const safeName = sanitizeFileName(params.fileName);
  const ts = Date.now();
  const storagePath = `bookings/${params.bookingId}/inspections/${params.stage}/${ts}_${params.type}_${safeName}`;

  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);
  const token = randomUUID();

  await file.save(params.bytes, {
    contentType: params.contentType,
    resumable: false,
    metadata: {
      contentType: params.contentType,
      metadata: {
        bookingId: params.bookingId,
        driverId: params.uid,
        stage: params.stage,
        type: params.type,
        contentType: params.contentType,
        firebaseStorageDownloadTokens: token,
      },
      cacheControl: "public,max-age=3600",
    },
  });

  const downloadUrl = downloadUrlFor({
    bucketName: bucket.name,
    storagePath,
    token,
  });

  return {
    storagePath,
    downloadUrl,
    sizeBytes: params.bytes.length,
  };
}

export const uploadInspectionImageCall = onCall(async (request) => {
  requireAuth(request);

  const uid = requireAuthUid(request);
  const role = roleOf(request);
  const data = request.data || {};

  const bookingId = String(data.bookingId ?? "").trim();
  if (!bookingId) throw new Error("missing-bookingId");

  const stage = normalizeStage(data.stage);
  const type = normalizeType(data.type ?? "image");
  if (type !== "image") throw new Error("uploadInspectionImageCall-only-supports-image");

  const fileName = sanitizeFileName(String(data.fileName ?? `capture_${Date.now()}.jpg`));
  const contentType = String(data.contentType ?? "image/jpeg").trim() || "image/jpeg";
  const base64 = String(data.base64 ?? "").trim();
  if (!base64) throw new Error("missing-base64");

  let bytes: Buffer;
  try {
    const payload = base64.includes(",") ? base64.split(",").pop() || "" : base64;
    bytes = Buffer.from(payload, "base64");
  } catch {
    throw new Error("invalid-base64");
  }

  if (!bytes.length) throw new Error("empty-file");
  if (bytes.length > 20 * 1024 * 1024) throw new Error("image-too-large");

  await assertDriverCanUploadBooking({ bookingId, uid, role });

  const stored = await writeInspectionMediaObject({
    bookingId,
    stage,
    type,
    fileName,
    contentType,
    bytes,
    uid,
  });

  return {
    storagePath: stored.storagePath,
    downloadUrl: stored.downloadUrl,
    sizeBytes: stored.sizeBytes,
    contentType,
  };
});

export const uploadInspectionImage = onCall(async (request) => {
  if (!request.auth) throw new Error("unauthenticated");

  const uid = String(request.auth.uid ?? "");
  const role = String(request.auth.token.role ?? "");
  if (role !== "driver") throw new Error("permission-denied");

  const { bookingId, stage, fileName, contentType, base64 } = request.data || {};
  if (!bookingId || !stage || !fileName || !contentType || !base64) {
    throw new Error("missing-fields");
  }

  const rawBase64 = String(base64);
  const normalizedBase64 = rawBase64.includes(",") ? rawBase64.split(",").pop() || "" : rawBase64;
  const buf = Buffer.from(normalizedBase64, "base64");
  // Treat empty/tiny payload as invalid image bytes for probe and safety.
  if (buf.length <= 1) throw new Error("empty-file");

  const bookingIdStr = String(bookingId);
  const bookingSnap = await db.collection("bookings").doc(bookingIdStr).get();
  if (!bookingSnap.exists) throw new Error("booking-not-found");

  const assignedDriverId = String((bookingSnap.data()?.assigned?.driverId) ?? "");
  if (assignedDriverId !== uid) throw new Error("permission-denied");

  const bucket = admin.storage().bucket();
  const ts = Date.now();
  const safeStage = String(stage) === "post" ? "post" : "pre";
  const safeFileName = sanitizeFileName(String(fileName));
  const path = `bookings/${bookingIdStr}/inspections/${safeStage}/${ts}_image_${safeFileName}`;

  const file = bucket.file(path);
  await file.save(buf, {
    contentType: String(contentType),
    resumable: false,
    metadata: {
      metadata: {
        bookingId: bookingIdStr,
        driverId: uid,
        stage: safeStage,
        type: "image",
      },
    },
  });

  const [url] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + 31536000000,
  });

  const mediaRef = db.collection("bookings").doc(bookingIdStr).collection("inspectionMedia").doc();
  await mediaRef.set({
    bookingId: bookingIdStr,
    driverId: uid,
    stage: safeStage,
    type: "image",
    storagePath: path,
    downloadUrl: url,
    contentType: String(contentType),
    sizeBytes: buf.length,
    status: "uploaded",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    mediaId: mediaRef.id,
    storagePath: path,
    downloadUrl: url,
    sizeBytes: buf.length,
  };
});

function verifyBearerTokenFromRequest(req: any): Promise<admin.auth.DecodedIdToken> {
  const authHeader = String(req.headers?.authorization ?? "");
  const parts = authHeader.split(" ");
  if (parts.length !== 2 || parts[0] !== "Bearer" || !parts[1]) {
    throw new Error("unauthenticated");
  }
  return admin.auth().verifyIdToken(parts[1]);
}

type MultipartParsed = {
  fields: Record<string, string>;
  fileName: string;
  contentType: string;
  fileBuffer: Buffer;
};

function parseMultipartRequest(req: any): Promise<MultipartParsed> {
  return new Promise((resolve, reject) => {
    const fields: Record<string, string> = {};
    const chunks: Buffer[] = [];
    let fileName = "upload.bin";
    let contentType = "application/octet-stream";
    let gotFile = false;

    const bb = Busboy({
      headers: req.headers,
      limits: {
        files: 1,
        fileSize: 200 * 1024 * 1024,
      },
    });

    bb.on("field", (name, value) => {
      fields[String(name)] = String(value ?? "");
    });

    bb.on("file", (_name, file, info) => {
      gotFile = true;
      fileName = sanitizeFileName(String(info.filename || "upload.bin"));
      contentType = String(info.mimeType || "application/octet-stream");
      file.on("data", (d: Buffer) => chunks.push(d));
      file.on("limit", () => reject(new Error("file-too-large")));
    });

    bb.on("error", (err) => reject(err));
    bb.on("finish", () => {
      if (!gotFile) return reject(new Error("missing-file"));
      const fileBuffer = Buffer.concat(chunks);
      if (!fileBuffer.length) return reject(new Error("empty-file"));
      resolve({ fields, fileName, contentType, fileBuffer });
    });

    bb.end(req.rawBody);
  });
}

// ---------------------------------------------------------------------------
// CORS helper used by uploadInspectionMediaRequest and pingUpload.
// Explicitly sets headers instead of relying on corsHandler so that Safari
// preflight (OPTIONS) is handled deterministically on Cloud Run / 2nd-gen CF.
// ---------------------------------------------------------------------------
function applyUploadCors(req: any, res: any): boolean {
  const origin = String(req.headers?.origin ?? "");
  const allowed =
    origin === "https://pink-fleets-driver.web.app" ||
    origin === "https://pink-fleets-driver.firebaseapp.com" ||
    origin.startsWith("http://localhost:");
  const responseOrigin = allowed ? origin : "https://pink-fleets-driver.web.app";
  res.set("Access-Control-Allow-Origin", responseOrigin);
  res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Max-Age", "86400");
  if (req.method === "OPTIONS") {
    console.log("[uploadCors] OPTIONS preflight from origin:", origin);
    res.status(204).send("");
    return true;
  }
  return false;
}

export const pingUpload = onRequest(async (req, res) => {
  if (applyUploadCors(req, res)) return;
  console.log("[pingUpload] ping from origin:", req.headers?.origin ?? "(none)");
  sendJson(res, 200, { ok: true, message: "pong", ts: Date.now() });
});

export const uploadInspectionMediaRequest = onRequest(async (req, res) => {
  if (applyUploadCors(req, res)) return;
  try {
    console.log("[uploadInspectionMediaRequest] method:", req.method, "origin:", req.headers?.origin ?? "(none)");

    if (req.method !== "POST") {
      sendJson(res, 405, { error: "method-not-allowed" });
      return;
    }

    const token = await verifyBearerTokenFromRequest(req);
    const uid = String(token.uid ?? "");
    const role = String(token.role ?? "");
    if (!uid) throw new Error("unauthenticated");
    console.log("[uploadInspectionMediaRequest] uid:", uid, "role:", role);

    const parsed = await parseMultipartRequest(req);
    console.log("[uploadInspectionMediaRequest] parsed fields:", parsed.fields,
      "fileName:", parsed.fileName, "contentType:", parsed.contentType,
      "fileBuffer.length:", parsed.fileBuffer.length);

    const bookingId = String(parsed.fields.bookingId ?? "").trim();
    if (!bookingId) throw new Error("missing-bookingId");

    const stage = normalizeStage(parsed.fields.stage);
    const type = normalizeType(parsed.fields.type);

    await assertDriverCanUploadBooking({ bookingId, uid, role });

    const stored = await writeInspectionMediaObject({
      bookingId,
      stage,
      type,
      fileName: parsed.fileName,
      contentType: parsed.contentType,
      bytes: parsed.fileBuffer,
      uid,
    });

    console.log("[uploadInspectionMediaRequest] stored storagePath:", stored.storagePath, "sizeBytes:", stored.sizeBytes);

    // Write Firestore records server-side so the client NEVER needs to
    // write Firestore after upload (avoids Timestamp-in-arrayUnion web crash).
    const uploadMapForFs = {
      url: stored.downloadUrl,
      name: parsed.fileName,
      contentType: parsed.contentType,
      path: stored.storagePath,
      uploadedAt: admin.firestore.Timestamp.now(),
      type,
      stage,
      sizeBytes: stored.sizeBytes,
    };
    const mediaRef = db.collection("bookings").doc(bookingId)
      .collection("inspectionMedia").doc();
    await Promise.all([
      mediaRef.set({
        bookingId,
        driverId: uid,
        stage,
        type,
        fileName: parsed.fileName,
        storagePath: stored.storagePath,
        downloadUrl: stored.downloadUrl,
        contentType: parsed.contentType,
        sizeBytes: stored.sizeBytes,
        status: "uploaded",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      db.collection("bookings").doc(bookingId)
        .collection("driver_inspections").doc(stage)
        .set({
          stage,
          driverId: uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          uploads: admin.firestore.FieldValue.arrayUnion(uploadMapForFs),
        }, { merge: true }),
    ]);

    sendJson(res, 200, {
      ok: true,
      mediaId: mediaRef.id,
      storagePath: stored.storagePath,
      downloadUrl: stored.downloadUrl,
      sizeBytes: stored.sizeBytes,
      contentType: parsed.contentType,
      type,
      stage,
      fileName: parsed.fileName,
    });
  } catch (e: any) {
    const msg = String(e?.message ?? e ?? "upload-failed");
    console.error("[uploadInspectionMediaRequest] error:", msg);
    const code = msg === "unauthenticated" ? 401 : msg === "permission-denied" ? 403 : 400;
    sendJson(res, code, { error: msg });
  }
});

// ------------------ Notification helpers (reliable) ------------------
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);


export const uploadInspectionImageHttp = onRequest(async (req, res) => {
  if (applyUploadCors(req, res)) return;
  try {
      if (req.method !== "POST") {
        sendJson(res, 405, { error: "method-not-allowed" });
        return;
      }

      const authHeader = String(req.headers.authorization ?? "");
      if (!authHeader.startsWith("Bearer ")) {
        sendJson(res, 401, { error: "unauthenticated" });
        return;
      }

      const idToken = authHeader.substring("Bearer ".length);
      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;
      const role = String((decoded as any).role ?? "");
      if (role !== "driver") {
        sendJson(res, 403, { error: "permission-denied" });
        return;
      }

      const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
      const { bookingId, stage, fileName, contentType, base64 } = body || {};
      if (!bookingId || !stage || !fileName || !contentType || !base64) {
        sendJson(res, 400, { error: "missing-fields" });
        return;
      }

      const bookingIdStr = String(bookingId);
      const bookingSnap = await db.collection("bookings").doc(bookingIdStr).get();
      if (!bookingSnap.exists) {
        sendJson(res, 404, { error: "booking-not-found" });
        return;
      }

      const assignedDriverId = String((bookingSnap.data()?.assigned?.driverId) ?? "");
      if (assignedDriverId !== uid) {
        sendJson(res, 403, { error: "permission-denied" });
        return;
      }

      const rawBase64 = String(base64);
      const normalizedBase64 = rawBase64.includes(",") ? rawBase64.split(",").pop() || "" : rawBase64;
      const buf = Buffer.from(normalizedBase64, "base64");
      if (!buf.length) {
        sendJson(res, 400, { error: "empty-file" });
        return;
      }

      const bucket = admin.storage().bucket();
      const ts = Date.now();
      const safeStage = stage === "post" ? "post" : "pre";
      const safeFileName = sanitizeFileName(String(fileName));
      const path = `bookings/${bookingIdStr}/inspections/${safeStage}/${ts}_image_${safeFileName}`;
      const file = bucket.file(path);

      await file.save(buf, {
        contentType: String(contentType),
        metadata: {
          metadata: {
            bookingId: bookingIdStr,
            driverId: uid,
            stage: safeStage,
            type: "image",
          },
        },
      });

      const [url] = await file.getSignedUrl({ action: "read", expires: Date.now() + 31536000000 });

      // Write Firestore records server-side so the client never needs to write
      // Firestore after upload (avoids Timestamp-in-arrayUnion web crash).
      const uploadMapForFs = {
        url,
        name: safeFileName,
        contentType: String(contentType),
        path,
        uploadedAt: admin.firestore.Timestamp.now(),
        type: "image",
        stage: safeStage,
        sizeBytes: buf.length,
      };
      const mediaRef = db.collection("bookings").doc(bookingIdStr).collection("inspectionMedia").doc();
      await Promise.all([
        mediaRef.set({
          bookingId: bookingIdStr,
          driverId: uid,
          stage: safeStage,
          type: "image",
          storagePath: path,
          downloadUrl: url,
          contentType: String(contentType),
          sizeBytes: buf.length,
          fileName: safeFileName,
          status: "uploaded",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
        db.collection("bookings").doc(bookingIdStr)
          .collection("driver_inspections").doc(safeStage)
          .set({
            stage: safeStage,
            driverId: uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            uploads: admin.firestore.FieldValue.arrayUnion(uploadMapForFs),
          }, { merge: true }),
      ]);

      sendJson(res, 200, {
        ok: true,
        mediaId: mediaRef.id,
        storagePath: path,
        downloadUrl: url,
        sizeBytes: buf.length,
        type: "image",
        stage: safeStage,
        fileName: safeFileName,
      });
  } catch (e: any) {
    sendJson(res, 500, { ok: false, error: String(e?.message ?? e) });
  }
});

// ----------- Save Inspection Notes + Checklist (server-side, avoids Firestore Web SDK crash) -----------
export const saveInspectionHttp = onRequest(async (req, res) => {
  if (applyUploadCors(req, res)) return;
  try {
    if (req.method !== "POST") {
      sendJson(res, 405, { error: "method-not-allowed" });
      return;
    }

    const authHeader = String(req.headers.authorization ?? "");
    if (!authHeader.startsWith("Bearer ")) {
      sendJson(res, 401, { error: "unauthenticated" });
      return;
    }

    const idToken = authHeader.substring("Bearer ".length);
    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;
    const role = String((decoded as any).role ?? "");
    if (role !== "driver") {
      sendJson(res, 403, { error: "permission-denied" });
      return;
    }

    const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    const { bookingId, stage, notes, checklist, sentToDispatcher } = body || {};

    if (!bookingId || !stage) {
      sendJson(res, 400, { error: "missing-fields" });
      return;
    }

    const bookingIdStr = String(bookingId);
    const safeStage = stage === "post" ? "post" : "pre";

    const bookingSnap = await db.collection("bookings").doc(bookingIdStr).get();
    if (!bookingSnap.exists) {
      sendJson(res, 404, { error: "booking-not-found" });
      return;
    }
    const assignedDriverId = String((bookingSnap.data()?.assigned?.driverId) ?? "");
    if (assignedDriverId !== uid) {
      sendJson(res, 403, { error: "permission-denied" });
      return;
    }

    // Sanitize inputs
    const safeNotes = String(notes ?? "").substring(0, 2000);
    const rawChecklist = (typeof checklist === "object" && checklist !== null && !Array.isArray(checklist))
      ? checklist as Record<string, unknown>
      : {};
    const safeChecklist: Record<string, boolean> = {};
    for (const [k, v] of Object.entries(rawChecklist)) {
      if (typeof k === "string" && (v === true || v === false)) {
        safeChecklist[k] = v as boolean;
      }
    }

    const isSendToDispatcher = sentToDispatcher === true;

    // Write to driver_inspections sub-collection (stream subscription source in client)
    const inspDocRef = db.collection("bookings").doc(bookingIdStr)
      .collection("driver_inspections").doc(safeStage);
    const inspData: Record<string, any> = {
      stage: safeStage,
      driverId: uid,
      notes: safeNotes,
      checklist: safeChecklist,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (isSendToDispatcher) {
      inspData.sentToDispatcher = true;
      inspData.sentToDispatcherAt = admin.firestore.FieldValue.serverTimestamp();
    }

    // Write denormalised fields to the top-level booking document
    const bookingUpdate: Record<string, any> = {
      [`inspection.${safeStage}.notes`]: safeNotes,
      [`inspection.${safeStage}.checklist`]: safeChecklist,
      [`inspection.${safeStage}.updatedAt`]: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (isSendToDispatcher) {
      bookingUpdate[`inspection.${safeStage}.submitted`] = true;
      bookingUpdate[`inspection.${safeStage}.submittedAt`] = admin.firestore.FieldValue.serverTimestamp();
      bookingUpdate[`inspection.${safeStage}.submittedBy`] = uid;
    }

    await Promise.all([
      inspDocRef.set(inspData, { merge: true }),
      db.collection("bookings").doc(bookingIdStr).set(bookingUpdate, { merge: true }),
    ]);

    sendJson(res, 200, { ok: true });
  } catch (e: any) {
    sendJson(res, 500, { ok: false, error: String(e?.message ?? e) });
  }
});

async function sendToTokens(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, any>,
  options?: { channelId?: string }
) {
  if (!tokens.length) return { sent: 0, failed: 0, removed: 0, deadTokens: [] as string[] };

  const payloadData = data
    ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]))
    : undefined;

  const msg: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title, body },
    data: payloadData,
    android: {
      priority: "high",
      notification: {
        channelId: options?.channelId ?? "pink_fleets",
        sound: "default",
      },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: "default", contentAvailable: true } },
    },
  };

  const resp = await admin.messaging().sendEachForMulticast(msg);

  let failed = 0;
  const deadTokens: string[] = [];

  resp.responses.forEach((r, idx) => {
    if (!r.success) {
      failed++;
      const code = (r.error as any)?.code as string | undefined;
      if (code && DEAD_TOKEN_CODES.has(code)) deadTokens.push(tokens[idx]);
    }
  });

  return { sent: tokens.length - failed, failed, removed: deadTokens.length, deadTokens };
}

async function removeDeadDriverTokens(driverUid: string, deadTokens: string[]) {
  if (!deadTokens.length) return;
  await db.collection("drivers").doc(driverUid).set(
    { fcmTokens: admin.firestore.FieldValue.arrayRemove(...deadTokens) },
    { merge: true }
  );
}

// ------------------ Notify Driver (Admin or Dispatcher) ------------------
export const notifyDriver = onCall(async (request) => {
  requireAdminOrDispatcher(request);

  const { driverUid, title, body, data } = request.data || {};
  if (!driverUid || !title || !body) throw new Error("Missing driverUid/title/body");

  const doc = await db.collection("drivers").doc(String(driverUid)).get();
  const tokens = (doc.data()?.fcmTokens ?? []) as string[];

  const resp = await sendToTokens(tokens, String(title), String(body), data, {
    channelId: "pink_fleets_driver",
  });

  if (resp.deadTokens.length) await removeDeadDriverTokens(String(driverUid), resp.deadTokens);

  const actor = callableActorMeta(request);
  await logAudit({
    ...actor,
    action: "notify_driver",
    targetPath: `drivers/${String(driverUid)}`,
    after: { title: String(title), body: String(body), sent: resp.sent, failed: resp.failed },
  });

  return resp;
});

// ------------------ Notify Rider (Admin only) ------------------
export const notifyRider = onCall(async (request) => {
  requireAdmin(request);

  const { riderUid, title, body, data } = request.data || {};
  if (!riderUid || !title || !body) throw new Error("Missing riderUid/title/body");

  const doc = await db.collection("riders").doc(String(riderUid)).get();
  const tokens = (doc.data()?.fcmTokens ?? []) as string[];

  const resp = await sendToTokens(tokens, String(title), String(body), data, {
    channelId: "pink_fleets_rider",
  });

  const actor = callableActorMeta(request);
  await logAudit({
    ...actor,
    action: "notify_rider",
    targetPath: `riders/${String(riderUid)}`,
    after: { title: String(title), body: String(body), sent: resp.sent, failed: resp.failed },
  });

  return resp;
});

// ------------------ Notify Dispatchers (Driver/Admin/Dispatcher) ------------------
export const notifyDispatchers = onCall(async (request) => {
  requireAuth(request);

  const { bookingId, stage } = request.data || {};
  if (!bookingId) throw new Error("Missing bookingId");

  const snap = await db.collection("dispatchers").get();
  const adminSnap = await db.collection("admins").get();
  const tokens: string[] = [];

  snap.docs.forEach((d) => {
    const data = d.data() || {};
    const t = (data.fcmTokens ?? []) as string[];
    t.forEach((tok) => tokens.push(tok));
  });

  adminSnap.docs.forEach((d) => {
    const data = d.data() || {};
    const t = (data.fcmTokens ?? []) as string[];
    t.forEach((tok) => tokens.push(tok));
  });

  const title = "Driver inspection submitted";
  const body = stage
    ? `Booking ${String(bookingId).substring(0, 8)} • ${String(stage).toUpperCase()} inspection`
    : `Booking ${String(bookingId).substring(0, 8)} inspection submitted`;

  const resp = await sendToTokens(tokens, title, body, {
    type: "driver_inspection",
    bookingId: String(bookingId),
    stage: stage ? String(stage) : "",
  }, {
    channelId: "pink_fleets_dispatcher",
  });

  const actor = callableActorMeta(request);
  await logAudit({
    ...actor,
    action: "notify_dispatchers",
    targetPath: "dispatchers/*",
    after: { bookingId: String(bookingId), stage: stage ? String(stage) : "", sent: resp.sent, failed: resp.failed },
  });

  return resp;
});

// ------------------ Create Driver User (Admin only) ------------------
export const createDriverUser = onCall(async (request) => {
  requireAdmin(request);

  const { email, password, name } = request.data || {};
  if (!email || !password) throw new Error("Missing email/password");

  const user = await admin.auth().createUser({
    email: String(email).trim(),
    password: String(password),
    displayName: name ? String(name).trim() : undefined,
  });

  await admin.auth().setCustomUserClaims(user.uid, { role: "driver" });

  await db.collection("drivers").doc(user.uid).set(
    {
      name: name ? String(name).trim() : "Driver",
      approved: false,
      active: true,
      status: "offline",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const actor = callableActorMeta(request);
  await logAudit({
    ...actor,
    action: "create_driver_user",
    targetPath: `drivers/${user.uid}`,
    after: { uid: user.uid, email: String(email).trim(), name: name ? String(name).trim() : "Driver" },
  });

  return { uid: user.uid };
});

// ======================================================================
// ======================= DISPATCH ENGINE ===============================
// ======================================================================

type OfferStatus = "sent" | "delivered" | "accepted" | "declined" | "expired" | "cancelled";

function nowTs() {
  return admin.firestore.Timestamp.now();
}
function minutesFromNow(min: number) {
  return admin.firestore.Timestamp.fromMillis(Date.now() + min * 60_000);
}

async function tryLockDriverForOffer(params: {
  driverId: string;
  bookingId: string;
  offerId: string;
  expiresAt: admin.firestore.Timestamp;
}) {
  const driverRef = db.collection("drivers").doc(params.driverId);
  return await db.runTransaction(async (tx) => {
    const snap = await tx.get(driverRef);
    if (!snap.exists) return false;
    const d = snap.data() || {};

    const status = String(d.status ?? "offline");
    const activeOfferId = String(d.activeOfferId ?? "");
    if (status !== "online") return false;
    if (activeOfferId) return false;

    tx.set(
      driverRef,
      {
        status: "offered",
        activeOfferId: params.offerId,
        activeOfferBookingId: params.bookingId,
        activeBookingId: admin.firestore.FieldValue.delete(),
        offerExpiresAt: params.expiresAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return true;
  });
}

type EligibleDriver = {
  uid: string;
  vehicleId?: string;
  tokens: string[];
  lastLocation?: { lat: number; lng: number; updatedAtMs?: number };
  lastAssignedAtMs?: number;
  acceptRate?: number;
};

async function getEligibleDrivers(): Promise<EligibleDriver[]> {
  const snap = await db
    .collection("drivers")
    .where("active", "==", true)
    .where("approved", "==", true)
    .where("status", "==", "online")
    .limit(50)
    .get();

  return snap.docs.map((d) => {
    const data = d.data() || {};
    const tokens = (data.fcmTokens ?? []) as string[];

    // driver_app writes:
    // lastLocation: { lat, lng, updatedAt }
    const ll = (data.lastLocation ?? null) as any;
    let lastLocation: EligibleDriver["lastLocation"];

    if (ll && typeof ll === "object") {
      const lat = Number(ll.lat);
      const lng = Number(ll.lng);
      const ts = ll.updatedAt as admin.firestore.Timestamp | undefined;
      if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
        lastLocation = { lat, lng, updatedAtMs: ts ? ts.toMillis() : undefined };
      }
    }

    const lastAssignedAt = data.lastAssignedAt as admin.firestore.Timestamp | undefined;

    return {
      uid: d.id,
      vehicleId: data.activeVehicleId || data.vehicleId,
      tokens,
      lastLocation,
      lastAssignedAtMs: lastAssignedAt ? lastAssignedAt.toMillis() : undefined,
      acceptRate: typeof data.acceptRate === "number" ? data.acceptRate : undefined,
    };
  });
}

async function createOffer(params: {
  bookingId: string;
  driverId: string;
  attemptNumber: number;
  expiresAt: admin.firestore.Timestamp;
}) {
  const offerRef = db.collection("booking_offers").doc();
  const offer = {
    bookingId: params.bookingId,
    driverId: params.driverId,
    status: "sent" as OfferStatus,
    attemptNumber: params.attemptNumber,
    sentAt: nowTs(),
    expiresAt: params.expiresAt,
    acknowledgedAt: null,
    respondedAt: null,
    schemaVersion: 1,
  };
  await offerRef.set(offer, { merge: true });
  return { offerId: offerRef.id, offer };
}

async function sendOfferToDriver(
  driverId: string,
  tokens: string[],
  bookingId: string,
  offerId: string,
  expiresAt: admin.firestore.Timestamp
) {
  const title = "New Ride Offer";
  const body = "Tap to accept or decline.";

  const data = {
    type: "booking_offer",
    bookingId,
    offerId,
    expiresAt: expiresAt.toMillis(),
  };

  const resp = await sendToTokens(tokens, title, body, data, {
    channelId: "pink_fleets_driver",
  });

  if (resp.deadTokens.length) await removeDeadDriverTokens(driverId, resp.deadTokens);
  return resp;
}

function dist2(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const dx = a.lat - b.lat;
  const dy = a.lng - b.lng;
  return dx * dx + dy * dy;
}

function clamp01(v: number) {
  if (Number.isNaN(v)) return 0;
  return Math.max(0, Math.min(1, v));
}

function minutesSince(tsMs?: number) {
  if (!tsMs) return Number.POSITIVE_INFINITY;
  return (Date.now() - tsMs) / 60000;
}

async function dispatchNextDriver(bookingId: string) {
  const bRef = db.collection("bookings").doc(bookingId);
  const bSnap = await bRef.get();
  if (!bSnap.exists) throw new Error("booking-not-found");

  const b = bSnap.data() || {};
  const status = String(b.status ?? "");

  if (status === "cancelled" || status === "completed") {
    return { ok: false, reason: "booking-not-dispatchable" };
  }

  // Payment gate (do not dispatch unless paid)
  const privRef = db.collection("bookings_private").doc(bookingId);
  const privSnap = await privRef.get();
  const priv = privSnap.data() || {};
  const paymentStatus = String(priv.paymentStatus ?? "unknown").toLowerCase();
  if (paymentStatus !== "paid") {
    await bRef.set(
      { status: "dispatching", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
    return { ok: false, reason: "unpaid" };
  }

  const attempt = Number(b.dispatchAttempt ?? 0) + 1;

  const drivers = await getEligibleDrivers();
  if (!drivers.length) {
    await bRef.set(
      {
        status: "dispatching",
        dispatchAttempt: attempt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { ok: false, reason: "no-drivers-online" };
  }

  // Use pickupGeo if you store it later; otherwise default NOLA center
  let pickup = { lat: 29.9511, lng: -90.0715 };
  const pg = (priv.pickupGeo ?? null) as any;
  if (pg) {
    if (typeof pg.latitude === "number" && typeof pg.longitude === "number") {
      pickup = { lat: pg.latitude, lng: pg.longitude };
    } else if (typeof pg.lat === "number" && typeof pg.lng === "number") {
      pickup = { lat: pg.lat, lng: pg.lng };
    }
  }

  const COOLDOWN_MINUTES = 8;
  const STALE_LOCATION_MINUTES = 5;

  drivers.sort((x, y) => {
    const xl = x.lastLocation;
    const yl = y.lastLocation;

    const xHasLoc = !!xl;
    const yHasLoc = !!yl;
    if (!xHasLoc && yHasLoc) return 1;
    if (xHasLoc && !yHasLoc) return -1;

    const xDist = xHasLoc ? dist2({ lat: xl!.lat, lng: xl!.lng }, pickup) : 9999;
    const yDist = yHasLoc ? dist2({ lat: yl!.lat, lng: yl!.lng }, pickup) : 9999;

    const xAssignMin = minutesSince(x.lastAssignedAtMs);
    const yAssignMin = minutesSince(y.lastAssignedAtMs);

    const xFairnessPenalty = 1 - clamp01(xAssignMin / 60); // 0 is best (older)
    const yFairnessPenalty = 1 - clamp01(yAssignMin / 60);

    const xAcceptPenalty = 1 - clamp01(x.acceptRate ?? 0.5);
    const yAcceptPenalty = 1 - clamp01(y.acceptRate ?? 0.5);

    const xCooldownPenalty = xAssignMin < COOLDOWN_MINUTES ? 2 : 0;
    const yCooldownPenalty = yAssignMin < COOLDOWN_MINUTES ? 2 : 0;

    const xLocAgeMin = minutesSince(xl?.updatedAtMs);
    const yLocAgeMin = minutesSince(yl?.updatedAtMs);
    const xStalePenalty = xLocAgeMin > STALE_LOCATION_MINUTES ? 1.5 : 0;
    const yStalePenalty = yLocAgeMin > STALE_LOCATION_MINUTES ? 1.5 : 0;

    const xScore = xDist * 1000 + xFairnessPenalty * 2 + xAcceptPenalty * 1.2 + xCooldownPenalty + xStalePenalty;
    const yScore = yDist * 1000 + yFairnessPenalty * 2 + yAcceptPenalty * 1.2 + yCooldownPenalty + yStalePenalty;

    if (xScore !== yScore) return xScore - yScore;

    // tie-breakers
    if (xDist !== yDist) return xDist - yDist;
    if (xAssignMin !== yAssignMin) return yAssignMin - xAssignMin; // older assignment wins
    return (y.acceptRate ?? 0) - (x.acceptRate ?? 0);
  });

  const expiresAt = minutesFromNow(1);

  let offerId: string | null = null;
  let chosen: EligibleDriver | null = null;

  for (const candidate of drivers) {
    const offerRef = db.collection("booking_offers").doc();
    const locked = await tryLockDriverForOffer({
      driverId: candidate.uid,
      bookingId,
      offerId: offerRef.id,
      expiresAt,
    });

    if (!locked) {
      continue;
    }

    await offerRef.set(
      {
        bookingId,
        driverId: candidate.uid,
        status: "sent" as OfferStatus,
        attemptNumber: attempt,
        sentAt: nowTs(),
        expiresAt,
        acknowledgedAt: null,
        respondedAt: null,
        schemaVersion: 1,
      },
      { merge: true }
    );

    offerId = offerRef.id;
    chosen = candidate;
    break;
  }

  if (!offerId || !chosen) {
    await bRef.set(
      {
        status: "dispatching",
        dispatchAttempt: attempt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { ok: false, reason: "no-drivers-available" };
  }

  await bRef.set(
    {
      status: "offered",
      dispatchAttempt: attempt,
      activeOfferId: offerId,
      offerExpiresAt: expiresAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await sendOfferToDriver(chosen.uid, chosen.tokens, bookingId, offerId, expiresAt);

  return { ok: true, offerId, driverId: chosen.uid, attempt };
}

// ------------------ Start Dispatch (Admin/Dispatcher) ------------------
export const dispatchBooking = onCall(async (request) => {
  requireAdminOrDispatcher(request);

  const { bookingId } = request.data || {};
  if (!bookingId) throw new Error("Missing bookingId");

  const bRef = db.collection("bookings").doc(String(bookingId));
  await bRef.set(
    { status: "dispatching", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  const result = await dispatchNextDriver(String(bookingId));
  const actor = callableActorMeta(request);
  await logAudit({
    ...actor,
    action: "dispatch_booking",
    targetPath: `bookings/${String(bookingId)}`,
    after: { result },
  });

  return result;
});

// ✅ AUTO-DISPATCH TRIGGER (NEW)
// Automatically runs when ANY booking doc is created.
// This is the production behavior you wanted.
export const autoDispatchOnBookingCreate = onDocumentCreated(
  "bookings/{bookingId}",
  async (event) => {
    const bookingId = String(event.params.bookingId);
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const status = String(data.status ?? "pending");

    // Only auto-dispatch for fresh bookings (don’t mess with completed/cancelled)
    if (status === "cancelled" || status === "completed") return;

    // Mark dispatching (merge safe)
    await db.collection("bookings").doc(bookingId).set(
      {
        status: "dispatching",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Kick first offer (dispatchNextDriver will payment-gate)
    try {
      await dispatchNextDriver(bookingId);
    } catch (_) {
      // no-op, sweep will pick up
    }
  }
);

export const onBookingPaymentStatusPaid = onDocumentUpdated(
  "bookings_private/{bookingId}",
  async (event) => {
    const bookingId = String(event.params.bookingId);
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeStatus = String(before.paymentStatus ?? "").toLowerCase();
    const afterStatus = String(after.paymentStatus ?? "").toLowerCase();
    if (beforeStatus === afterStatus) return;
    if (afterStatus !== "paid") return;

    await db.collection("bookings").doc(bookingId).set(
      {
        status: "dispatching",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    try {
      await dispatchNextDriver(bookingId);
    } catch (_) {
      // sweep will retry
    }
  }
);

// ------------------ Driver ACK Offer (Driver) ------------------
export const ackOffer = onCall(async (request) => {
  requireDriver(request);

  const { offerId } = request.data || {};
  if (!offerId) throw new Error("Missing offerId");

  const uid = requireAuthUid(request);
  const ref = db.collection("booking_offers").doc(String(offerId));

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error("offer-not-found");

    const offer = snap.data() || {};
    if (String(offer.driverId) !== uid) throw new Error("permission-denied");

    const st = String(offer.status);
    if (st === "accepted" || st === "declined" || st === "expired") return;

    tx.set(ref, { acknowledgedAt: nowTs(), status: "delivered" }, { merge: true });
  });

  return { ok: true };
});

// ------------------ Driver Respond Offer (Driver) ------------------
export const respondToOffer = onCall(async (request) => {
  requireDriver(request);

  const { offerId, bookingId, decision } = request.data || {};
  if (!offerId || !bookingId || !decision) throw new Error("Missing offerId/bookingId/decision");

  const uid = requireAuthUid(request);
  const decisionNorm = String(decision).toLowerCase();
  if (decisionNorm !== "accept" && decisionNorm !== "decline") {
    throw new Error("decision must be accept|decline");
  }

  const offerRef = db.collection("booking_offers").doc(String(offerId));
  const bookingRef = db.collection("bookings").doc(String(bookingId));
  const driverRef = db.collection("drivers").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const [offerSnap, bookingSnap] = await Promise.all([tx.get(offerRef), tx.get(bookingRef)]);
    if (!offerSnap.exists) throw new Error("offer-not-found");
    if (!bookingSnap.exists) throw new Error("booking-not-found");

    const offer = offerSnap.data() || {};
    const booking = bookingSnap.data() || {};

    if (String(offer.driverId) !== uid) throw new Error("permission-denied");
    if (String(offer.bookingId) !== String(bookingId)) throw new Error("offer-booking-mismatch");

    const currentOfferStatus = String(offer.status);
    if (currentOfferStatus === "accepted" || currentOfferStatus === "declined" || currentOfferStatus === "expired") {
      return { ok: false, reason: "offer-already-closed" };
    }

    const activeOfferId = String(booking.activeOfferId ?? "");
    if (activeOfferId && activeOfferId !== String(offerId)) {
      tx.set(offerRef, { status: "expired", respondedAt: nowTs() }, { merge: true });
      return { ok: false, reason: "offer-no-longer-active" };
    }

    const bookingStatus = String(booking.status ?? "");
    if (bookingStatus === "accepted" || bookingStatus === "cancelled" || bookingStatus === "completed") {
      tx.set(offerRef, { status: "expired", respondedAt: nowTs() }, { merge: true });
      return { ok: false, reason: "booking-not-available" };
    }

    if (decisionNorm === "decline") {
      tx.set(offerRef, { status: "declined", respondedAt: nowTs() }, { merge: true });
      tx.set(
        driverRef,
        {
          status: "online",
          activeOfferId: admin.firestore.FieldValue.delete(),
          activeOfferBookingId: admin.firestore.FieldValue.delete(),
          activeBookingId: admin.firestore.FieldValue.delete(),
          offerExpiresAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      tx.set(
        bookingRef,
        {
          status: "dispatching",
          activeOfferId: admin.firestore.FieldValue.delete(),
          offerExpiresAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { ok: true, decision: "declined" };
    }

    const driverSnap = await tx.get(driverRef);
    const driverData = driverSnap.data() || {};
    const vehicleId = String(driverData.activeVehicleId ?? driverData.vehicleId ?? "");

    tx.set(offerRef, { status: "accepted", respondedAt: nowTs() }, { merge: true });

    tx.set(
      bookingRef,
      {
        status: "accepted",
        driverId: uid,
        assigned: {
          driverId: uid,
          vehicleId: vehicleId || null,
          assignedAt: nowTs(),
        },
        activeOfferId: admin.firestore.FieldValue.delete(),
        offerExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // fairness tracking
    tx.set(
      driverRef,
      {
        lastAssignedAt: nowTs(),
        status: "busy",
        activeOfferId: admin.firestore.FieldValue.delete(),
        activeOfferBookingId: String(bookingId),
        activeBookingId: String(bookingId),
        offerExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { ok: true, decision: "accepted", driverId: uid, vehicleId };
  });

  // If declined, immediately try next driver
  if ((result as any)?.ok && (result as any)?.decision === "declined") {
    try {
      await dispatchNextDriver(String(bookingId));
    } catch (_) {}
  }

  const actor = callableActorMeta(request);
  await logAudit({
    ...actor,
    action: "respond_to_offer",
    targetPath: `booking_offers/${String(offerId)}`,
    before: { bookingId: String(bookingId) },
    after: { decision: decisionNorm, result },
  });

  return result;
});

// ------------------ Scheduled: expire offers + re-dispatch ------------------
export const dispatchSweep = onSchedule("every 1 minutes", async () => {
  const now = nowTs();

  const snap = await db
    .collection("booking_offers")
    .where("status", "in", ["sent", "delivered"])
    .where("expiresAt", "<=", now)
    .limit(50)
    .get();

  if (snap.empty) return;

  for (const doc of snap.docs) {
    const offerId = doc.id;
    const offer = doc.data() || {};
    const bookingId = String(offer.bookingId ?? "");
    const driverId = String(offer.driverId ?? "");

    await doc.ref.set({ status: "expired", respondedAt: nowTs() }, { merge: true });

    if (driverId) {
      await db.collection("drivers").doc(driverId).set(
        {
          status: "online",
          activeOfferId: admin.firestore.FieldValue.delete(),
          activeOfferBookingId: admin.firestore.FieldValue.delete(),
          activeBookingId: admin.firestore.FieldValue.delete(),
          offerExpiresAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    if (!bookingId) continue;

    const bRef = db.collection("bookings").doc(bookingId);

    await db.runTransaction(async (tx) => {
      const bSnap = await tx.get(bRef);
      if (!bSnap.exists) return;

      const b = bSnap.data() || {};
      if (String(b.activeOfferId ?? "") !== offerId) return;

      tx.set(
        bRef,
        {
          status: "dispatching",
          activeOfferId: admin.firestore.FieldValue.delete(),
          offerExpiresAt: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    try {
      await dispatchNextDriver(bookingId);
    } catch (_) {}
  }
});

// ------------------ Sync driver location -> booking ------------------
export const syncDriverLocationToBooking = onDocumentUpdated(
  "drivers/{driverId}",
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const nestedLocation = after.lastLocation as any;
    const lat =
      typeof after.lat === "number"
        ? after.lat
        : typeof nestedLocation?.lat === "number"
          ? nestedLocation.lat
          : typeof nestedLocation?.latitude === "number"
            ? nestedLocation.latitude
            : null;
    const lng =
      typeof after.lng === "number"
        ? after.lng
        : typeof nestedLocation?.lng === "number"
          ? nestedLocation.lng
          : typeof nestedLocation?.longitude === "number"
            ? nestedLocation.longitude
            : null;
    const locationUpdatedAt =
      after.updatedAt ?? nestedLocation?.updatedAt ?? admin.firestore.FieldValue.serverTimestamp();
    if (lat == null || lng == null) return;

    const lastLocation = {
      lat,
      lng,
      updatedAt: locationUpdatedAt,
    };

    const bookingId = String(after.activeBookingId ?? "");
    if (!bookingId) return;

    const driverId = String(event.params.driverId);

    try {
      await db.collection("bookings").doc(bookingId).update({
        driverId: driverId,
        "assigned.driverId": driverId,
        "assigned.driverLocation": lastLocation,
        driverLocation: lastLocation,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ignore if booking missing
    }
  }
);

// ------------------ Unlock driver when booking ends ------------------
export const unlockDriverOnBookingEnd = onDocumentUpdated(
  "bookings/{bookingId}",
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const status = String(after.status ?? "");
    if (status !== "completed" && status !== "cancelled") return;

    const assigned = (after.assigned ?? {}) as any;
    const driverId = String(assigned.driverId ?? "");
    if (!driverId) return;

    await db.collection("drivers").doc(driverId).set(
      {
        status: "online",
        activeBookingId: admin.firestore.FieldValue.delete(),
        activeOfferId: admin.firestore.FieldValue.delete(),
        activeOfferBookingId: admin.firestore.FieldValue.delete(),
        offerExpiresAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
);

// ======================================================================
// ================== CREATE BOOKING HTTP (v2 onRequest) ================
// ======================================================================
//
// Replaces the web-callable createBookingRider for rider_app web builds.
// Root cause fixed: Firestore Web SDK v11.x crashes ("INTERNAL ASSERTION
// FAILED: Unexpected state") when it deserialises GeoPoint fields that
// were written by the server into bookings/.  Fix: store GeoPoints ONLY
// in bookings_private so the live screen subscription stays crash-free.
//
// Auth  : Bearer <Firebase ID token> in Authorization header
// CORS  : corsHandler (origin: true) — covers all Pink Fleets domains
// Pricing: computed server-side from admin_settings/app — client inputs
//          are vehicle/duration/tier/flags only (no pricingSnapshot)
//
export const createBookingHttp = onRequest(async (req, res) => {
  // CORS first (handles OPTIONS preflight automatically)
  corsHandler(req, res, async () => {
    try {
      if (req.method !== "POST") {
        sendJson(res, 405, { error: "method-not-allowed" });
        return;
      }
      const authHeader = String(req.headers.authorization ?? "");
      if (!authHeader.startsWith("Bearer ")) {
        sendJson(res, 401, { error: "unauthenticated" });
        return;
      }
      const idToken = authHeader.substring("Bearer ".length);
      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;
      const email = decoded.email || null;
      const name = decoded.name || null;
      const phone = decoded.phone_number || null;

      const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
      const {
        pickupAddress, pickupPlaceId, pickupLat, pickupLng,
        dropoffAddress, dropoffPlaceId, dropoffLat, dropoffLng,
        scheduledStartMs, durationHours, vehicleType, passengers, stops
      } = body || {};

      const bookingRef = admin.firestore().collection("bookings").doc();
      const bookingId = bookingRef.id;
      const nowServer = admin.firestore.FieldValue.serverTimestamp();

      // Write bookings/{bookingId}
      await bookingRef.set({
        status: "dispatching",
        riderId: uid,
        riderUid: uid,
        riderEmail: bookingRiderEmail,
        pickupAddress: pickupAddress ?? null,
        pickupLat: typeof pickupLat === "number" ? pickupLat : null,
        pickupLng: typeof pickupLng === "number" ? pickupLng : null,
        dropoffAddress: dropoffAddress ?? null,
        dropoffLat: typeof dropoffLat === "number" ? dropoffLat : null,
        dropoffLng: typeof dropoffLng === "number" ? dropoffLng : null,
        vehicleType: vehicleType ?? null,
        requestedVehicle: vehicleType ?? null,
        driverId: null,
        riderInfo: {
          uid,
          email: bookingRiderEmail,
          name: bookingRiderName,
          phone: bookingRiderPhone,
        },
        assigned: {},
        createdAt: nowServer,
        updatedAt: nowServer,
      });

      // Write bookings_private/{bookingId}
      await admin.firestore().collection("bookings_private").doc(bookingId).set({
        pickupAddress,
        dropoffAddress,
        pickupPlaceId: pickupPlaceId ?? null,
        dropoffPlaceId: dropoffPlaceId ?? null,
        pickupGeo: (typeof pickupLat === "number" && typeof pickupLng === "number") ? new admin.firestore.GeoPoint(pickupLat, pickupLng) : null,
        dropoffGeo: (typeof dropoffLat === "number" && typeof dropoffLng === "number") ? new admin.firestore.GeoPoint(dropoffLat, dropoffLng) : null,
        scheduledStart: typeof scheduledStartMs === "number" ? admin.firestore.Timestamp.fromMillis(scheduledStartMs) : null,
        durationHours: durationHours ?? null,
        passengers: passengers ?? null,
        vehicleType: vehicleType ?? null,
        stops: stops ?? null,
        pricingSnapshot: { total: 0, schemaVersion: 1 },
        paymentStatus: "paid",
        createdAt: nowServer,
        updatedAt: nowServer,
      });

      sendJson(res, 200, { ok: true, bookingId });
    } catch (e: any) {
      sendJson(res, 500, { ok: false, error: String(e?.message ?? e) });
    }
  });
});

// ======================================================================
// ============== CHARGE BOOKING ADJUSTMENTS (Stripe-ready stub) ========
// ======================================================================
//
// Called by dispatcher/admin when saving Adjustments / Surcharges.
// Stub mode: computes final totals, writes to bookings_private, returns ok.
// Stripe mode (TODO): create off-session PaymentIntent for the delta.
//
export const chargeBookingAdjustments = onCall(async (request) => {
  requireAdminOrDispatcher(request);

  const { bookingId, fuelSurchargePct, parkingCents, tollsCents, venueCents, notes } = request.data ?? {};

  if (!bookingId) throw new Error("missing-bookingId");

  const bpRef  = db.collection("bookings_private").doc(String(bookingId));
  const bpSnap = await bpRef.get();
  if (!bpSnap.exists) throw new Error("booking-private-not-found");

  const bp = bpSnap.data() ?? {};

  // Read original base so we can compute fuel surcharge delta correctly
  const pricing      = (bp.pricing ?? {}) as Record<string, any>;
  const original     = (pricing.original ?? {}) as Record<string, any>;
  const baseCents    = Number(original.baseCents    ?? (bp.pricingSnapshot as any)?.base ?? 0);
  const gratuityCents = Number(original.gratuityCents ?? (bp.pricingSnapshot as any)?.gratuity ?? 0);
  const origTotal    = Number(original.totalCents   ?? (bp.pricingSnapshot as any)?.total ?? 0);

  const fuelPct           = Number(fuelSurchargePct ?? 0);
  const adjParkingCents   = Number(parkingCents     ?? 0);
  const adjTollsCents     = Number(tollsCents       ?? 0);
  const adjVenueCents     = Number(venueCents       ?? 0);

  // Fuel surcharge delta: applied to (base + gratuity)
  const fuelAdjCents       = Math.round((baseCents + gratuityCents) * (fuelPct / 100));
  const adjustmentsTotalCents = fuelAdjCents + adjParkingCents + adjTollsCents + adjVenueCents;
  const finalTotalCents    = origTotal + adjustmentsTotalCents;
  const deltaCents         = finalTotalCents - origTotal;

  const uid  = String(request.auth?.uid ?? "");
  const role = String((request.auth?.token as any)?.role ?? "");

  const adjustmentsPayload: Record<string, any> = {
    fuelSurchargePct: fuelPct,
    fuelAdjCents,
    parkingCents:     adjParkingCents,
    tollsCents:       adjTollsCents,
    venueCents:       adjVenueCents,
    notes:            String(notes ?? "").substring(0, 1000),
    addedByRole:      role,
    addedByUid:       uid,
    addedAt:          admin.firestore.FieldValue.serverTimestamp(),
    adjustmentsTotalCents,
    finalTotalCents,
    deltaCents,
  };

  // Compute updated "current" pricing snapshot
  const currentPricing = {
    ...(original as object),
    parkingCents:  adjParkingCents,
    tollsCents:    adjTollsCents,
    venueCents:    adjVenueCents,
    fuelAdjCents,
    adjustmentsTotalCents,
    totalCents:    finalTotalCents,
  };

  await bpRef.set(
    {
      adjustments: adjustmentsPayload,
      "pricing.current":               currentPricing,
      "pricing.adjustmentsTotalCents": adjustmentsTotalCents,
      "pricing.finalTotalCents":       finalTotalCents,
      "pricing.deltaCents":            deltaCents,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const actor = callableActorMeta(request);
  await logAudit({
    ...actor,
    action:     "adjustments_charged",
    targetPath: `bookings_private/${String(bookingId)}`,
    after: {
      bookingId:             String(bookingId),
      mode:                  "stub",
      adjustmentsTotalCents,
      finalTotalCents,
      deltaCents,
    },
  });

  console.log("[chargeBookingAdjustments] bookingId:", bookingId, "finalTotalCents:", finalTotalCents, "delta:", deltaCents);

  // ── Stripe path (TODO when Stripe activated) ─────────────────────
  // const stripe = stripeClient();
  // const { customerId, paymentMethodId } = bp.stripe ?? {};
  // if (customerId && paymentMethodId && deltaCents > 50) {
  //   const pi = await stripe.paymentIntents.create({
  //     amount: deltaCents,
  //     currency: "usd",
  //     customer: customerId,
  //     payment_method: paymentMethodId,
  //     off_session: true,
  //     confirm: true,
  //   });
  //   await bpRef.set({ "stripe.paymentIntentId": pi.id, "stripe.paymentIntentStatus": pi.status }, { merge: true });
  // }

  return {
    ok:                    true,
    mode:                  "stub",
    bookingId:             String(bookingId),
    adjustmentsTotalCents,
    finalTotalCents,
    deltaCents,
  };
});
