import "./options";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, type Firestore} from "firebase-admin/firestore";
import {
  loadHomepageDocument,
  parseHomepage,
  scrapeCalendar,
  scrapeSchedules,
  scrapeStandings,
  type CalendarEvent,
  type ScheduleEntry,
} from "./cx";

export {cxDetail} from "./cxDetail";
export {sendPush} from "./push";

initializeApp();

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

// Runs after the other documents are stored and never throws: a failure only leaves the previous cx/schedules.
async function storeSchedules(db: Firestore, freshEvents: CalendarEvent[] | undefined): Promise<void> {
  try {
    const events = freshEvents ?? ((await db.doc("cx/calendar").get()).data()?.events as CalendarEvent[] | undefined) ?? [];
    const previous = ((await db.doc("cx/schedules").get()).data()?.events as ScheduleEntry[] | undefined) ?? [];
    const schedules = await scrapeSchedules(events, previous);
    if (schedules === null) {
      logger.error("cx/schedules: no race page could be fetched, keeping previous data");
      return;
    }
    await db.doc("cx/schedules").set({...schedules, updatedAt: FieldValue.serverTimestamp()});
    logger.info(`cx/schedules: updated, ${schedules.events.length} events`);
  } catch (error) {
    logger.error("cx/schedules: scrape failed, keeping previous data", error);
  }
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

  const events = calendar.status === "fulfilled" ? calendar.value.events : undefined;
  await storeSchedules(db, events);

  if (!stored.some(Boolean)) {
    throw new Error("Every CX scrape failed; nothing was updated");
  }
}

export const scrapeCx = onSchedule(
  {
    schedule: "30 16,22 * * *",
    timeZone: "Europe/Madrid",
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    await runCxScrape(getFirestore());
  }
);
