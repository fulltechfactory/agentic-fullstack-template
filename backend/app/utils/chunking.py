"""
Text chunking utilities for RAG ingestion.

Implements recursive character text splitting with overlap for optimal
embedding and retrieval performance.
"""

from dataclasses import dataclass
from typing import List
import re


@dataclass
class ChunkingConfig:
    """Configuration for text chunking."""
    chunk_size: int = 1000  # Target size in characters
    chunk_overlap: int = 200  # Overlap between chunks
    min_chunk_size: int = 100  # Minimum chunk size (avoid tiny chunks)
    separators: tuple = ("\n\n", "\n", ". ", " ", "")  # Split priority


@dataclass
class TextChunk:
    """A chunk of text with metadata."""
    content: str
    chunk_index: int
    total_chunks: int
    start_char: int
    end_char: int


def chunk_text(
    text: str,
    config: ChunkingConfig = None,
) -> List[TextChunk]:
    """
    Split text into overlapping chunks for RAG ingestion.

    Uses recursive character text splitting: tries to split on paragraph
    boundaries first, then sentences, then words, then characters.

    Args:
        text: The text to chunk
        config: Chunking configuration (uses defaults if None)

    Returns:
        List of TextChunk objects with content and metadata
    """
    if config is None:
        config = ChunkingConfig()

    # Clean the text
    text = text.strip()

    # If text is small enough, return as single chunk
    if len(text) <= config.chunk_size:
        return [TextChunk(
            content=text,
            chunk_index=0,
            total_chunks=1,
            start_char=0,
            end_char=len(text),
        )]

    # Split recursively
    raw_chunks = _recursive_split(text, config.separators, config.chunk_size)

    # Merge small chunks and create overlapping chunks
    chunks = _create_overlapping_chunks(raw_chunks, config)

    # Create TextChunk objects with metadata
    result = []
    total = len(chunks)
    char_pos = 0

    for i, chunk_content in enumerate(chunks):
        # Find actual position in original text (approximate due to overlap)
        start_char = text.find(chunk_content[:50]) if len(chunk_content) >= 50 else text.find(chunk_content)
        if start_char == -1:
            start_char = char_pos

        result.append(TextChunk(
            content=chunk_content,
            chunk_index=i,
            total_chunks=total,
            start_char=start_char,
            end_char=start_char + len(chunk_content),
        ))
        char_pos = start_char + len(chunk_content) - config.chunk_overlap

    return result


def _recursive_split(text: str, separators: tuple, chunk_size: int) -> List[str]:
    """
    Recursively split text using a hierarchy of separators.
    """
    if not text:
        return []

    if len(text) <= chunk_size:
        return [text]

    # Try each separator in order
    for sep in separators:
        if sep == "":
            # Last resort: split by characters
            return _split_by_size(text, chunk_size)

        if sep in text:
            splits = text.split(sep)

            # If we got reasonable splits, process them
            if len(splits) > 1:
                result = []
                current = ""

                for split in splits:
                    # Add separator back (except for last)
                    piece = split + sep if split != splits[-1] else split

                    if len(current) + len(piece) <= chunk_size:
                        current += piece
                    else:
                        if current:
                            result.append(current.strip())

                        # If piece itself is too large, split it further
                        if len(piece) > chunk_size:
                            # Find next separator in hierarchy
                            next_sep_idx = separators.index(sep) + 1
                            if next_sep_idx < len(separators):
                                sub_chunks = _recursive_split(
                                    piece,
                                    separators[next_sep_idx:],
                                    chunk_size
                                )
                                result.extend(sub_chunks)
                                current = ""
                            else:
                                result.extend(_split_by_size(piece, chunk_size))
                                current = ""
                        else:
                            current = piece

                if current.strip():
                    result.append(current.strip())

                return result

    # Fallback: split by size
    return _split_by_size(text, chunk_size)


def _split_by_size(text: str, chunk_size: int) -> List[str]:
    """Split text into chunks of approximately chunk_size."""
    chunks = []
    for i in range(0, len(text), chunk_size):
        chunks.append(text[i:i + chunk_size])
    return chunks


def _create_overlapping_chunks(chunks: List[str], config: ChunkingConfig) -> List[str]:
    """
    Create overlapping chunks from a list of non-overlapping chunks.
    Merges small chunks and adds overlap between chunks.
    """
    if not chunks:
        return []

    # First pass: merge very small chunks
    merged = []
    current = ""

    for chunk in chunks:
        if len(current) + len(chunk) <= config.chunk_size:
            current += (" " if current else "") + chunk
        else:
            if current:
                merged.append(current)
            current = chunk

    if current:
        merged.append(current)

    # Filter out chunks that are too small (unless it's the only chunk)
    if len(merged) > 1:
        merged = [c for c in merged if len(c) >= config.min_chunk_size]

    if not merged:
        return chunks[:1] if chunks else []

    # Second pass: add overlap
    if len(merged) <= 1 or config.chunk_overlap == 0:
        return merged

    overlapped = [merged[0]]

    for i in range(1, len(merged)):
        prev_chunk = merged[i - 1]
        curr_chunk = merged[i]

        # Get overlap from end of previous chunk
        overlap_text = prev_chunk[-config.chunk_overlap:] if len(prev_chunk) > config.chunk_overlap else prev_chunk

        # Find a good break point in the overlap (prefer word boundary)
        space_idx = overlap_text.find(' ')
        if space_idx > 0:
            overlap_text = overlap_text[space_idx + 1:]

        overlapped.append(overlap_text + " " + curr_chunk)

    return overlapped
