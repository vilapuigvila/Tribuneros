import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import * as cheerio from "cheerio";
import {parseCategoryResults, parseRacePage, parseRiderPage, parseStandingPage, standingPageURL} from "../src/cx";

// Fixtures are real cyclocross24 pages captured on 2026-09-29; re-capture them when the site changes.
function fixture(name: string) {
  return cheerio.load(readFileSync(join(__dirname, "..", "..", "test", "fixtures", name), "utf8"));
}

test("race page: title, summary and Men Elite past winners, newest first", () => {
  const page = parseRacePage(fixture("race-koksijde.html"));

  assert.equal(page.title, "UCI World Cup Koksijde 2026");
  assert.match(page.summary, /^UCI World Cup Koksijde cyclocross: 20 December 2026/);
  assert.equal(page.pastWinners.length, 58);
  assert.deepEqual(page.pastWinners[0], {
    year: "2025",
    rider: "VAN DER POEL Mathieu",
    riderURL: "https://cyclocross24.com/rider/mathieu-van-der-poel/",
    countryFlagURL: "https://cyclocross24.com/images/flag/32/Netherlands.png",
    resultsURL: "https://cyclocross24.com/race/17924/",
  });
  assert.equal(page.pastWinners[page.pastWinners.length - 1].year, "1969");
  const years = page.pastWinners.map((winner) => Number(winner.year));
  assert.deepEqual(years, [...years].sort((lhs, rhs) => rhs - lhs));
});

test("race page: two editions in one year are both kept", () => {
  const page = parseRacePage(fixture("race-koksijde.html"));
  const herygers1994 = page.pastWinners.filter((winner) => winner.year === "1994" && winner.rider === "HERYGERS Paul");

  assert.equal(herygers1994.length, 2);
  assert.notEqual(herygers1994[0].resultsURL, herygers1994[1].resultsURL);
});

test("race page: other categories' winners are left out", () => {
  const riders = parseRacePage(fixture("race-koksijde.html")).pastWinners.map((winner) => winner.rider);

  assert.ok(!riders.includes("REVOL Lise"));
});

test("race page: TV channels with names, sites and absolute logos", () => {
  const channels = parseRacePage(fixture("race-dendermonde.html")).tvChannels;

  assert.equal(channels.length, 4);
  assert.deepEqual(channels[0], {
    name: "Sporza",
    logoURL: "https://cyclocross24.com/files/tv/1.png",
    url: "https://www.sporza.be/",
  });
  assert.equal(channels[1].name, "Eurosport*");
  assert.equal(channels[2].url, "https://www.hbomax.com/sports");
  assert.equal(channels[3].url, "https://www.tntsports.co.uk/");
});

test("race page: no TV info gives an empty list", () => {
  assert.deepEqual(parseRacePage(fixture("race-koksijde.html")).tvChannels, []);
});

test("rider page: name, avatar, first 8 facts and the most recent results", () => {
  const page = parseRiderPage(fixture("rider-wout-van-aert.html"));

  assert.equal(page.name, "Wout van Aert");
  assert.equal(page.avatarURL, "https://cyclocross24.com/images/rider/wout-van-aert-zG2.png");
  assert.deepEqual(
    page.facts.map((fact) => fact.label),
    ["Name", "Surname", "Date of birth", "Age", "Place of birth", "Residence", "Nationality", "Team"]
  );
  assert.deepEqual(page.facts[page.facts.length - 1], {label: "Team", value: "Visma - Lease a Bike"});
  assert.ok(page.results.length > 10);
  assert.deepEqual(page.results[1], {
    date: "29-12-2025",
    race: "X2O Trofee Loenhout - Azencross",
    position: "10",
    raceURL: "https://cyclocross24.com/race/17944/",
  });
});

test("rider page: a DNF shows as \"-\"", () => {
  const latest = parseRiderPage(fixture("rider-wout-van-aert.html")).results[0];

  assert.equal(latest.date, "02-01-2026");
  assert.equal(latest.position, "-");
});

