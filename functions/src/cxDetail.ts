import "./options";
import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";
import {Timestamp, getFirestore, type Firestore} from "firebase-admin/firestore";
import {scrapeCategoryResults, scrapeRacePage, scrapeRiderPage} from "./cx";

const HOUR_MS = 3_600_000;

export interface DetailKind {
  collection: string;
  idPattern: RegExp;
  // null: once stored, never refetched (a finished race's results don't change).
  maxAgeMs: number | null;
  // Resolves to null when the page parsed to nothing usable, so the cache isn't overwritten with it.
  scrape: (id: string) => Promise<object | null>;
}

export const DETAIL_KINDS: Record<string, DetailKind> = {
  rider: {
    collection: "cxRiders",
    idPattern: /^[a-z0-9-]{1,100}$/,
    maxAgeMs: 24 * HOUR_MS,
    scrape: async (slug) => {
      const page = await scrapeRiderPage(slug);
      return page.name ? page : null;
    },
  },
  race: {
    collection: "cxRaces",
    // An all-digit path is a results page, not a race page.
    idPattern: /^(?!\d+$)[a-z0-9-]{1,100}$/,
    maxAgeMs: 7 * 24 * HOUR_MS,
    scrape: async (slug) => {
      const page = await scrapeRacePage(slug);
      return page.title ? page : null;
    },
  },
  results: {
    collection: "cxResults",
    idPattern: /^\d{1,9}$/,
    maxAgeMs: null,
    scrape: async (id) => {
      const results = await scrapeCategoryResults(id);
      return results.length > 0 ? {results} : null;
    },
  },
};

export function detailKind(kind: unknown, id: unknown): DetailKind | null {
  if (typeof kind !== "string" || typeof id !== "string") return null;
  const match = Object.prototype.hasOwnProperty.call(DETAIL_KINDS, kind) ? DETAIL_KINDS[kind] : undefined;
  return match && match.idPattern.test(id) ? match : null;
}

export function isFresh(updatedAt: Date | undefined, maxAgeMs: number | null, now: Date): boolean {
  if (!updatedAt) return false;
  return maxAgeMs === null || now.getTime() - updatedAt.getTime() < maxAgeMs;
}

export interface DetailResponse {
  status: number;
  body: object;
}

function responseBody(data: FirebaseFirestore.DocumentData): object {
  const updatedAt = data.updatedAt instanceof Timestamp ? data.updatedAt.toDate().toISOString() : null;
  return {...data, updatedAt};
}

// Serves the cached document while fresh; otherwise scrapes, stores and returns the page, falling back
// to the stale copy when the scrape fails (same rule as scrapeCx: never replace data with nothing).
export async function loadDetail(db: Firestore, kind: DetailKind, id: string, now: Date = new Date()): Promise<DetailResponse> {
  const ref = db.collection(kind.collection).doc(id);
  const cached = (await ref.get()).data();
  const updatedAt = cached?.updatedAt instanceof Timestamp ? cached.updatedAt.toDate() : undefined;
  if (cached && isFresh(updatedAt, kind.maxAgeMs, now)) {
    return {status: 200, body: responseBody(cached)};
  }

  let scraped: object | null = null;
  try {
    scraped = await kind.scrape(id);
  } catch (error) {
    logger.warn(`${kind.collection}/${id}: scrape failed`, error);
  }

  if (scraped) {
    const document = {...scraped, updatedAt: Timestamp.now()};
    await ref.set(document);
    return {status: 200, body: responseBody(document)};
  }
  if (cached) {
    logger.warn(`${kind.collection}/${id}: serving stale copy`);
    return {status: 200, body: responseBody(cached)};
  }
  return {status: 502, body: {error: "cyclocross24 page unavailable"}};
}

export const cxDetail = onRequest(
  {
    // Few instances, so the per-instance 750 ms request spacing still protects cyclocross24 from bursts.
    maxInstances: 2,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request, response) => {
    if (request.method !== "GET") {
      response.status(405).json({error: "GET only"});
      return;
    }
    const kind = detailKind(request.query.kind, request.query.id);
    if (!kind) {
      response.status(400).json({error: "expected ?kind=rider|race|results&id=<slug or results id>"});
      return;
    }
    const result = await loadDetail(getFirestore(), kind, request.query.id as string);
    response.status(result.status).json(result.body);
  }
);
