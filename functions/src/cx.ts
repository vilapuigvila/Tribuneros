import * as cheerio from "cheerio";
import type {CheerioAPI, Cheerio} from "cheerio";
import type {AnyNode, Element} from "domhandler";

const BASE_URL = "https://cyclocross24.com";
const FETCH_TIMEOUT_MS = 20_000;

export interface Podium {
  position: number;
  rider: string;
  riderURL: string | null;
  country: string;
  countryFlagURL: string | null;
  time: string;
}

export interface Category {
  title: string;
  categoryURL: string | null;
  winnerImageURL: string | null;
  podium: Podium[];
}

export interface Race {
  title: string;
  country: string;
  countryFlagURL: string | null;
  date: string;
  location: string;
  raceURL: string | null;
  categories: Category[];
}

export interface Section {
  title: string;
  races: Race[];
}

export interface Homepage {
  sections: Section[];
}

export interface Leader {
  position: number;
  rider: string;
  riderURL: string | null;
  countryFlagURL: string | null;
  points: string;
}

export interface StandingsCategory {
  title: string;
  url: string | null;
  leaders: Leader[];
  leaderImageURL: string | null;
}

export interface StandingsItem {
  title: string;
  url: string | null;
  logoURL: string | null;
  categories: StandingsCategory[];
}

export interface Standings {
  items: StandingsItem[];
}

export interface CalendarEvent {
  date: string;
  race: string;
  raceClass: string;
  flagURL: string | null;
  winnerName: string;
  isCancelled: boolean;
  raceID: number | null;
  raceSlug: string | null;
  raceURL: string | null;
  resultsURL: string | null;
  videoURL: string | null;
  websiteURL: string | null;
  raceCountry: string | null;
  winnerURL: string | null;
  winnerCountry: string | null;
  winnerFlagURL: string | null;
}

export interface Calendar {
  season: string;
  category: string;
  events: CalendarEvent[];
}

// MARK: - Fetching

const MIN_REQUEST_GAP_MS = 750;
const MAX_ATTEMPTS = 3;

let lastRequestStartedAt = 0;
let requestChain: Promise<void> = Promise.resolve();

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

// The site returns 429 on bursts, so request starts are spaced out globally across all scrapers.
function waitForRequestSlot(): Promise<void> {
  const slot = requestChain.then(async () => {
    const wait = lastRequestStartedAt + MIN_REQUEST_GAP_MS - Date.now();
    if (wait > 0) await sleep(wait);
    lastRequestStartedAt = Date.now();
  });
  requestChain = slot;
  return slot;
}

function retryDelayMs(response: Response, attempt: number): number {
  const retryAfterSeconds = Number(response.headers.get("retry-after"));
  if (Number.isFinite(retryAfterSeconds) && retryAfterSeconds > 0) {
    return Math.min(retryAfterSeconds, 30) * 1000;
  }
  return 5_000 * attempt;
}

async function fetchDocument(url: string): Promise<CheerioAPI> {
  for (let attempt = 1; ; attempt++) {
    await waitForRequestSlot();
    const response = await fetch(url, {signal: AbortSignal.timeout(FETCH_TIMEOUT_MS)});
    if (response.ok) {
      return cheerio.load(await response.text());
    }
    const retryable = response.status === 429 || response.status === 503;
    if (!retryable || attempt >= MAX_ATTEMPTS) {
      throw new Error(`GET ${url} failed with status ${response.status}`);
    }
    await sleep(retryDelayMs(response, attempt));
  }
}

// MARK: - Helpers

// jsoup's text() collapses whitespace; cheerio's doesn't, so normalize to match the Swift parsers.
function clean(value: string | undefined): string {
  return (value ?? "").replace(/\s+/g, " ").trim();
}

function absoluteURL(href: string | undefined): string | null {
  const trimmed = (href ?? "").trim();
  if (!trimmed) return null;
  try {
    return new URL(trimmed, BASE_URL).toString();
  } catch {
    return null;
  }
}

function strictInt(value: string): number | null {
  const trimmed = value.trim();
  return /^-?\d+$/.test(trimmed) ? Number.parseInt(trimmed, 10) : null;
}

function ownText(element: Cheerio<Element>): string {
  return clean(
    element
      .contents()
      .filter((_, node: AnyNode) => node.type === "text")
      .text()
  );
}

function raceCode(href: string): string | null {
  const components = href.trim().split("/").filter((part) => part.length > 0);
  if (components.length < 2 || components[0] !== "race") return null;
  return components[1];
}

