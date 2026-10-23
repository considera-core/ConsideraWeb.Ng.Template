import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter } from '@angular/router';
import { HEADING_LEVEL_SHIFT } from '@considera-core/angular-extensions';

import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    {
      provide: HEADING_LEVEL_SHIFT,
      useValue: 2
    }
  ]
};
