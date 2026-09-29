import {test} from "node:test";
import assert from "node:assert/strict";
import {DETAIL_KINDS, detailKind, isFresh} from "../src/cxDetail";

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
