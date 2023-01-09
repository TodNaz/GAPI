module gapi.gl.extensions.sdlsurface;

version(BackendGL):

import gapi;
import gapi.extensions.sdlsurface;
import bindbc.sdl;
import gapi.gl;

version (Posix)
{
    import gapi.extensions.pxx11;
    import gapi.gl.extensions.pxx11;

    import x11.Xlib : Display;

    final class SDL_GAPISurface : GLPosixX11Surface
    {
        public
        {
            SDL_SysWMinfo wmInfo;
            SDL_WindowInfo windowInfo;
        }

        this(SDL_WindowInfo windowInfo, RCIAllocator allocator)
        {
            PosixX11WindowInfo posixWindowInfo;
            this.windowInfo = windowInfo;
            
            SDL_VERSION(&wmInfo.version_);
            SDL_GetWindowWMInfo(*windowInfo.window, &wmInfo);

            posixWindowInfo.dpy = cast(Display*) wmInfo.info.x11.display;
            posixWindowInfo.wnd = cast(ulong*) &wmInfo.info.x11.window;

            super(posixWindowInfo, allocator);
        }

        override SwapChain createSwapChain(Device device, CreateSwapChainInfo createInfo)
        {
            GLPosixX11SwapChain sc = make!(GLPosixX11SwapChain)(allocator, cast(Display*) wmInfo.info.x11.display, cast(GLPosixX11Surface) this, createInfo, allocator);
            SDL_DestroyWindow(*windowInfo.window);
            *windowInfo.window = SDL_CreateWindowFrom(cast(void*) wmInfo.info.x11.window);

            return sc;
        } 
    }
}

Surface SDL_CreateGAPISurface(Instance instance, SDL_WindowInfo windowInfo)
{
    GLInstance glinstance = cast(GLInstance) instance;

    SDL_GAPISurface surface = make!(SDL_GAPISurface)(glinstance.allocator, windowInfo, glinstance.allocator);

    return surface;
}