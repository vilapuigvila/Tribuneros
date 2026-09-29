import {test} from "node:test";
import assert from "node:assert/strict";
import {HttpStatusError} from "../src/cx";
import {DETAIL_KINDS, MISSING_MAX_AGE_MS, detailKind, isFresh, isMissingError} from "../src/cxDetail";

const HOUR_MS = 3_600_000;

test("request: accepts a slug per kind and a numeric results id", () => {
  assert.equal(detailKind("rider", "wout-van-aert"), DETAIL_KINDS.rider);
  assert.equal(detailKind("race", "koksijde"), DETAIL_KINDS.race);
  assert.equal(detailKind("results", "18209"), DETAIL_KINDS.results);
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
