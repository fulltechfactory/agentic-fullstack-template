"""
Text extractors for various file formats.
"""

from pathlib import Path
from typing import Tuple

# Supported extensions by category
DOCUMENT_EXTENSIONS = {'.pdf', '.docx'}
TEXT_EXTENSIONS = {'.txt', '.md'}
CODE_EXTENSIONS = {
    '.py', '.js', '.ts', '.tsx', '.jsx',
    '.c', '.cpp', '.h', '.hpp', '.rs', '.go', '.java',
    '.html', '.css', '.scss', '.json', '.yaml', '.yml',
    '.sql', '.sh', '.bash', '.zsh',
    '.xml', '.toml', '.ini', '.env',
}

ALL_EXTENSIONS = DOCUMENT_EXTENSIONS | TEXT_EXTENSIONS | CODE_EXTENSIONS

# Language detection by extension
LANGUAGE_MAP = {
    '.py': 'python',
    '.js': 'javascript',
    '.ts': 'typescript',
    '.tsx': 'typescript-react',
    '.jsx': 'javascript-react',
    '.c': 'c',
    '.cpp': 'cpp',
    '.h': 'c-header',
    '.hpp': 'cpp-header',
    '.rs': 'rust',
    '.go': 'go',
    '.java': 'java',
    '.html': 'html',
    '.css': 'css',
    '.scss': 'scss',
    '.json': 'json',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.sql': 'sql',
    '.sh': 'shell',
    '.bash': 'bash',
    '.zsh': 'zsh',
    '.xml': 'xml',
    '.toml': 'toml',
    '.ini': 'ini',
    '.md': 'markdown',
    '.txt': 'text',
}


def get_file_category(extension: str) -> str:
    """Get file category from extension."""
    ext = extension.lower()
    if ext in DOCUMENT_EXTENSIONS:
        return 'document'
    elif ext in TEXT_EXTENSIONS:
        return 'text'
    elif ext in CODE_EXTENSIONS:
        return 'code'
    return 'unknown'


def is_supported(filename: str) -> bool:
    """Check if file extension is supported."""
    ext = Path(filename).suffix.lower()
    return ext in ALL_EXTENSIONS


def extract_text(file_path: str, filename: str) -> Tuple[str, dict]:
    """
    Extract text from a file.
    
    Args:
        file_path: Path to the temporary file
        filename: Original filename (for extension detection)
    
    Returns:
        Tuple of (extracted_text, metadata)
    """
    ext = Path(filename).suffix.lower()
    category = get_file_category(ext)
    
    metadata = {
        'filename': filename,
        'extension': ext,
        'category': category,
    }
    
    if ext == '.pdf':
        from app.extractors.pdf import extract_pdf
        text = extract_pdf(file_path)
    elif ext == '.docx':
        from app.extractors.docx import extract_docx
        text = extract_docx(file_path)
    elif category in ('text', 'code'):
        from app.extractors.text import extract_text_file
        text = extract_text_file(file_path)
        if category == 'code':
            metadata['language'] = LANGUAGE_MAP.get(ext, 'unknown')
    else:
        raise ValueError(f"Unsupported file extension: {ext}")
    
    metadata['char_count'] = len(text)
    
    return text, metadata