export function currentSeason(now: Date = new Date()): string {
  const year = now.getUTCFullYear();
  // Seasons run autumn to winter; from July onward the next season's calendar is the relevant one.
  return now.getUTCMonth() >= 6 ? `${year}-${year + 1}` : `${year - 1}-${year}`;
}

// MARK: - Homepage

function parseCategory($: CheerioAPI, category: Cheerio<Element>): Category {
  const anchor = category.find("div.fp_category > a").first();
  const podium = category
    .find("div.fp_rider_bar")
    .slice(0, 3)
    .map((_, row) => {
      const $row = $(row);
      const riderAnchor = $row.find("div.fp_rider a").first();
      const riderFlag = $row.find("div.fp_flag img.flag").first();
      return {
        position: strictInt(clean($row.find("div.fp_result").first().text())) ?? 0,
        rider: clean(riderAnchor.text()),
        riderURL: absoluteURL(riderAnchor.attr("href")),
        country: riderFlag.attr("title") ?? "",
        countryFlagURL: absoluteURL(riderFlag.attr("src")),
        time: clean($row.find("div.fp_time").first().text()),
      };
    })
    .get();

  return {
    title: ownText(anchor),
    categoryURL: absoluteURL(anchor.attr("href")),
    winnerImageURL: absoluteURL(category.find("img.fp_image_winner").first().attr("src")),
    podium,
  };
}

function parseRaceBlock($: CheerioAPI, block: Cheerio<Element>): Race | null {
  const raceInfo = block.find("div.race_info").first();
  if (raceInfo.length === 0) return null;

  const flag = raceInfo.find("div.race_info_left img.flag").first();
  const tokens = clean(raceInfo.find("div.race_info_bar").first().text())
    .split(" ")
    .filter((token) => token.length > 0);

  return {
    title: clean(raceInfo.find("h3.h3").first().text()),
    country: flag.attr("title") ?? "",
    countryFlagURL: absoluteURL(flag.attr("src")),
    date: tokens.slice(0, 3).join(" "),
    location: tokens.slice(3).join(" ").trim(),
    raceURL: absoluteURL(raceInfo.find("a[href^=\"/race/\"]").first().attr("href")),
    categories: block
      .find("div.race_category")
      .map((_, category) => parseCategory($, $(category)))
      .get(),
  };
}

export function parseHomepage($: CheerioAPI): Homepage {
  const sections = $("div.raceday:has(div.race_block)")
    .map((_, section) => {
      const $section = $(section);
      const races = $section
        .find("div.race_block")
        .map((__, block) => parseRaceBlock($, $(block)))
        .get()
        .filter((race): race is Race => race !== null);
      return {title: clean($section.find(".fp_title").first().text()), races};
    })
    .get();
  return {sections};
}

export function loadHomepageDocument(): Promise<CheerioAPI> {
  return fetchDocument(BASE_URL);
}

// MARK: - Calendar

export function parseCalendar($: CheerioAPI): CalendarEvent[] {
  return $("tr.r1_row.ri_calendar")
    .map((_, row): CalendarEvent | null => {
      const $row = $(row);
      const raceTd = $row.find("td.r1_cal_rider").first();
      const raceAnchor = raceTd.find("a[href^=\"/race/\"]").first();
      const racePath = raceAnchor.attr("href") ?? "";
      const date = clean($row.find("td.r1_cal_date").first().text());
      const race = clean(raceAnchor.text());
      if (!date || !race) return null;

      const flag = raceTd.find("img.flag").first();
      const winnerTd = $row.find("td.r1_cal_winner").first();
      let resultsAnchor = winnerTd.find("a[title=\"Results\"][href^=\"/race/\"]").first();
      if (resultsAnchor.length === 0) {
        resultsAnchor = winnerTd.find("a[href^=\"/race/\"]").first();
      }
      const resultsPath = resultsAnchor.attr("href") ?? "";
      const resultsCode = raceCode(resultsPath);
      const winnerAnchor = winnerTd.find("a.rurl[href^=\"/rider/\"]").first();
      const winnerFlag = winnerTd.find("img.flag").first();

      return {
        date,
        race,
        raceClass: clean($row.find("td.r1_cal_class").first().text()),
        flagURL: absoluteURL(flag.attr("src")),
        winnerName: clean(winnerAnchor.text()),
        isCancelled: $row.hasClass("race_cancelled") || $row.find("div.cancel").length > 0,
        raceID: resultsCode === null ? null : strictInt(resultsCode),
        raceSlug: raceCode(racePath),
        raceURL: absoluteURL(racePath),
        resultsURL: absoluteURL(resultsPath),
        videoURL: absoluteURL($row.find("td.r1_cal_yt a[href$=\"#video\"]").first().attr("href")),
        websiteURL: absoluteURL($row.find("td.r1_cal_web a[href]").first().attr("href")),
        raceCountry: flag.length > 0 ? (flag.attr("title") ?? "").trim() : null,
        winnerURL: absoluteURL(winnerAnchor.attr("href")),
        winnerCountry: winnerFlag.length > 0 ? (winnerFlag.attr("title") ?? "").trim() : null,
        winnerFlagURL: absoluteURL(winnerFlag.attr("src")),
      };
    })
    .get()
    .filter((event): event is CalendarEvent => event !== null);
}

