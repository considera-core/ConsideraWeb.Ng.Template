// Computes the next version from commit headers, tags it and creates a GitHub release.
//   master       -> 1.2.3
//   other branch -> 1.2.3-N.BRANCH-NAME (branch case kept), a GitHub prerelease that cleanup.cjs deletes when its PR closes.
// A branch's 1.2.3 is the version master will release when the branch merges, and N counts the branch's releases of it
// (1.2.3-0.X, 1.2.3-1.X, ...), so every branch build sorts below the 1.2.3 it becomes. The first release is 1.0.0.
// Tags have no v prefix; older v-prefixed tags are still read so versions carry on from them.
// Commit headers: [Major|Minor] [STORY-123] Title (default is a patch). See commit-format.cjs.
// Usage: node release/release.cjs [--dry-run]
// The version and tag are written to $GITHUB_OUTPUT either way, so the workflow can deploy before it tags.
const { execFileSync } = require('node:child_process');
const { appendFileSync } = require('node:fs');
const { parseHeader } = require('./commit-format.cjs');

const DRY_RUN = process.argv.includes('--dry-run');
const BASE = [1, 0, 0];
const RANK = { patch: 1, minor: 2, major: 3 };
const SECTIONS = [['major', 'Breaking changes'], ['minor', 'Features'], ['patch', 'Fixes and changes']];

const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'], ...opts })?.trim() ?? '';
const git = (...args) => run('git', args);

const branch = process.env.GITHUB_REF_NAME || git('rev-parse', '--abbrev-ref', 'HEAD');
const isMaster = branch === 'master';
const suffix = branch.replace(/[^A-Za-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');

const tryRun = (cmd, args) => {
  try {
    return run(cmd, args, { stdio: 'pipe' });
  } catch {
    return '';
  }
};

const tagged = git('tag', '-l').split('\n').filter(Boolean);
const cmp = (a, b) => a.core.reduce((d, n, i) => d || n - b.core[i], 0);
const versions = tagged
  .map((t) => /^v?(\d+)\.(\d+)\.(\d+)(?:-(.+))?$/.exec(t))
  .filter(Boolean)
  .map((m) => {
    const branchPre = /^(\d+)\.(.+)$/.exec(m[4] ?? '');
    return { tag: m[0], core: [+m[1], +m[2], +m[3]], pre: m[4] ?? null, n: branchPre ? +branchPre[1] : 0, branch: branchPre?.[2] };
  });
const latest = (list) => list.sort((a, b) => cmp(a, b) || a.n - b.n).at(-1);

const stable = latest(versions.filter((t) => !t.pre));
const ownReleases = versions.filter((t) => t.branch === suffix);
const last = isMaster ? stable : latest(ownReleases) ?? stable;

const commitsIn = (range) => git('log', range, '--format=%h%x09%B%x00')
  .split('\0')
  .map((c) => c.trim())
  .filter(Boolean)
  .map((c) => ({ short: c.slice(0, c.indexOf('\t')), message: c.slice(c.indexOf('\t') + 1) }))
  .map((c) => ({ ...c, parsed: parseHeader(c.message) }))
  .filter((c) => c.parsed);

// commits since the last release; a branch's first release only looks at its own commits (not master's history)
const branchRange = !isMaster && tryRun('git', ['rev-parse', '--verify', '-q', 'origin/master']) ? 'origin/master..HEAD' : 'HEAD';
const range = last ? `${last.tag}..HEAD` : isMaster ? 'HEAD' : branchRange;
const commits = commitsIn(range);

if (!commits.length) {
  console.log('No releasable commits, nothing to release.');
  process.exit(0);
}

// a branch bumps the last stable release by everything it carries, which is what master releases once it merges
const releaseOf = (list) => list.reduce((r, c) => (RANK[c.parsed.release] > RANK[r] ? c.parsed.release : r), 'patch');
const release = releaseOf(isMaster ? commits : commitsIn(branchRange));
const bump = ([maj, min, pat]) => ({ major: [maj + 1, 0, 0], minor: [maj, min + 1, 0], patch: [maj, min, pat + 1] })[release];
const core = stable ? bump(stable.core) : BASE;
const sameCore = ownReleases.filter((t) => cmp(t, { core }) === 0);
const increment = sameCore.length ? Math.max(...sameCore.map((t) => t.n)) + 1 : 0;
const version = core.join('.') + (isMaster ? '' : `-${increment}.${suffix}`);
const tag = version;

const notes = SECTIONS.map(([key, heading]) => {
  const lines = commits.filter((c) => c.parsed.release === key).map((c) => `- ${c.parsed.storyId ? `**${c.parsed.storyId}** ` : ''}${c.parsed.title} (${c.short})`);
  return lines.length ? `### ${heading}\n\n${lines.join('\n')}` : '';
}).filter(Boolean).join('\n\n');

console.log(`${last ? last.tag : '(none)'} -> ${tag} (${stable ? release : 'base'})\n${notes}`);
if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `version=${version}\ntag=${tag}\n`);
if (DRY_RUN) process.exit(0);

git('config', 'user.name', 'github-actions[bot]');
git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com');
git('tag', '-a', tag, '-m', tag);
git('push', 'origin', tag);
run('gh', ['release', 'create', tag, '--title', tag, '--notes', `## ${version}\n\n${notes}`, '--verify-tag', ...(isMaster ? [] : ['--prerelease'])], { stdio: 'inherit' });
