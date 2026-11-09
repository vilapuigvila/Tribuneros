import {test} from "node:test";
import assert from "node:assert/strict";
import {BODY_MAX, PushRequestError, TITLE_MAX, buildPushMessage, isAuthorized} from "../src/push";

const base = {title: "Hello", body: "World"};

test("push: builds a token message with the default sound", () => {
  const message = buildPushMessage({...base, target: {token: "abc"}}) as unknown as Record<string, unknown>;
  assert.equal(message.token, "abc");
  assert.deepEqual(message.notification, {title: "Hello", body: "World"});
  assert.deepEqual(message.apns, {payload: {aps: {sound: "default"}}});
  assert.equal(message.data, undefined);
});

test("push: builds a topic message with string data", () => {
  const message = buildPushMessage({...base, target: {topic: "all"}, data: {route: "cx"}}) as unknown as Record<string, unknown>;
  assert.equal(message.topic, "all");
  assert.deepEqual(message.data, {route: "cx"});
});

test("push: rejects a missing, empty or too long title or body", () => {
  const target = {topic: "all"};
  for (const input of [
    {body: "b", target},
    {title: "t", target},
    {title: "  ", body: "b", target},
    {title: "t".repeat(TITLE_MAX + 1), body: "b", target},
    {title: "t", body: "b".repeat(BODY_MAX + 1), target},
  ]) {
    assert.throws(() => buildPushMessage(input), PushRequestError);
  }
});

test("push: rejects an unknown topic, an empty token, no target and both targets", () => {
  for (const target of [{topic: "everyone"}, {token: ""}, {}, undefined, {topic: "all", token: "abc"}]) {
    assert.throws(() => buildPushMessage({...base, target}), PushRequestError);
  }
});

test("push: rejects data that is not a string map", () => {
  const target = {topic: "all"};
  for (const data of [{a: 1}, ["x"], "x", null, {a: {b: "c"}}]) {
    assert.throws(() => buildPushMessage({...base, target, data}), PushRequestError);
  }
});

test("push: rejects a body that is not an object", () => {
  for (const input of [null, "x", 3, []]) assert.throws(() => buildPushMessage(input), PushRequestError);
});

test("push: auth needs the exact bearer key", () => {
  assert.equal(isAuthorized("Bearer secret", "secret"), true);
  assert.equal(isAuthorized("Bearer wrong", "secret"), false);
  assert.equal(isAuthorized("secret", "secret"), false);
  assert.equal(isAuthorized(undefined, "secret"), false);
  assert.equal(isAuthorized("Bearer ", ""), false);
});