export async function scrapeCalendar(season: string = currentSeason(), category = "ME"): Promise<Calendar> {
  const $ = await fetchDocument(`${BASE_URL}/calendar/${season}/${category}/`);
  return {season, category, events: parseCalendar($)};
}

// MARK: - Standings

function parseStandingsLinks($: CheerioAPI): StandingsItem[] {
  let links = $("li.footer_title")
    .filter((_, li) => /^standings$/i.test(ownText($(li))))
    .closest("ul")
    .find("a[href]");
  if (links.length === 0) {
    links = $("a[href^=\"/uciranking/\"], a[href^=\"/standings/\"]");
  }

  const seenTitles = new Set<string>();
  const items: StandingsItem[] = [];
  links.each((_, anchor) => {
    const title = clean($(anchor).text());
    if (!title || seenTitles.has(title)) return;
    seenTitles.add(title);
    items.push({title, url: absoluteURL($(anchor).attr("href")), logoURL: null, categories: []});
  });

  const score = (item: StandingsItem): number =>
    item.url && new URL(item.url).pathname.toLowerCase().includes("uciranking") ? 0 : 1;
  return items
    .map((item, index) => ({item, index}))
    .sort((lhs, rhs) => score(lhs.item) - score(rhs.item) || lhs.index - rhs.index)
    .map(({item}) => item);
}

function normalizedStandingsTitle(raw: string): string {
  return clean(
    raw
      .trim()
      .split(" - ")[0]
      .replace(/\b\d{4}\s*[-–]\s*\d{4}\b/, "")
  );
}

function parseStandingsLogo($: CheerioAPI): string | null {
  let logo = $("div.standings_logo img").first();
  if (logo.length === 0) logo = $(".rid_land img.flag").first();
  return absoluteURL(logo.attr("data-src") || logo.attr("src"));
}

function parseStandingsCategories($: CheerioAPI): {categories: {title: string; url: string | null}[]; selectedIndex: number} {
  const tabs = $("a.cx-cat[href]");
  if (tabs.length > 0) {
    let selectedIndex = 0;
    const categories = tabs
      .map((index, tab) => {
        const className = $(tab).attr("class") ?? "";
        if (className.includes("c10") && className.includes("t10")) selectedIndex = index;
        return {title: clean($(tab).text()), url: absoluteURL($(tab).attr("href"))};
      })
      .get();
    return {categories, selectedIndex};
  }

  let selectedIndex = 0;
  const categories = $("select[name=cat] option[value]")
    .map((index, option) => {
      if ($(option).attr("selected") !== undefined) selectedIndex = index;
      return {title: clean($(option).text()), url: absoluteURL($(option).attr("value"))};
    })
    .get();
  return {categories, selectedIndex};
}

function parseStandingsLeaders($: CheerioAPI): Leader[] {
  return $("tr.r1_row")
    .slice(0, 5)
    .map((_, row): Leader | null => {
      const $row = $(row);
      const uciPosition = strictInt(clean($row.find("td.r1_uci_position").first().text()));
      const standPosition = strictInt(clean($row.find("td.stand_position").first().text()));
      const position = uciPosition ?? standPosition;
      if (position === null) return null;

      const pointsSelector = uciPosition !== null ? "td.r1_uci_points" : "td.stand_points";
      const riderAnchor = $row.find("a.rurl").first();
      const rider = clean(riderAnchor.text());
      if (!rider) return null;

      return {
        position,
        rider,
        riderURL: absoluteURL(riderAnchor.attr("href")),
        countryFlagURL: absoluteURL($row.find("img.flag").first().attr("src")),
        points: clean($row.find(pointsSelector).first().text()),
      };
    })
    .get()
    .filter((leader): leader is Leader => leader !== null);
}

