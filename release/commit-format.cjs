// Commit header format: <"Major" | "Minor" | ""> <StoryId?> <Title>
const HEADER = /^(?:(Major|Minor)\s+)?(?:([A-Z]{2}-CWEB-[0-9A-Z]+)\s+)?(\S.*)$/;
const HEADER_TYPE_LOOKALIKE = /^(major|minor)\b/i;
const HEADER_TYPE_STRICT = /^(Major|Minor)\s+\S/;

const firstLine = (message) => message.split(/\r?\n/, 1)[0].trim();

function parseHeader(message) {
  const header = firstLine(message);
  if (header.startsWith('Merge ')) return null;

  const match = HEADER.exec(header);
  if (!match) return null;

  const [, keyword, storyId, title] = match;
  return { release: keyword ? keyword.toLowerCase() : 'patch', storyId: storyId ?? null, title };
}

function validateHeader(message) {
  const header = firstLine(message);
  if (!header) return 'Commit message is empty.';
  if (HEADER_TYPE_LOOKALIKE.test(header) && !HEADER_TYPE_STRICT.test(header)) {
    return 'Use exactly "Major" or "Minor" (capitalized), followed by a title.';
  }
  return null;
}

module.exports = { parseHeader, validateHeader };
