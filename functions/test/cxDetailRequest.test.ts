import {test} from "node:test";
import assert from "node:assert/strict";
import {HttpStatusError} from "../src/cx";
import {DETAIL_KINDS, MISSING_MAX_AGE_MS, PROVISIONAL_MAX_AGE_MS, detailKind, isFresh, isMissingError} from "../src/cxDetail";

const HOUR_MS = 3_600_000;

test("request: accepts a slug per kind and a numeric results id", () => {
  assert.equal(detailKind("rider", "wout-van-aert"), DETAIL_KINDS.rider);
  assert.equal(detailKind("race", "koksijde"), DETAIL_KINDS.race);
  assert.equal(detailKind("results", "18209"), DETAIL_KINDS.results);
});

test("request: a standing id is a uciranking or standings path of up to three plain segments", () => {
  for (const id of [
    "uciranking~2025-2026~ME",
    "standings~superprestige",
    "standings~superprestige~2025-2026~WE",
    "uciranking",
  ]) {
    assert.equal(detailKind("standing", id), DETAIL_KINDS.standing, id);
  }
});

test("request: rejects standing ids with slashes, other paths, extra segments or odd characters", () => {
  for (const id of [
    "uciranking/2025-2026/ME",
    "/uciranking~2025-2026~ME",
    "uciranking~2025-2026~ME~",
    "rider~wout-van-aert",
    "calendar~2025-2026~ME",
    "https://cyclocross24.com/uciranking/2025-2026/ME/",
    "standings~superprestige~2025-2026~ME~extra",
    "standings~super prestige",
    "standings~superprestige?x=1",
    "standings~..",
    "standings~super_prestige",
    "standings~" + "a".repeat(61),
    "UCIRANKING~2025-2026~ME",
  ]) {
    assert.equal(detailKind("standing", id), null, id);
  }
});

test("request: rejects unknown kinds, missing ids and anything that isn't a plain slug", () => {
  for (const [kind, id] of [
    ["rider", undefined],
    ["team", "visma"],
    ["toString", "x"],
    ["rider", "../calendar"],
    ["rider", "wout-van-aert/results"],
    ["rider", "https://example.com"],
    ["race", "18209"],
    ["results", "koksijde"],
    ["rider", ["wout-van-aert"]],
  ]) {
    assert.equal(detailKind(kind, id), null, `${kind} ${id}`);
  }
});

test("freshness: riders expire after a day, races after a week, results never", () => {
  const now = new Date("2026-09-29T12:00:00Z");
  const ago = (hours: number) => new Date(now.getTime() - hours * HOUR_MS);

  assert.equal(isFresh(ago(23), DETAIL_KINDS.rider.maxAgeMs, now), true);
  assert.equal(isFresh(ago(25), DETAIL_KINDS.rider.maxAgeMs, now), false);
  assert.equal(isFresh(ago(6 * 24), DETAIL_KINDS.race.maxAgeMs, now), true);
  assert.equal(isFresh(ago(8 * 24), DETAIL_KINDS.race.maxAgeMs, now), false);
  assert.equal(isFresh(ago(10_000), DETAIL_KINDS.results.maxAgeMs, now), true);
  assert.equal(isFresh(undefined, DETAIL_KINDS.results.maxAgeMs, now), false);
});

test("results: a document whose winner has no time is provisional and refreshed after 15 minutes", () => {
  const isFinal = DETAIL_KINDS.results.isFinal!;
  const row = {position: "1", rider: "NIEUWENHUIS Joris", age: "30", team: "", countryFlagURL: null, riderURL: null};

  assert.equal(isFinal({results: [{...row, time: ""}, {...row, position: "2", time: ""}]}), false);
  assert.equal(isFinal({results: []}), false);
  assert.equal(isFinal({results: [{...row, time: "1:03:37"}, {...row, position: "2", time: "0:13"}]}), true);
  assert.equal(PROVISIONAL_MAX_AGE_MS, 15 * 60_000);
});

test("freshness: standings expire after 12 hours", () => {
  const now = new Date("2026-09-29T12:00:00Z");
  const ago = (hours: number) => new Date(now.getTime() - hours * HOUR_MS);

  assert.equal(DETAIL_KINDS.standing.collection, "cxStandings");
  assert.equal(isFresh(ago(11), DETAIL_KINDS.standing.maxAgeMs, now), true);
  assert.equal(isFresh(ago(13), DETAIL_KINDS.standing.maxAgeMs, now), false);
});

test("missing pages: only a 404/410 counts, other failures aren't remembered", () => {
  assert.equal(isMissingError(new HttpStatusError(404, "https://cyclocross24.com/rider/x/")), true);
  assert.equal(isMissingError(new HttpStatusError(410, "https://cyclocross24.com/rider/x/")), true);
  assert.equal(isMissingError(new HttpStatusError(429, "https://cyclocross24.com/rider/x/")), false);
  assert.equal(isMissingError(new HttpStatusError(503, "https://cyclocross24.com/rider/x/")), false);
  assert.equal(isMissingError(new Error("fetch failed")), false);
  assert.equal(isMissingError(undefined), false);
});

test("missing pages: remembered for an hour", () => {
  const now = new Date("2026-09-29T12:00:00Z");

  assert.equal(isFresh(new Date(now.getTime() - 59 * 60_000), MISSING_MAX_AGE_MS, now), true);
  assert.equal(isFresh(new Date(now.getTime() - 61 * 60_000), MISSING_MAX_AGE_MS, now), false);
});
