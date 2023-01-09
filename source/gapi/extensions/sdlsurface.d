module gapi.extensions.sdlsurface;

import gapi;
import bindbc.sdl;

struct SDL_WindowInfo
{
    public
    {
        SDL_Window** window;
    }
}

Surface function(Instance, SDL_WindowInfo) createSurfaceFromWindow;