import { Routes } from '@angular/router';

// The CDN redirects /<app> to /<app>/home, so home must exist; replace it with the app's real routes
export const routes: Routes = [
  { path: 'home', children: [] },
  { path: '**', redirectTo: 'home' }
];
