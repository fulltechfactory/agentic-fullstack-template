"""
PDF text extractor using PyMuPDF with column-aware extraction.
"""

from typing import List, Tuple


def extract_pdf(file_path: str) -> str:
    """
    Extract text from a PDF file with column-aware layout detection.

    Uses PyMuPDF with block-based extraction to properly handle
    multi-column layouts.

    Args:
        file_path: Path to the PDF file

    Returns:
        Extracted text content
    """
    # Try PyMuPDF with column detection first
    text = _extract_with_pymupdf_blocks(file_path)

    # Fallback to simple extraction if blocks fail
    if not text.strip():
        text = _extract_with_pymupdf_simple(file_path)

    # Last resort: pdfplumber
    if not text.strip():
        text = _extract_with_pdfplumber(file_path)

    return text


def _extract_with_pymupdf_blocks(file_path: str) -> str:
    """
    Extract text using PyMuPDF with block-based column detection.

    This method extracts text blocks and sorts them to respect
    multi-column layouts by reading columns left-to-right.
    """
    try:
        import fitz  # PyMuPDF

        text_parts = []
        with fitz.open(file_path) as doc:
            for page in doc:
                page_text = _extract_page_with_columns(page)
                if page_text:
                    text_parts.append(page_text)

        return "\n\n".join(text_parts)
    except ImportError:
        return ""
    except Exception:
        return ""


def _extract_page_with_columns(page) -> str:
    """
    Extract text from a page respecting column layout.

    Detects columns by analyzing block x-coordinates and reads
    each column top-to-bottom before moving to the next.
    """
    # Get text blocks: (x0, y0, x1, y1, "text", block_no, block_type)
    blocks = page.get_text("blocks")

    # Filter text blocks only (block_type == 0)
    text_blocks = [b for b in blocks if b[6] == 0 and b[4].strip()]

    if not text_blocks:
        return ""

    # Detect columns by analyzing x-coordinates
    columns = _detect_columns(text_blocks, page.rect.width)

    # Sort blocks by column, then by y-position within column
    sorted_blocks = _sort_blocks_by_columns(text_blocks, columns)

    # Extract text from sorted blocks
    texts = []
    for block in sorted_blocks:
        text = block[4].strip()
        if text:
            texts.append(text)

    return "\n\n".join(texts)


def _detect_columns(blocks: List, page_width: float) -> List[Tuple[float, float]]:
    """
    Detect column boundaries from text blocks.

    Returns list of (x_start, x_end) tuples for each detected column.
    """
    if not blocks:
        return [(0, page_width)]

    # Get x-coordinates of block left edges
    x_coords = sorted(set(b[0] for b in blocks))

    if len(x_coords) < 2:
        return [(0, page_width)]

    # Find gaps that indicate column separation
    # A gap is significant if it's larger than average block width
    avg_block_width = sum(b[2] - b[0] for b in blocks) / len(blocks)
    min_gap = avg_block_width * 0.3  # 30% of average block width

    columns = []
    col_start = 0

    for i in range(len(x_coords) - 1):
        gap = x_coords[i + 1] - x_coords[i]
        if gap > min_gap and gap > page_width * 0.1:  # Also require 10% of page width
            # Found a column boundary
            col_end = (x_coords[i] + x_coords[i + 1]) / 2
            columns.append((col_start, col_end))
            col_start = col_end

    # Add the last column
    columns.append((col_start, page_width))

    # If we detected too many columns (likely noise), fall back to simple detection
    if len(columns) > 4:
        # Try simple 2-column detection based on page center
        center = page_width / 2
        left_blocks = [b for b in blocks if b[2] < center]
        right_blocks = [b for b in blocks if b[0] > center]

        if left_blocks and right_blocks:
            return [(0, center), (center, page_width)]
        return [(0, page_width)]

    return columns if columns else [(0, page_width)]


def _sort_blocks_by_columns(blocks: List, columns: List[Tuple[float, float]]) -> List:
    """
    Sort blocks by column (left to right) then by y-position within column.
    """
    def get_column_index(block):
        x_center = (block[0] + block[2]) / 2
        for i, (col_start, col_end) in enumerate(columns):
            if col_start <= x_center <= col_end:
                return i
        return 0

    # Sort by column index first, then by y-position
    return sorted(blocks, key=lambda b: (get_column_index(b), b[1]))


def _extract_with_pymupdf_simple(file_path: str) -> str:
    """Extract text using PyMuPDF with simple extraction."""
    try:
        import fitz  # PyMuPDF

        text_parts = []
        with fitz.open(file_path) as doc:
            for page in doc:
                # Use sort=True to attempt basic layout preservation
                page_text = page.get_text(sort=True)
                if page_text:
                    text_parts.append(page_text)

        return "\n\n".join(text_parts)
    except ImportError:
        return ""
    except Exception:
        return ""


def _extract_with_pdfplumber(file_path: str) -> str:
    """Extract text using pdfplumber as last resort."""
    try:
        import pdfplumber

        text_parts = []
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                # Try layout-aware extraction
                page_text = page.extract_text(layout=True)
                if page_text:
                    text_parts.append(page_text)

        return "\n\n".join(text_parts)
    except ImportError:
        return ""
    except Exception:
        return ""
