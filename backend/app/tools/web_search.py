"""
Web search tool using DuckDuckGo HTML interface.
Fallback for providers without native web search (Ollama, LM Studio).
"""
import asyncio
import random
import re
from typing import List, Dict
from urllib.parse import quote_plus, urljoin
import httpx
from bs4 import BeautifulSoup
from app.extractors.web import extract_web_content
from app.config.settings import settings


# User agents for rotation
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
]


def _get_headers() -> Dict[str, str]:
    """Get headers with random user agent."""
    return {
        'User-Agent': random.choice(USER_AGENTS),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,fr;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'DNT': '1',
        'Connection': 'keep-alive',
    }


async def _search_duckduckgo(query: str, num_results: int = 5) -> List[Dict[str, str]]:
    """
    Search DuckDuckGo HTML interface and return result URLs.

    Args:
        query: Search query
        num_results: Maximum number of results to return

    Returns:
        List of dicts with 'url', 'title', 'snippet'
    """
    search_url = f"https://html.duckduckgo.com/html/?q={quote_plus(query)}"

    async with httpx.AsyncClient(timeout=settings.WEB_SEARCH_TIMEOUT, follow_redirects=True) as client:
        response = await client.get(search_url, headers=_get_headers())
        response.raise_for_status()

    soup = BeautifulSoup(response.text, 'lxml')
    results = []

    for result in soup.select('.result'):
        if len(results) >= num_results:
            break

        # Get title and URL
        title_elem = result.select_one('.result__title a')
        if not title_elem:
            continue

        # DuckDuckGo uses redirect URLs, extract actual URL
        href = title_elem.get('href', '')
        # Extract actual URL from DuckDuckGo redirect
        url_match = re.search(r'uddg=([^&]+)', href)
        if url_match:
            from urllib.parse import unquote
            url = unquote(url_match.group(1))
        else:
            url = href

        # Skip non-http URLs
        if not url.startswith('http'):
            continue

        title = title_elem.get_text(strip=True)

        # Get snippet
        snippet_elem = result.select_one('.result__snippet')
        snippet = snippet_elem.get_text(strip=True) if snippet_elem else ''

        results.append({
            'url': url,
            'title': title,
            'snippet': snippet,
        })

    return results


async def _fetch_page_content(url: str, max_chars: int = 4000) -> Dict[str, str]:
    """
    Fetch and extract content from a URL.

    Args:
        url: Page URL
        max_chars: Maximum characters to extract

    Returns:
        Dict with 'url', 'title', 'content', 'error'
    """
    result = {
        'url': url,
        'title': '',
        'content': '',
        'error': None,
    }

    try:
        async with httpx.AsyncClient(timeout=settings.WEB_SEARCH_TIMEOUT, follow_redirects=True) as client:
            response = await client.get(url, headers=_get_headers())
            response.raise_for_status()

            content_type = response.headers.get('content-type', '')
            if 'text/html' not in content_type:
                result['error'] = f'Non-HTML content: {content_type}'
                return result

            text, metadata = extract_web_content(response.text, max_chars=max_chars)
            result['title'] = metadata.get('title', '')
            result['content'] = text

    except httpx.TimeoutException:
        result['error'] = 'Timeout'
    except httpx.HTTPStatusError as e:
        result['error'] = f'HTTP {e.response.status_code}'
    except Exception as e:
        result['error'] = str(e)

    return result


async def _search_web_async(query: str) -> str:
    """
    Async implementation of web search.

    Args:
        query: Search query

    Returns:
        Formatted search results with citations
    """
    # Get search results from DuckDuckGo
    search_results = await _search_duckduckgo(query, num_results=settings.WEB_SEARCH_NUM_RESULTS)

    if not search_results:
        return f"No search results found for: {query}"

    # Fetch content from each page with delay between requests
    pages = []
    for i, result in enumerate(search_results):
        if i > 0:
            await asyncio.sleep(settings.WEB_SEARCH_DELAY)

        page = await _fetch_page_content(result['url'])
        page['search_title'] = result['title']
        page['search_snippet'] = result['snippet']
        pages.append(page)

    # Format results
    formatted = []
    for i, page in enumerate(pages, 1):
        title = page['title'] or page['search_title']
        content = page['content'] or page['search_snippet']

        if not content:
            continue

        formatted.append(
            f"## [{i}] {title}\n"
            f"**Source:** {page['url']}\n\n"
            f"{content}"
        )

    if not formatted:
        return f"Found results but could not extract content for: {query}"

    header = f"### Web Search Results for: \"{query}\"\n\n"
    return header + "\n\n---\n\n".join(formatted)


def search_web(query: str) -> str:
    """
    Search the web for current information using DuckDuckGo.

    Use this tool when you need up-to-date information from the internet,
    such as recent news, current events, documentation, or facts that may
    have changed since your knowledge cutoff.

    Args:
        query: The search query describing what information to find

    Returns:
        Search results with content excerpts and source citations
    """
    try:
        # Run async function in event loop
        try:
            loop = asyncio.get_running_loop()
            # If we're already in an async context, create a task
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as executor:
                future = executor.submit(asyncio.run, _search_web_async(query))
                return future.result(timeout=settings.WEB_SEARCH_TIMEOUT + 10)
        except RuntimeError:
            # No running loop, we can use asyncio.run directly
            return asyncio.run(_search_web_async(query))

    except Exception as e:
        return f"Web search failed: {str(e)}"
