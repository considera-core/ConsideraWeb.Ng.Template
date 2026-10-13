const { readFileSync } = require('node:fs');
const { validateHeader } = require('./commit-format.cjs');

const error = validateHeader(readFileSync(process.argv[2], 'utf8'));
if (error) {
  console.error(`✖ ${error}\n  Format: [Major|Minor] [STORY-123] Title`);
  process.exit(1);
}
