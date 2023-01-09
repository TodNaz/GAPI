module dglx.glx;

version(Posix):
version(Dynamic_GLX):
version(BackendGL):

import bindbc.loader;
import x11.X, x11.Xlib, x11.Xutil;

alias GLXLibrary = SharedLib;

__gshared GLXLibrary glxLib;

struct __GLXFBConfigRec;
struct __GLXcontextRec;

static immutable GLX_X_RENDERABLE = 0x8012;
static immutable GLX_DRAWABLE_TYPE = 0x8010;
static immutable GLX_RENDER_TYPE = 0x8011;
static immutable GLX_X_VISUAL_TYPE = 0x22;
static immutable GLX_RED_SIZE = 8;
static immutable GLX_GREEN_SIZE = 9;
static immutable GLX_BLUE_SIZE = 10;
static immutable GLX_ALPHA_SIZE = 11;
static immutable GLX_DEPTH_SIZE = 12;
static immutable GLX_STENCIL_SIZE = 13;
static immutable GLX_DOUBLEBUFFER = 5;
static immutable GLX_BUFFER_SIZE = 2;
static immutable GLX_RGBA = 4;
static immutable GLX_MAX_PBUFFER_WIDTH = 0x8016;
static immutable GLX_MAX_PBUFFER_HEIGHT = 0x8017;

static immutable GLX_WINDOW_BIT = 0x00000001;
static immutable GLX_PIXMAP_BIT = 0x00000002;
static immutable GLX_PBUFFER_BIT = 0x0004;
static immutable GLX_RGBA_BIT = 0x00000001;
static immutable GLX_TRUE_COLOR = 0x8002;
static immutable GLX_RGBA_TYPE = 0x8014;

static immutable GLX_SAMPLE_BUFFERS = 0x186a0;
static immutable GLX_SAMPLES = 0x186a1;

static immutable GLX_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
static immutable GLX_CONTEXT_MINOR_VERSION_ARB = 0x2092;
static immutable GLX_CONTEXT_FLAGS_ARB = 0x2094;
static immutable GLX_CONTEXT_PROFILE_MASK_ARB = 0x9126;

static immutable GLX_CONTEXT_DEBUG_BIT_ARB = 0x0001;
static immutable GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB = 0x0002;

static immutable GLX_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
static immutable GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002;

alias GLXDrawable = ulong;
alias GLXFBConfig = __GLXFBConfigRec*;
alias GLXContext = __GLXcontextRec*;
alias GLXWindow = XID;
alias GLXPbuffer = XID;
alias GLXPixmap = XID;

alias FglXQueryVersion = extern(C) bool function(Display *dpy,int *maj,int *min);
alias FglXChooseFBConfig = extern(C) GLXFBConfig* function(Display *dpy,int screen,const int *attribList, int *nitems);
alias FglXGetVisualFromFBConfig = extern(C) XVisualInfo* function(Display *dpy, GLXFBConfig config);
alias FglXGetFBConfigAttrib = extern(C) int function(Display *dpy, GLXFBConfig config,  int attribute, int *value);
alias FglXQueryExtensionsString = extern(C) const(char*) function(Display *dpy, int screen);
alias FglXCreateNewContext = extern(C) GLXContext function(Display *dpy, GLXFBConfig config,int renderType, 
                                                 GLXContext shareList, bool direct);

alias FglXMakeCurrent = extern(C) bool function(Display *dpy,GLXDrawable drawable, GLXContext ctx);
alias FglXDestroyContext = extern(C) void function(Display *dpy, GLXContext ctx);
alias FglXSwapBuffers = extern(C) void function(Display *dpy, GLXDrawable drawable);
alias FglXWaitX = extern(C) void function();
alias FglXChooseVisual = extern(C) XVisualInfo* function(Display *dpy,int ds,int* attribs);
alias FglXCreateContext = extern(C) GLXContext function(Display *dpy,XVisualInfo* vis,GLXContext shareList,bool direct);
alias FglXIsDirect = extern(C) bool function(Display *dpy,GLXContext context);
alias FglXGetProcAddressARB = extern(C) void* function(const char* procName);
alias FglXCreateContextAttribsARB = extern(C) GLXContext function(  Display *dpy, GLXFBConfig config,
                                                                    GLXContext share_context, Bool direct,
                                                                    const int *attrib_list);