async function fetchRiderAvatarURL(riderURL: string): Promise<string | null> {
  const $ = await fetchDocument(riderURL);
  let image = $("img.rider-avatar__image").first();
  if (image.length === 0) image = $("img[src*=\"/images/rider/\"]").first();
  return absoluteURL(image.attr("src"));
}

async function enrichStandingsItem(item: StandingsItem, url: string, includeLeaderImage: boolean): Promise<StandingsItem> {
  const $ = await fetchDocument(url);
  const title = normalizedStandingsTitle(clean($("h1.main_title").first().text()) || item.title);
  const logoURL = parseStandingsLogo($) ??
    (url.includes("uciranking") ? absoluteURL("/images/flag/32/UCI.png") : null);

  const parsed = parseStandingsCategories($);
  const baseCategories = parsed.categories.slice(0, 3);
  const selectedIndex = Math.min(parsed.selectedIndex, Math.max(0, baseCategories.length - 1));
  const currentLeaders = parseStandingsLeaders($);

  const categories: StandingsCategory[] = [];
  for (const [index, base] of baseCategories.entries()) {
    let leaders: Leader[] = [];
    if (index === selectedIndex) {
      leaders = currentLeaders;
    } else if (base.url) {
      try {
        leaders = parseStandingsLeaders(await fetchDocument(base.url));
      } catch (error) {
        console.warn(`Standings category ${base.url} failed`, error);
      }
    }
    categories.push({title: base.title, url: base.url, leaders, leaderImageURL: null});
  }

  const riderURL = categories[selectedIndex]?.leaders[0]?.riderURL;
  if (includeLeaderImage && riderURL) {
    try {
      categories[selectedIndex].leaderImageURL = await fetchRiderAvatarURL(riderURL);
    } catch (error) {
      console.warn(`Rider avatar ${riderURL} failed`, error);
    }
  }

  return {title, url: item.url, logoURL: logoURL ?? item.logoURL, categories};
}

export async function scrapeStandings(homepage: CheerioAPI): Promise<Standings> {
  const baseItems = parseStandingsLinks(homepage);
  const items = await Promise.all(
    baseItems.map(async (item, index) => {
      if (!item.url) return item;
      try {
        return await enrichStandingsItem(item, item.url, index === 0);
      } catch (error) {
        console.warn(`Standings item ${item.url} failed`, error);
        return item;
      }
    })
  );
  return {items};
}

// MARK: - Detail pages

export interface RacePastWinner {
  year: string;
  rider: string;
  riderURL: string | null;
  countryFlagURL: string | null;
  resultsURL: string | null;
}

export interface RacePage {
  title: string;
  summary: string;
  pastWinners: RacePastWinner[];
}

export interface RiderFact {
  label: string;
  value: string;
}

export interface RiderResult {
  date: string;
  race: string;
  position: string;
  raceURL: string | null;
}

export interface RiderPage {
  name: string;
  avatarURL: string | null;
  facts: RiderFact[];
  results: RiderResult[];
}

export interface CategoryResult {
  position: string;
  rider: string;
  age: string;
  team: string;
  time: string;
  countryFlagURL: string | null;
  riderURL: string | null;
}

const RIDER_FACTS_LIMIT = 8;
const RIDER_RESULTS_LIMIT = 10;
const PAST_WINNERS_CATEGORY = "Men Elite";

function mainTitle($: CheerioAPI): string {
  const heading = $("h1.main_title").first();
  return clean((heading.length > 0 ? heading : $("h1").first()).text());
}

function isResultsPath(href: string): boolean {
  const code = raceCode(href);
  return code !== null && strictInt(code) !== null;
}

