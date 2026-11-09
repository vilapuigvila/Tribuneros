import "./options";
import {timingSafeEqual, createHash} from "node:crypto";
import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {getApps, initializeApp} from "firebase-admin/app";
import {getMessaging, type Message} from "firebase-admin/messaging";

const pushAdminKey = defineSecret("PUSH_ADMIN_KEY");

export interface SendPushRequest {
  title: string;
  body: string;
  target: {topic: "all"} | {token: string};
  data?: Record<string, string>;
}

export const TITLE_MAX = 100;
export const BODY_MAX = 500;

export class PushRequestError extends Error {}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function text(value: unknown, field: string, max: number): string {
  if (typeof value !== "string" || value.trim() === "") throw new PushRequestError(`${field} is required`);
  if (value.length > max) throw new PushRequestError(`${field} is longer than ${max} characters`);
  return value;
}

export function buildPushMessage(input: unknown): Message {
  if (!isRecord(input)) throw new PushRequestError("body must be a JSON object");
  const title = text(input.title, "title", TITLE_MAX);
  const body = text(input.body, "body", BODY_MAX);

  const target = input.target;
  if (!isRecord(target)) throw new PushRequestError("target is required");
  let destination: {topic: string} | {token: string};
  if (typeof target.token === "string" && target.token !== "" && target.topic === undefined) {
    destination = {token: target.token};
  } else if (target.topic === "all" && target.token === undefined) {
    destination = {topic: "all"};
  } else {
    throw new PushRequestError("target must be {topic: \"all\"} or {token}");
  }

  let data: Record<string, string> | undefined;
  if (input.data !== undefined) {
    if (!isRecord(input.data) || !Object.values(input.data).every((v) => typeof v === "string")) {
      throw new PushRequestError("data must be an object of strings");
    }
    data = input.data as Record<string, string>;
  }

  return {
    ...destination,
    notification: {title, body},
    ...(data ? {data} : {}),
    apns: {payload: {aps: {sound: "default"}}},
  } as Message;
}

export function isAuthorized(header: string | undefined, key: string): boolean {
  if (!key || !header?.startsWith("Bearer ")) return false;
  const digest = (value: string) => createHash("sha256").update(value).digest();
  return timingSafeEqual(digest(header.slice("Bearer ".length)), digest(key));
}

export const sendPush = onRequest({secrets: [pushAdminKey], maxInstances: 2}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({error: "POST only"});
    return;
  }
  // trim: `openssl rand -hex 32 | secrets:set --data-file=-` stores a trailing newline no header can carry.
  if (!isAuthorized(req.get("authorization"), pushAdminKey.value().trim())) {
    res.status(401).json({error: "unauthorized"});
    return;
  }
  let message: Message;
  try {
    message = buildPushMessage(req.body);
  } catch (error) {
    if (!(error instanceof PushRequestError)) throw error;
    res.status(400).json({error: error.message});
    return;
  }
  try {
    if (getApps().length === 0) initializeApp();
    const id = await getMessaging().send(message);
    res.status(200).json({id});
  } catch (error) {
    const code = (error as {code?: string}).code ?? "unknown";
    logger.error(`sendPush: FCM rejected the message (${code})`, error);
    res.status(502).json({error: (error as Error).message, code});
  }
});