test("results page: classified riders only, in order", () => {
  const results = parseCategoryResults(fixture("results-18209.html"));

  assert.equal(results.length, 40);
  assert.deepEqual(results[0], {
    position: "1",
    rider: "JANSSEN Wout",
    age: "24",
    team: "",
    time: "1:00:17",
    countryFlagURL: "https://cyclocross24.com/images/flag/32/Belgium.png",
    riderURL: "https://cyclocross24.com/rider/wout-janssen/",
  });
  assert.equal(results[1].team, "Pauwels Sauzen - Altez Industriebouw");
  assert.deepEqual(results.map((result) => Number(result.position)), results.map((_, index) => index + 1));
});

test("rider page: the full results table, newest first, capped at 200 rows", () => {
  // The fixture holds 367 result rows, back to 2015.
  const results = parseRiderPage(fixture("rider-wout-van-aert.html")).results;

  assert.equal(results.length, 200);
  assert.deepEqual(results[results.length - 1], {
    date: "26-09-2015",
    race: "Soudal Classics - GP Neerpelt",
    position: "1",
    raceURL: "https://cyclocross24.com/race/1633/",
  });
  const year = (date: string) => Number(date.slice(-4));
  const years = results.map((result) => year(result.date));
  assert.deepEqual(years, [...years].sort((lhs, rhs) => rhs - lhs));
});

// Standings fixtures captured on 2026-10-20.
test("UCI ranking page: title, category options, selected category and the full first page", () => {
  const page = parseStandingPage(fixture("uciranking-2026-2027-ME.html"));

  assert.equal(page.title, "UCI Ranking Men");
  assert.deepEqual(page.categories, [
    {title: "Men Elite", url: "https://cyclocross24.com/uciranking/2026-2027/ME/"},
    {title: "Women Elite", url: "https://cyclocross24.com/uciranking/2026-2027/WE/"},
    {title: "Men Junior", url: "https://cyclocross24.com/uciranking/2026-2027/MJ/"},
  ]);
  assert.equal(page.selectedIndex, 0);
  assert.equal(page.rows.length, 100);
  assert.deepEqual(page.rows[0], {
    position: 1,
    rider: "VAN DER POEL Mathieu",
    riderURL: "https://cyclocross24.com/rider/mathieu-van-der-poel/",
    countryFlagURL: "https://cyclocross24.com/images/flag/32/Netherlands.png",
    team: "Alpecin - Premier Tech",
    points: "2240",
  });
  assert.equal(page.rows[99].position, 100);
  assert.equal(page.rows[99].team, null);
});

test("series standings page: title, category tabs, selected category and every row", () => {
  const page = parseStandingPage(fixture("standings-superprestige-2025-2026-ME.html"));

  assert.equal(page.title, "Superprestige Cyclocross");
  assert.deepEqual(page.categories, [
    {title: "Men Elite", url: "https://cyclocross24.com/standings/superprestige/2025-2026/ME/"},
    {title: "Women Elite", url: "https://cyclocross24.com/standings/superprestige/2025-2026/WE/"},
  ]);
  assert.equal(page.selectedIndex, 0);
  assert.equal(page.rows.length, 38);
  assert.deepEqual(page.rows[0], {
    position: 1,
    rider: "VANDEPUTTE Niels",
    riderURL: "https://cyclocross24.com/rider/niels-vandeputte/",
    countryFlagURL: "https://cyclocross24.com/images/flag/32/Belgium.png",
    team: null,
    points: "105",
  });
  assert.deepEqual(page.rows.map((row) => row.position), Array.from({length: 38}, (_, index) => index + 1));
});

test("series standings page: a season with no race yet has no rows", () => {
  const page = parseStandingPage(fixture("standings-superprestige-empty.html"));

  assert.equal(page.rows.length, 0);
  assert.equal(page.categories.length, 2);
});

test("standing page URL: rebuilt from the ~ id", () => {
  assert.equal(standingPageURL("uciranking~2025-2026~ME"), "https://cyclocross24.com/uciranking/2025-2026/ME/");
  assert.equal(standingPageURL("standings~superprestige"), "https://cyclocross24.com/standings/superprestige/");
});

test("race page: the schedule lists venue-local starts, Men Elite last", () => {
  const schedule = parseRacePage(fixture("race-dendermonde.html")).schedule;

  assert.equal(schedule.length, 4);
  assert.deepEqual(schedule[0], {time: "11:00", category: "Women Junior"});
  assert.deepEqual(schedule[3], {time: "15:00", category: "Men Elite"});
});