// The History block lists every category's winners as sibling rows under a header per category.
export function parseRacePage($: CheerioAPI): RacePage {
  const header = $("div.ri_history_category")
    .filter((_, element) => ownText($(element)) === PAST_WINNERS_CATEGORY)
    .first();
  const siblings = header.nextUntil("div.ri_history_category");
  const rows = siblings.filter("div.ri_row").add(siblings.find("div.ri_row"));

  const seen = new Set<string>();
  const pastWinners: RacePastWinner[] = [];
  rows.each((_, row) => {
    const $row = $(row);
    const yearAnchor = $row.find("div.ri_history_left a").first();
    const year = clean(yearAnchor.text());
    const riderAnchor = $row.find("div.ri_history_rider a[href^=\"/rider/\"]").first();
    const rider = clean(riderAnchor.text());
    const resultsPath = yearAnchor.attr("href") ?? "";
    const resultsURL = isResultsPath(resultsPath) ? absoluteURL(resultsPath) : null;
    // Some years hold two editions (January and December), so the results link, not the year, identifies one.
    const key = resultsURL ?? `${year}|${rider}`;
    if (!/^(19[5-9]\d|20\d{2})$/.test(year) || !rider || seen.has(key)) return;
    seen.add(key);

    pastWinners.push({
      year,
      rider,
      riderURL: absoluteURL(riderAnchor.attr("href")),
      countryFlagURL: absoluteURL($row.find("img.flag").first().attr("src")),
      resultsURL,
    });
  });

  return {
    title: mainTitle($),
    summary: clean($("meta[name=description]").first().attr("content")),
    pastWinners: pastWinners.sort((lhs, rhs) => Number(rhs.year) - Number(lhs.year)),
  };
}

// Season tables come newest first, so the first rows are the most recent results.
export function parseRiderPage($: CheerioAPI): RiderPage {
  let avatar = $("img.rider-avatar__image").first();
  if (avatar.length === 0) avatar = $("img[src*=\"/images/rider/\"]").first();

  const seenLabels = new Set<string>();
  const facts: RiderFact[] = [];
  $("table.riderinfo-table tr").each((_, row) => {
    const label = clean($(row).find("th").first().text()).replace(/:$/, "").trim();
    const value = clean($(row).find("td").first().text());
    if (!label || !value || seenLabels.has(label.toLowerCase())) return;
    seenLabels.add(label.toLowerCase());
    facts.push({label, value});
  });

  const results = $("table.rider_table tr.rider_result_row")
    .map((_, row): RiderResult | null => {
      const $row = $(row);
      const raceAnchor = $row.find("td.rider_result_race a[href^=\"/race/\"]").first();
      const date = clean($row.find("td.rider_result_date").first().text());
      const race = clean(raceAnchor.text());
      if (!/^\d{1,2}[-./]\d{1,2}[-./]\d{4}$/.test(date) || !race) return null;
      const position = clean($row.find("td.rider_result_position").first().text()).replace(/\.$/, "");
      return {
        date,
        race,
        position: strictInt(position) === null ? "-" : position,
        raceURL: absoluteURL(raceAnchor.attr("href")),
      };
    })
    .get()
    .filter((result): result is RiderResult => result !== null);

  return {
    name: mainTitle($),
    avatarURL: absoluteURL(avatar.attr("src")),
    facts: facts.slice(0, RIDER_FACTS_LIMIT),
    results: results.slice(0, RIDER_RESULTS_LIMIT),
  };
}

// A results page (/race/<id>/) holds one category; rows without a numeric position (DNF, DNS) are skipped.
export function parseCategoryResults($: CheerioAPI): CategoryResult[] {
  return $("tr.r1_row")
    .map((_, row): CategoryResult | null => {
      const $row = $(row);
      const position = clean($row.find("td.res_position").first().text());
      const riderCell = $row.find("td.res_rider").first();
      const riderAnchor = riderCell.find("a[href^=\"/rider/\"]").first();
      const rider = clean(riderAnchor.text());
      if (strictInt(position) === null || !rider) return null;
      return {
        position,
        rider,
        age: clean($row.find("td.res_age").first().text()),
        team: clean($row.find("td.res_team").first().text()),
        time: clean($row.find("td.res_time").first().text()),
        countryFlagURL: absoluteURL(riderCell.find("img.flag").first().attr("src")),
        riderURL: absoluteURL(riderAnchor.attr("href")),
      };
    })
    .get()
    .filter((result): result is CategoryResult => result !== null);
}

export async function scrapeRacePage(slug: string): Promise<RacePage> {
  return parseRacePage(await fetchDocument(`${BASE_URL}/race/${slug}/`));
}

export async function scrapeRiderPage(slug: string): Promise<RiderPage> {
  return parseRiderPage(await fetchDocument(`${BASE_URL}/rider/${slug}/`));
}

export async function scrapeCategoryResults(id: string): Promise<CategoryResult[]> {
  return parseCategoryResults(await fetchDocument(`${BASE_URL}/race/${id}/`));
}
