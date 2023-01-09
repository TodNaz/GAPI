module gapi.extensions.pxx11;

version(Posix):

import x11.Xlib;
import x11.X;
import gapi.extensions.surface;

struct PosixX11WindowInfo
{
    public
    {
        Display* dpy;
        Window* wnd;
    }
}

Surface function(Instance, PosixX11WindowInfo) createSurfaceFromWindow;