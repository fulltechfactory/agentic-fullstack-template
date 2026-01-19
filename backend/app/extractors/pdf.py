"""
PDF text extractor using pdfplumber with PyMuPDF fallback.
"""

import pdfplumber


def extract_pdf(file_path: str) -> str:
    """
    Extract text from a PDF file.

    Uses pdfplumber first, falls back to PyMuPDF if no text extracted.

    Args:
        file_path: Path to the PDF file

    Returns:
        Extracted text content
    """
    # Try pdfplumber first
    text = _extract_with_pdfplumber(file_path)

    # Fallback to PyMuPDF if pdfplumber fails
    if not text.strip():
        text = _extract_with_pymupdf(file_path)

    return text


def _extract_with_pdfplumber(file_path: str) -> str:
    """Extract text using pdfplumber."""
    text_parts = []

    try:
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text_parts.append(page_text)
    except Exception:
        pass

    return "\n\n".join(text_parts)


def _extract_with_pymupdf(file_path: str) -> str:
    """Extract text using PyMuPDF (fitz) as fallback."""
    try:
        import fitz  # PyMuPDF

        text_parts = []
        with fitz.open(file_path) as doc:
            for page in doc:
                page_text = page.get_text()
                if page_text:
                    text_parts.append(page_text)

        return "\n\n".join(text_parts)
    except ImportError:
        return ""
    except Exception:
        return ""
