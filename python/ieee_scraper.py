#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ieee_scraper.py -- IEEE Xplore scraper for Napoleon's VSG project

Strategy:
  Primary   : Navigate to search page, intercept /rest/search JSON response
              (browser sends it automatically with correct cookies/headers)
              -> full authors + full abstract + DOI
  Fallback  : DOM parsing of the search results HTML
              -> title + year + venue only (no abstract)

Usage:
  python ieee_scraper.py "virtual synchronous generator hardware"
  python ieee_scraper.py "VSG inverter control" --pages 3
  python ieee_scraper.py "synchronverter prototype" --pages 2 --headless --no-pause
"""

import asyncio
import argparse
import io
import json
import re
import sys
from datetime import date
from pathlib import Path

# Force UTF-8 stdout so Unicode in titles/abstracts doesn't crash on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

try:
    from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    print("Playwright not installed. Run:")
    print("  pip install playwright && playwright install chromium")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PAPERS_LOG = Path(
    r"C:\Users\User\workspace\engineering\vsg-project\docs\research\papers_log.md"
)
IEEE_BASE        = "https://ieeexplore.ieee.org"
IEEE_SEARCH_URL  = f"{IEEE_BASE}/search/searchresult.jsp"
RESULTS_PER_PAGE = 25


# ---------------------------------------------------------------------------
# Log file helpers
# ---------------------------------------------------------------------------

def _next_paper_number(log_path: Path) -> int:
    if not log_path.exists():
        return 1
    text = log_path.read_text(encoding="utf-8")
    nums = re.findall(r"## \[PAPER-(\d{3,})\]", text)
    return max(int(n) for n in nums) + 1 if nums else 1


def _init_log(log_path: Path) -> None:
    if not log_path.exists():
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(
            "# Research Papers Log\n"
            "**Project:** VSG Hardware Prototype\n"
            f"**Last updated:** {date.today()}\n\n"
            "---\n",
            encoding="utf-8",
        )


def _clean_venue(raw: str) -> str:
    """Keep only the first meaningful line; strip metadata noise."""
    line = raw.split("\n")[0].strip()
    # Remove trailing metadata like "Year: 2022 | Conference Paper | ..."
    line = re.split(r"\s*\|\s*Year", line)[0]
    line = re.split(r"\s*Year:\s*\d{4}", line)[0]
    return line.strip() or raw.split("\n")[0].strip()


def append_papers(log_path: Path, papers: list[dict]) -> list[tuple[str, str]]:
    _init_log(log_path)
    start = _next_paper_number(log_path)
    saved = []

    with log_path.open("a", encoding="utf-8") as f:
        for i, p in enumerate(papers):
            num      = f"PAPER-{start + i:03d}"
            title    = (p.get("title") or "[No title]").strip()
            authors  = "; ".join(p.get("authors") or []) or "[unverified]"
            year     = p.get("year") or "[unverified]"
            venue    = _clean_venue(p.get("venue") or "[unverified]")
            doi      = p.get("doi") or "[unverified]"
            url      = p.get("url") or "[unverified]"
            abstract = (p.get("abstract") or "").strip()
            if not abstract:
                abstract = "Abstract not retrieved -- access full text via DOI with SUT subscription."

            f.write(
                f"\n## [{num}] {title}\n\n"
                f"| Field | Value |\n"
                f"|---|---|\n"
                f"| **Authors** | {authors} |\n"
                f"| **Year** | {year} |\n"
                f"| **Journal / Venue** | {venue} |\n"
                f"| **Publisher** | IEEE |\n"
                f"| **DOI** | {doi} |\n"
                f"| **Database Found** | IEEE Xplore |\n"
                f"| **Access** | SUT subscription / Abstract only |\n"
                f"| **URL** | {url} |\n"
                f"| **Relevance** | [To be assessed] |\n\n"
                f"### Abstract\n"
                f"> {abstract}\n\n"
                f"### Key Takeaways\n"
                f"- [Main method or contribution]\n"
                f"- [Hardware platform if mentioned -- MCU, topology, power rating]\n"
                f"- [Key result or finding]\n"
                f"- [Limitation or gap relevant to Napoleon's work]\n\n"
                f"---\n"
            )
            saved.append((num, title))

    # Update header date
    text = log_path.read_text(encoding="utf-8")
    text = re.sub(
        r"\*\*Last updated:\*\* \d{4}-\d{2}-\d{2}",
        f"**Last updated:** {date.today()}",
        text,
        count=1,
    )
    log_path.write_text(text, encoding="utf-8")
    return saved


# ---------------------------------------------------------------------------
# Parse IEEE REST API JSON
# ---------------------------------------------------------------------------

def _parse_api_json(data: dict) -> tuple[list[dict], int]:
    total   = data.get("totalRecords", 0)
    records = data.get("records") or data.get("articles") or []
    papers  = []

    for a in records:
        # Authors: list of dicts with 'normalizedName' or 'preferredName' or 'id'+'lastName'+'firstName'
        raw_authors = a.get("authors") or []
        authors = []
        for auth in raw_authors:
            if not isinstance(auth, dict):
                continue
            name = (
                auth.get("normalizedName")
                or auth.get("preferredName")
                or auth.get("full_name")
                or (
                    f"{auth.get('lastName', '')}, {auth.get('firstName', '')}".strip(", ")
                )
            )
            if name:
                authors.append(name.strip())

        venue = (
            a.get("publicationTitle")
            or a.get("displayPublicationTitle")
            or a.get("confTitle")
            or a.get("publisher")
            or "[unverified]"
        )

        article_num = a.get("articleNumber", "")
        doc_link    = a.get("documentLink", "")
        paper_url   = (
            f"{IEEE_BASE}{doc_link}" if doc_link.startswith("/")
            else doc_link
            or (f"{IEEE_BASE}/document/{article_num}" if article_num else "")
        )

        # Strip IEEE search highlight markup: [::keyword::] -> keyword
        raw_abstract = (a.get("abstract") or "").strip()
        abstract = re.sub(r"\[::", "", re.sub(r"::\]", "", raw_abstract))

        raw_title = (a.get("articleTitle") or a.get("title") or "").strip()
        clean_title = re.sub(r"\[::", "", re.sub(r"::\]", "", raw_title))

        papers.append({
            "title":    clean_title,
            "authors":  authors,
            "year":     str(a.get("publicationYear") or ""),
            "venue":    venue,
            "abstract": abstract,
            "doi":      a.get("doi", ""),
            "url":      paper_url,
        })

    return papers, total


# ---------------------------------------------------------------------------
# Primary: network interception
# ---------------------------------------------------------------------------

async def fetch_via_intercept(
    page, query: str, page_num: int
) -> tuple[list[dict], int]:
    """
    Navigate to the search results page and intercept the /rest/search response
    that IEEE Xplore fires automatically. The browser sends it with all correct
    cookies and CSRF headers, so we get the full JSON including abstract + authors.
    """
    captured: dict = {}

    async def on_response(response):
        if "/rest/search" in response.url and response.status == 200:
            try:
                body = await response.json()
                captured.update(body)
            except Exception:
                pass

    page.on("response", on_response)

    url = (
        f"{IEEE_SEARCH_URL}"
        f"?queryText={query.replace(' ', '+')}"
        f"&pageNumber={page_num}"
        f"&rowsPerPage={RESULTS_PER_PAGE}"
    )
    await page.goto(url, wait_until="networkidle", timeout=30_000)

    page.remove_listener("response", on_response)

    if not captured:
        raise RuntimeError("No /rest/search response intercepted")

    return _parse_api_json(captured)


# ---------------------------------------------------------------------------
# Fallback: DOM parsing
# ---------------------------------------------------------------------------

async def fetch_via_dom(
    page, query: str, page_num: int
) -> tuple[list[dict], int]:
    """Parse the search results HTML. Gives title + year + venue only."""
    url = (
        f"{IEEE_SEARCH_URL}"
        f"?queryText={query.replace(' ', '+')}"
        f"&pageNumber={page_num}"
    )
    await page.goto(url, wait_until="domcontentloaded", timeout=30_000)

    try:
        await page.wait_for_selector(
            "xpl-search-result, .List-results-item, .result-item",
            timeout=20_000,
        )
    except PlaywrightTimeout:
        print("  Timeout: no result elements found in DOM.")
        return [], 0

    items = (
        await page.query_selector_all("xpl-search-result")
        or await page.query_selector_all(".List-results-item")
        or await page.query_selector_all(".result-item")
    )

    papers = []
    for item in items:
        try:
            title_el = await item.query_selector("h3 a, .result-item-title a")
            if not title_el:
                continue
            title = (await title_el.inner_text()).strip()
            href  = await title_el.get_attribute("href") or ""
            paper_url = f"{IEEE_BASE}{href}" if href.startswith("/") else href

            # Year + venue
            desc_el  = await item.query_selector(".description, .publisher-info-container")
            desc_txt = (await desc_el.inner_text()).strip() if desc_el else ""
            year_m   = re.search(r"\b(19|20)\d{2}\b", desc_txt)
            year     = year_m.group(0) if year_m else ""

            papers.append({
                "title":    title,
                "authors":  [],        # not available from DOM without clicking through
                "year":     year,
                "venue":    desc_txt,
                "abstract": "",        # not shown in search list
                "doi":      "",
                "url":      paper_url,
            })

        except Exception as exc:
            print(f"  Skipping one item: {exc}")
            continue

    return papers, len(papers)


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

async def run(query: str, max_pages: int, headless: bool, no_pause: bool) -> None:
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            headless=headless,
            slow_mo=150 if not headless else 0,
            args=["--disable-blink-features=AutomationControlled"],
        )
        ctx = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1280, "height": 900},
            locale="en-US",
        )
        page = await ctx.new_page()

        print(f"\nOpening {IEEE_BASE} ...")
        await page.goto(IEEE_BASE, wait_until="domcontentloaded", timeout=20_000)

        if not headless and not no_pause:
            print("\n" + "-" * 60)
            print("Browser is open.")
            print("To use SUT library access:")
            print("  1. Go to https://library.sut.ac.th/clremsite/?m=eresource")
            print("  2. Click [IEEE/IET Electronic Library (IEL)]")
            print("  3. Log in with your SUT account")
            print("  4. Wait until IEEE Xplore is open in the browser")
            print("-" * 60)
            print("Press ENTER to start scraping...")
            await asyncio.get_event_loop().run_in_executor(None, input)

        all_papers: list[dict] = []

        for pg in range(1, max_pages + 1):
            print(f"\n[Page {pg}/{max_pages}]  query: {query!r}")

            # Primary: intercept network response
            try:
                papers, total = await fetch_via_intercept(page, query, pg)
                has_abstract  = sum(1 for p in papers if p.get("abstract"))
                print(
                    f"  [intercept OK] {len(papers)} papers, "
                    f"{has_abstract} with abstract  (total in DB: {total})"
                )
            except Exception as exc:
                print(f"  [intercept FAIL: {exc}] -> DOM fallback")
                papers, total = await fetch_via_dom(page, query, pg)
                print(f"  [DOM] {len(papers)} papers (no abstract)")

            all_papers.extend(papers)

            if total and pg * RESULTS_PER_PAGE >= total:
                print("  End of results.")
                break

        await browser.close()

    # Save
    print(f"\n{'─' * 60}")
    if not all_papers:
        print("No papers found. Try a different query.")
        sys.exit(1)

    print(f"Total scraped: {len(all_papers)} papers")
    saved = append_papers(PAPERS_LOG, all_papers)
    print(f"Saved to: {PAPERS_LOG}")
    print(f"{'─' * 60}")
    for num, title in saved:
        short = title[:70] + "..." if len(title) > 70 else title
        print(f"  [{num}] {short}")
    print(f"{'─' * 60}\n")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Scrape IEEE Xplore -> papers_log.md",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("query", help='e.g. "virtual synchronous generator hardware"')
    parser.add_argument(
        "--pages", type=int, default=2, metavar="N",
        help="Result pages to fetch (25 papers/page, default: 2)",
    )
    parser.add_argument(
        "--headless", action="store_true",
        help="Run browser without GUI (cannot log in via SUT proxy)",
    )
    parser.add_argument(
        "--no-pause", action="store_true",
        help="Skip the manual login pause",
    )
    args = parser.parse_args()
    asyncio.run(run(args.query, args.pages, args.headless, args.no_pause))


if __name__ == "__main__":
    main()
