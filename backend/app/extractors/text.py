"""
Plain text and code file extractor.
"""


def extract_text_file(file_path: str) -> str:
    """
    Extract text from a plain text or code file.
    
    Args:
        file_path: Path to the text file
    
    Returns:
        File content as text
    """
    # Try different encodings
    encodings = ['utf-8', 'latin-1', 'cp1252']
    
    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    
    # Fallback: read as binary and decode with errors ignored
    with open(file_path, 'rb') as f:
        return f.read().decode('utf-8', errors='ignore')
