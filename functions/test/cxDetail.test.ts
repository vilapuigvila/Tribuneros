import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import * as cheerio from "cheerio";
import {parseCategoryResults, parseRacePage, parseRiderPage} from "../src/cx";

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

test("rider page: name, avatar, first 8 facts and 10 most recent results", () => {
  const page = parseRiderPage(fixture("rider-wout-van-aert.html"));

  assert.equal(page.name, "Wout van Aert");
  assert.equal(page.avatarURL, "https://cyclocross24.com/images/rider/wout-van-aert-zG2.png");
  assert.deepEqual(
    page.facts.map((fact) => fact.label),
    ["Name", "Surname", "Date of birth", "Age", "Place of birth", "Residence", "Nationality", "Team"]
  );
  assert.deepEqual(page.facts[page.facts.length - 1], {label: "Team", value: "Visma - Lease a Bike"});
  assert.equal(page.results.length, 10);
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
