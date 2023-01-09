module gapi.extensions.win32wi;

version(Windows):
import core.sys.windows.windows;
import gapi.extensions.surface;

struct Win32WindowInfo
{
    public
    {
        HMODULE hInstance;
        HANDLE* wnd;
    }
}

Surface function(Instance, Win32WindowInfo) createSurfaceFromWindow;