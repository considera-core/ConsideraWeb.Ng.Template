// Copies this template into a sibling folder and renames everything in it.
// Usage: node scripts/create.mjs ConsideraWeb.Ng.Some.Name [--app some-name] [--title "ConsideraWeb Some Name"] [--port 4201]
//   --app    the URL segment the app is served under (/some-name/); defaults to the last part of the name, lowercased
//   --title  the browser tab title; defaults to "ConsideraWeb " + the last part of the name
//   --port   the ng serve port; defaults to 4200
// The new folder gets a fresh git repo (master) with .githooks enabled; nothing is committed or installed.
import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const TEMPLATE = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SKIP = new Set(['.git', '.angular', 'dist', 'node_modules', 'scripts']);
const BINARY = /\.(ico|png|jpe?g|gif|woff2?|ttf|eot)$/i;

const args = process.argv.slice(2);
const option = (flag) => {
  const i = args.indexOf(flag);
  return i === -1 ? undefined : args[i + 1];
};
const name = args.find((a, i) => !a.startsWith('--') && !args[i - 1]?.startsWith('--'));
if (!name || !/^[A-Za-z0-9.]+$/.test(name)) {
  console.error('Usage: node scripts/create.mjs ConsideraWeb.Ng.Some.Name [--app some-name] [--title "..."] [--port 4201]');
  process.exit(1);
}

const last = name.split('.').at(-1);
const app = option('--app') ?? last.toLowerCase();
const title = option('--title') ?? `ConsideraWeb ${last}`;
const port = option('--port') ?? '4200';
const project = name.toLowerCase().replace(/\./g, '-');
const target = resolve(TEMPLATE, '..', name);
if (existsSync(target)) {
  console.error(`${target} already exists.`);
  process.exit(1);
}

// the template's own names, each distinct enough to replace in every text file
const REPLACEMENTS = [
  ['ConsideraWeb.Ng.Template', name],
  ['consideraweb-ng-template', project],
  ['ConsideraWeb Template', title],
  ['/template/', `/${app}/`],
  ['4299', port]
];
// the lockfile only carries the project name; its hashes could contain the other tokens
const LOCKFILE_REPLACEMENTS = REPLACEMENTS.slice(1, 2);

cpSync(TEMPLATE, target, { recursive: true, filter: (src) => !SKIP.has(basename(src)) });

const files = (dir) => readdirSync(dir).flatMap((f) => (statSync(join(dir, f)).isDirectory() ? files(join(dir, f)) : [join(dir, f)]));
for (const file of files(target).filter((f) => !BINARY.test(f))) {
  const rules = basename(file) === 'package-lock.json' ? LOCKFILE_REPLACEMENTS : REPLACEMENTS;
  const before = readFileSync(file, 'utf8');
  const after = rules.reduce((text, [from, to]) => text.replaceAll(from, to), before);
  if (after !== before) {
    writeFileSync(file, after);
    console.log(`  renamed in ${relative(target, file)}`);
  }
}

const git = (...a) => execFileSync('git', a, { cwd: target, stdio: 'inherit' });
git('init', '-q', '-b', 'master');
git('config', 'core.hooksPath', '.githooks');

console.log(`\nCreated ${target}\n  project: ${project}\n  url:     /${app}/home\n  title:   ${title}\n  port:    ${port}\nNext: work through TODO.md.`);
