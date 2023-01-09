module vaapi.vaapi;

import bindbc.loader;

alias VADisplay = void*;
alias VAStatus = int;

version(Posix)
{
    import x11.Xlib : Display;

    VADisplay vaGetDisplay(Display* dpy)
    {
        return cast(VADisplay) dpy;
    }
}

alias FvaInitialize = extern(C) VAStatus function(VADisplay dpy, int* maj, int* min);

__gshared
{
    SharedLib vaLib;

    FvaInitialize vaInitialize;
}

void loadVAAPI()
{
    vaLib = load("/usr/lib64/libva-x11.so.2");
    if (vaLib == invalidHandle)
    {
        throw new Exception("VA-API error!");
    }

    void bindOrError(void** ptr,string name) @trusted
    {
        import std.string : toStringz;
        bindSymbol(vaLib, ptr, name.toStringz);

        if(*ptr is null) throw new Exception("Not load library!");
    }

    bindOrError(cast(void**) &vaInitialize, "vaInitialize");
}