alias FglXGetClientString = extern(C) const char* function(Display* dpy, int name);
alias FglXGetFBConfigs = extern(C) GLXFBConfig* function(Display *dpy, int screen, int *nelements);
alias FglXCreateWindow = extern(C) GLXWindow function(Display* dpy, GLXFBConfig config, Window win, const int* al);
alias FglXDestroyWindow = extern(C) void function(Display* dpy, GLXWindow wnd);
alias FglXCreatePixmap = extern(C) GLXPixmap function(Display* dpy, GLXFBConfig config, Pixmap pixmap, const int* attribs);
alias FglXCreateGLXPixmap = extern(C) GLXPixmap function(Display* dpy, XVisualInfo* vis, Pixmap pixmap);
alias FglXMakeContextCurrent = extern(C) bool function(Display* dpy, XID draw, XID read, GLXContext ctx);

__gshared
{
    FglXQueryVersion glXQueryVersion;
    FglXChooseFBConfig glXChooseFBConfig;
    FglXGetVisualFromFBConfig glXGetVisualFromFBConfig;
    FglXGetFBConfigAttrib glXGetFBConfigAttrib;
    FglXQueryExtensionsString glXQueryExtensionsString;
    FglXCreateNewContext glXCreateNewContext;
    FglXMakeCurrent glXMakeCurrent;
    FglXDestroyContext glXDestroyContext;
    FglXSwapBuffers glXSwapBuffers;
    FglXWaitX glXWaitX;
    FglXChooseVisual glXChooseVisual;
    FglXCreateContext glXCreateContext;
    FglXIsDirect glXIsDirect;
    FglXGetProcAddressARB glXGetProcAddress;
    FglXCreateContextAttribsARB glXCreateContextAttribsARB;
    FglXGetClientString glXGetClientString;
    FglXGetFBConfigs glXGetFBConfigs;
    FglXCreateWindow glXCreateWindow;
    FglXDestroyWindow glXDestroyWindow;
    FglXCreatePixmap glXCreatePixmap;
    FglXCreateGLXPixmap glXCreateGLXPixmap;
    FglXMakeContextCurrent glXMakeContextCurrent;
}

static string[] glxDefaultPaths = [
    "/usr/lib/libGLX.so",
    "/usr/lib/libGL.so",
    "/usr/lib/libGLX_nvidia.so",
];

/++
    Load GLX library, which should open context in x11 environment.

    Throws: `Exception` if library is not load.
