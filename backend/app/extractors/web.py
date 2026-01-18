"""
Web content extractor for HTML pages.
"""
from typing import Tuple
from bs4 import BeautifulSoup


# Tags to remove completely (no content extraction)
REMOVE_TAGS = {
    'script', 'style', 'nav', 'header', 'footer', 'aside',
    'iframe', 'noscript', 'svg', 'form', 'button', 'input',
    'meta', 'link', 'head',
}

# Tags that typically contain main content
CONTENT_TAGS = {'article', 'main', 'section', 'div', 'p', 'span'}


def extract_web_content(html: str, max_chars: int = 8000) -> Tuple[str, dict]:
    """
    Extract readable text content from HTML.

    Args:
        html: Raw HTML content
        max_chars: Maximum characters to return (default 8000)

    Returns:
        Tuple of (extracted_text, metadata)
    """
    soup = BeautifulSoup(html, 'lxml')

    metadata = {
        'title': '',
        'description': '',
    }

    # Extract title
    title_tag = soup.find('title')
    if title_tag:
        metadata['title'] = title_tag.get_text(strip=True)

    # Extract meta description
    meta_desc = soup.find('meta', attrs={'name': 'description'})
    if meta_desc and meta_desc.get('content'):
        metadata['description'] = meta_desc['content']

    # Remove unwanted tags
    for tag in soup.find_all(REMOVE_TAGS):
        tag.decompose()

    # Try to find main content area first
    main_content = None
    for selector in ['article', 'main', '[role="main"]', '.content', '#content']:
        main_content = soup.select_one(selector)
        if main_content:
            break

    # Use main content if found, otherwise use body
    content_area = main_content or soup.body or soup

    # Extract text
    text_parts = []
    for element in content_area.find_all(['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'td', 'th', 'pre', 'code']):
        text = element.get_text(separator=' ', strip=True)
        if text and len(text) > 10:  # Filter very short fragments
            text_parts.append(text)

    # Join and deduplicate
    seen = set()
    unique_parts = []
    for part in text_parts:
        normalized = ' '.join(part.split())
        if normalized not in seen:
            seen.add(normalized)
            unique_parts.append(normalized)

    full_text = '\n\n'.join(unique_parts)

    # Truncate if needed
    if len(full_text) > max_chars:
        full_text = full_text[:max_chars] + '...'

    metadata['char_count'] = len(full_text)

    return full_text, metadata
