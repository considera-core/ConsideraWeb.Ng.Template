# ConsideraWeb.Ng.Template

Angular 21 app on Forge and `@considera-core/angular-extensions`, served at `/template/home`.

## Commands

| Command         | Does                                                                     |
|-----------------|--------------------------------------------------------------------------|
| `npm i`         | Install (needs `NODE_AUTH_TOKEN`, see `.npmrc`)                          |
| `npm start`     | Serve at https://local.considera.dev/template/home, `/api` proxied to :5079 |
| `npm run build` | Production build to `dist/consideraweb-ng-template/browser`              |
| `npm test`      | Unit tests (Vitest)                                                      |

`npm start` needs `local.considera.dev` pointing at `127.0.0.1` in the hosts file and the dev certificates in
`../ConsideraWeb.Proxy`. The API proxy is in `proxy.conf.json`.

## Releases

Commit headers are `[Major|Minor] [XX-CWEB-123] Title`; no keyword means a patch. Pushing to `master` deploys to S3
and tags `1.2.3`; other branches tag `1.2.3-N.BRANCH` prereleases, deleted when the branch's PR closes. See
`release/`.
