# ConsideraWeb.Ng.Template

Angular 21 app on Forge and `@considera-core/angular-extensions`, served at `/template/home`.

## Commands

| Command         | Does                                              |
|-----------------|---------------------------------------------------|
| `npm i`         | Install (needs `NODE_AUTH_TOKEN`, see `.npmrc`)   |
| `npm start`     | Serve at http://localhost:4299/template/home      |
| `npm run build` | Production build to `dist/consideraweb-ng-template/browser` |
| `npm test`      | Unit tests (Vitest)                               |

## Releases

Commit headers are `[Major|Minor] [XX-CWEB-123] Title`; no keyword means a patch. Pushing to `master` deploys to S3
and tags `v1.2.3`; other branches tag `v1.2.3-N.BRANCH` prereleases, deleted when the branch's PR closes. See
`release/`.
