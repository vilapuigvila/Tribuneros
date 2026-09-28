import {setGlobalOptions} from "firebase-functions";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, type Firestore} from "firebase-admin/firestore";
import {loadHomepageDocument, parseHomepage, scrapeCalendar, scrapeStandings} from "./cx";

initializeApp();

setGlobalOptions({region: "europe-west1", maxInstances: 10});

type Outcome = PromiseSettledResult<object>;

async function store(db: Firestore, path: string, outcome: Outcome, isEmpty: (value: object) => boolean): Promise<boolean> {
  if (outcome.status === "rejected") {
    logger.error(`${path}: scrape failed, keeping previous data`, outcome.reason);
    return false;
  }
  if (isEmpty(outcome.value)) {
    logger.error(`${path}: scrape returned no data, keeping previous data`);
    return false;
  }
  await db.doc(path).set({...outcome.value, updatedAt: FieldValue.serverTimestamp()});
  logger.info(`${path}: updated`);
  return true;
}

export async function runCxScrape(db: Firestore): Promise<void> {
  const homepageDocument = loadHomepageDocument();
  const [homepage, calendar, standings] = await Promise.allSettled([
    homepageDocument.then(parseHomepage),
    scrapeCalendar(),
    homepageDocument.then(scrapeStandings),
  ]);

  const stored = await Promise.all([
    store(db, "cx/homepage", homepage, (value) => (value as {sections: unknown[]}).sections.length === 0),
    store(db, "cx/calendar", calendar, (value) => (value as {events: unknown[]}).events.length === 0),
    store(db, "cx/standings", standings, (value) => (value as {items: unknown[]}).items.length === 0),
  ]);

  if (!stored.some(Boolean)) {
    throw new Error("Every CX scrape failed; nothing was updated");
  }
}

export const scrapeCx = onSchedule(
  {
    schedule: "every day 23:00",
    timeZone: "Europe/Madrid",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    await runCxScrape(getFirestore());
  }
);
