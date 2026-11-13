import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import * as cheerio from "cheerio";
import {
  buildSchedules,
  cxSeries,
  madridToday,
  parseRacePage,
  scheduledEvents,
  scheduleHeadingDate,
  type CalendarEvent,
  type ScheduledStart,
} from "../src/cx";

// race-ostrava.html was captured on 2026-11-12: two days, juniors on Thursday, elites on Friday.
function fixture(name: string) {
  return cheerio.load(readFileSync(join(__dirname, "..", "..", "test", "fixtures", name), "utf8"));
}

function event(overrides: Partial<CalendarEvent>): CalendarEvent {
  return {
    date: "15-11-2026",
    race: "Race",
    raceClass: "C1",
    flagURL: null,
    winnerName: "",
    isCancelled: false,
    raceID: null,
    raceSlug: "race",
    raceURL: null,
    resultsURL: null,
    videoURL: null,
    websiteURL: null,
    raceCountry: "Belgium",
    winnerURL: null,
    winnerCountry: null,
    winnerFlagURL: null,
    ...overrides,
  };
}

test("schedule: each row carries the day heading it sits under", () => {
  const schedule = parseRacePage(fixture("race-ostrava.html")).schedule;

  assert.deepEqual(schedule, [
    {time: "18:15", category: "Women Junior", date: "26-11-2026"},
    {time: "19:45", category: "Men Junior", date: "26-11-2026"},
    {time: "18:15", category: "Women Elite", date: "27-11-2026"},
    {time: "19:45", category: "Men Elite", date: "27-11-2026"},
  ]);
});

test("schedule: a heading with the edition name after the date still gives the day", () => {
  assert.equal(scheduleHeadingDate("Sunday 15 November 2026 - X2O Trofee Hamme-Zogge - Bollekescross"), "15-11-2026");
  assert.equal(scheduleHeadingDate("Saturday 2 January 2027"), "02-01-2027");
  assert.equal(scheduleHeadingDate("Schedule"), null);
});

test("series: matches the app's rule, one case per series", () => {
  assert.equal(cxSeries("UCI World Cup Hamme", "CDM", "Belgium"), "worldCup");
  assert.equal(cxSeries("Some Cross", "CDM", "Czech Republic"), "worldCup");
  assert.equal(cxSeries("Superprestige Ruddervoorde", "C1", "Belgium"), "superprestige");
  assert.equal(cxSeries("X2O Trofee Hamme-Zogge", "C1", "Belgium"), "x2oTrofee");
  assert.equal(cxSeries("Exact Cross Mol", "C2", "Belgium"), "exactCross");
  assert.equal(cxSeries("National Championships Belgium", "CN", "Belgium"), "championships");
  assert.equal(cxSeries("Cyclocross Merksplas (C1)", " c1 ", "belgium"), "otherBelgian");
  assert.equal(cxSeries("Cyclocross Gavere (C2)", "C2", "Netherlands"), "others");
});

test("events: future, not cancelled, in the five series; Exact Cross and others left out", () => {
  const events = [
    event({raceSlug: "past", race: "UCI World Cup Past", date: "11-11-2026"}),
    event({raceSlug: "today", race: "UCI World Cup Today", date: "12-11-2026"}),
    event({raceSlug: "cancelled", race: "Superprestige Cancelled", isCancelled: true}),
    event({raceSlug: "exact", race: "Exact Cross Mol"}),
    event({raceSlug: "other", race: "Gieten", raceCountry: "Netherlands"}),
    event({raceSlug: null, race: "UCI World Cup No Page"}),
    event({raceSlug: "belgian", race: "Merksplas"}),
    event({raceSlug: "national", race: "Belgian Championships", raceClass: "CN", date: "10-01-2027"}),
  ];

  const slugs = scheduledEvents(events, "12-11-2026").map((selected) => selected.raceSlug);

  assert.deepEqual(slugs, ["today", "belgian", "national"]);
});

test("date match: same slug, two events, only the edition on the page gets an entry", () => {
  const hamme: ScheduledStart[] = [
    {time: "13:45", category: "Women Elite", date: "15-11-2026"},
    {time: "15:00", category: "Men Elite (C1)", date: "15-11-2026"},
  ];
  const events = [
    event({raceSlug: "hamme", race: "X2O Trofee Hamme-Zogge", date: "15-11-2026"}),
    event({raceSlug: "hamme", race: "UCI World Cup Hamme", raceClass: "CDM", date: "23-01-2027"}),
  ];

  const entries = buildSchedules(events, new Map([["hamme", hamme]]), [], "12-11-2026");

  assert.deepEqual(entries, [{raceSlug: "hamme", date: "15-11-2026", schedule: hamme}]);
});

test("date match: a two-day edition keeps both days, a later edition's rows stay out", () => {
  const rows: ScheduledStart[] = [
    {time: "18:15", category: "Women Junior", date: "26-11-2026"},
    {time: "19:45", category: "Men Elite", date: "27-11-2026"},
    {time: "15:00", category: "Men Elite", date: "23-01-2027"},
  ];
  const events = [event({raceSlug: "ostrava", race: "UCI World Cup Ostrava", date: "27-11-2026"})];

  const entries = buildSchedules(events, new Map([["ostrava", rows]]), [], "12-11-2026");

  assert.deepEqual(entries[0].schedule, rows.slice(0, 2));
});

test("failed fetch: the previous entry of a future event is kept, past ones are dropped", () => {
  const kept = {raceSlug: "merksplas", date: "14-11-2026", schedule: [{time: "15:10", category: "Men Elite", date: "14-11-2026"}]};
  const past = {raceSlug: "old", date: "08-11-2026", schedule: []};
  const events = [
    event({raceSlug: "merksplas", race: "Merksplas", date: "14-11-2026"}),
    event({raceSlug: "ruddervoorde", race: "Superprestige Ruddervoorde", date: "06-12-2026"}),
  ];
  const pages = new Map<string, ScheduledStart[] | null>([["merksplas", null], ["ruddervoorde", []]]);

  assert.deepEqual(buildSchedules(events, pages, [kept, past], "12-11-2026"), [kept]);
});

test("today: the calendar day in Madrid", () => {
  assert.equal(madridToday(new Date("2026-11-12T23:30:00Z")), "13-11-2026");
  assert.equal(madridToday(new Date("2026-11-12T10:00:00Z")), "12-11-2026");
});