+/
void loadGLXLibrary() @trusted
{
    import std.file : exists, dirEntries, SpanMode, DirEntry, isDir, isFile, write, read, mkdir;
    import std.string : toStringz;
    import std.algorithm : reverse, canFind;
    import std.parallelism : parallel;
    import std.process : environment;
    debug import std.stdio;

    immutable configDir = environment.get("HOME") ~ "/.config";
    if (!exists(configDir))
    {
        mkdir (configDir);
    }

    immutable configFile = configDir ~ "/glxlibpath";

    string[] pathes;

    string[] recurseFindGLX(string path)
    {
        import std.traits : ReturnType;

        string[] locateds;

        ReturnType!dirEntries dirs;

        try
        {
            dirs = dirEntries(path, SpanMode.depth);

            foreach(DirEntry e; parallel(dirs, 1))
            {
                if(e.name.isDir)
                {
                    if(!pathes.canFind(e.name))
                    {
                        locateds ~= recurseFindGLX(e.name ~ "/");
                        pathes ~= e.name;
                    }
                }

                if(e.name.isFile)
                {
                    if (e.name.canFind("libglx.so") || e.name.canFind("libGLX.so"))
                    {
                        locateds ~= e.name;
                    }else
                    if (e.name.canFind("libGL.so"))
                    {
                        if (!e.name.canFind("libGL.so.1.7.0"))
                            locateds ~= e.name;
                    }
                }
            }
        } catch (Exception e)
        {
            return locateds;
        }

        return locateds;
    }

    string[] paths;

    if (exists(configFile))
    {
        paths ~= cast(string) read(configFile);
    } else
    {
        paths ~= recurseFindGLX("/usr/lib/") ~ glxDefaultPaths;

        version(X86_64)
        {
            paths ~= recurseFindGLX("/usr/lib/x86_64-linux-gnu/");
            paths ~= recurseFindGLX("/usr/lib64/");
            paths ~= recurseFindGLX("/opt/nvidia/lib/");
        }
        else
        version(X86)
        {
            paths ~= recurseFindGLX("/usr/lib/i386-linux-gnu/");
            paths ~= recurseFindGLX("/usr/lib32/");
            paths ~= recurseFindGLX("/opt/nvidia/lib32/");
        }
    }
    
    bool isSucces = false;
    bool ErrorFind = false;

    void bindOrError(void** ptr,string name) @trusted
    {
        bindSymbol(glxLib, ptr, name.toStringz);

        if(*ptr is null) throw new Exception("Not load library!");
    }

    string cachelib;

    foreach(path; paths)
    {
        if(path.exists)
        {
            glxLib = load(path.toStringz);
            if(glxLib == invalidHandle)
            {
                continue;
            }

            try
            {
                bindOrError(cast(void**) &glXQueryVersion, "glXQueryVersion");
                bindOrError(cast(void**) &glXChooseFBConfig, "glXChooseFBConfig");
                bindOrError(cast(void**) &glXGetVisualFromFBConfig, "glXGetVisualFromFBConfig");
                bindOrError(cast(void**) &glXGetFBConfigAttrib, "glXGetFBConfigAttrib");
                bindOrError(cast(void**) &glXQueryExtensionsString, "glXQueryExtensionsString");
                bindOrError(cast(void**) &glXCreateNewContext, "glXCreateNewContext");
                bindOrError(cast(void**) &glXMakeCurrent, "glXMakeCurrent");
                bindOrError(cast(void**) &glXDestroyContext, "glXDestroyContext");
                bindOrError(cast(void**) &glXSwapBuffers, "glXSwapBuffers");
                bindOrError(cast(void**) &glXWaitX, "glXWaitX");
                bindOrError(cast(void**) &glXChooseVisual, "glXChooseVisual");
                bindOrError(cast(void**) &glXCreateContext, "glXCreateContext");
                bindOrError(cast(void**) &glXIsDirect, "glXIsDirect");
                bindOrError(cast(void**) &glXGetProcAddress, "glXGetProcAddress");
                bindOrError(cast(void**) &glXCreateContextAttribsARB, "glXCreateContextAttribsARB");
                bindOrError(cast(void**) &glXGetClientString, "glXGetClientString");
                bindOrError(cast(void**) &glXGetFBConfigs, "glXGetFBConfigs");
                bindOrError(cast(void**) &glXCreateWindow, "glXCreateWindow");
                bindOrError(cast(void**) &glXDestroyWindow, "glXDestroyWindow");
                bindOrError(cast(void**) &glXCreatePixmap, "glXCreatePixmap");
                bindOrError(cast(void**) &glXCreateGLXPixmap, "glXCreateGLXPixmap");
                bindOrError(cast(void**) &glXMakeContextCurrent, "glXMakeContextCurrent");

                isSucces = true;
                cachelib = path;
            }catch(Exception e)
            {
                continue;
            }
            break;
        }
    }

    write (configFile, cachelib);

    if(!isSucces)
        throw new Exception("Library `glx` is not load!");
}
