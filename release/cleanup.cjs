// Deletes a branch's prerelease git tags and GitHub releases.
// Usage: node release/cleanup.cjs BRANCH-NAME [--dry-run]
// Matches what release.cjs tags for that branch: v1.2.3-N.BRANCH-NAME.
const { execFileSync } = require('node:child_process');

const DRY_RUN = process.argv.includes('--dry-run');
const branch = process.argv.slice(2).find((a) => !a.startsWith('--'));
if (!branch) {
  console.error('Usage: node release/cleanup.cjs BRANCH-NAME [--dry-run]');
  process.exit(1);
}
if (branch === 'master') {
  console.error('Refusing to clean up master.');
  process.exit(1);
}

const run = (cmd, args) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] }).trim();
const tryRun = (cmd, args) => {
  try {
    return run(cmd, args);
  } catch {
    return null;
  }
};

const suffix = branch.replace(/[^A-Za-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
const escaped = suffix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const isBranchTag = (t) => new RegExp(`^v\\d+\\.\\d+\\.\\d+-\\d+\\.${escaped}$`).test(t);

const tags = run('git', ['tag', '-l', 'v*']).split('\n').filter(isBranchTag);
console.log(`${tags.length} tags belong to ${branch}: ${tags.join(', ') || '(none)'}`);
if (DRY_RUN) process.exit(0);

// a tag whose release was never created is deleted directly
for (const tag of tags) {
  if (tryRun('gh', ['release', 'delete', tag, '--cleanup-tag', '--yes']) === null) tryRun('git', ['push', '--delete', 'origin', tag]);
  console.log(`Deleted tag ${tag}`);
}
