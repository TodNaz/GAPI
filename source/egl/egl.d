module egl.egl;

version(Posix):
version(BackendGL):
import bindbc.loader;

alias EGLDisplay = void*;
alias EGLNativeDisplayType = void*;
alias EGLNativeWindowType = ulong; // X11 LAYOOUT

alias EGLConfig = void*;
alias EGLSurface = void*;
alias EGLContext = void*;

static immutable EGL_VENDOR = 0x3053;
static immutable EGL_MAX_PBUFFER_WIDTH = 0x302C;
static immutable EGL_MAX_PBUFFER_HEIGHT = 0x302A;
static immutable EGL_SURFACE_TYPE = 0x3033;
static immutable EGL_PBUFFER_BIT = 0x0001;	/* EGL_SURFACE_TYPE mask bits */
static immutable EGL_PIXMAP_BIT	= 0x0002;	/* EGL_SURFACE_TYPE mask bits */
static immutable EGL_WINDOW_BIT	= 0x0004;	/* EGL_SURFACE_TYPE mask bits */
static immutable EGL_BUFFER_SIZE = 0x3020;
static immutable EGL_ALPHA_SIZE = 0x3021;
static immutable EGL_BLUE_SIZE = 0x3022;
static immutable EGL_GREEN_SIZE = 0x3023;
static immutable EGL_RED_SIZE = 0x3024;
static immutable EGL_DEPTH_SIZE = 0x3025;
static immutable EGL_STENCIL_SIZE = 0x3026;
static immutable EGL_CONTEXT_CLIENT_VERSION = 0x3098;

alias FeglGetDisplay = extern(C) EGLDisplay function(EGLNativeDisplayType);
alias FeglInitialize = extern(C) bool function(EGLDisplay, int*, int*);
alias FeglQueryString = extern(C) const char* function(EGLDisplay, int);
alias FeglChooseConfig = extern(C) bool function(EGLDisplay, const int*, EGLConfig* config, int config_size, int* cl);
alias FeglGetConfigs = extern(C) bool function(EGLDisplay, EGLConfig* configs, int size, int* nums);
alias FeglGetConfigAttrib = extern(C) bool function(EGLDisplay, EGLConfig cfg, int attrib, int* value);
alias FeglCreateWindowSurface = extern(C) EGLSurface function(EGLDisplay, EGLConfig cfg, EGLNativeWindowType win, const int* attrib_list);
alias FeglCreateContext = extern(C) EGLContext function(EGLDisplay, EGLConfig cfg, EGLContext share, const int* attribs);
alias FeglDestroyContext = extern(C) bool function(EGLDisplay, EGLContext);
alias FeglMakeCurrent = extern(C) bool function (EGLDisplay dpy, EGLSurface draw, EGLSurface read, EGLContext ctx);
alias FeglDestroySurface = extern(C) bool function(EGLDisplay dpy, EGLSurface);

__gshared
{
    SharedLib egllib;

    FeglGetDisplay eglGetDisplay;
    FeglInitialize eglInitialize;
    FeglQueryString eglQueryString;
    FeglChooseConfig eglChooseConfig;
    FeglGetConfigs eglGetConfigs;
    FeglGetConfigAttrib eglGetConfigAttrib;
    FeglCreateWindowSurface eglCreateWindowSurface;
    FeglCreateContext eglCreateContext;
    FeglDestroyContext eglDestroyContext;
    FeglMakeCurrent eglMakeCurrent;
    FeglDestroySurface eglDestroySurface;
}

void loadEGL()
{
    auto paths = [
        "/opt/nvidia/lib/libEGL.so",
        "/usr/lib/libEGL.so"
    ];

    bool isSuccess = false;
    void bindOrError(void** ptr,string name) @trusted
    {
        import std.string : toStringz;
        bindSymbol(egllib, ptr, name.toStringz);

        if(*ptr is null) throw new Exception("Not load library!");
    }

    foreach (path; paths)
    {
        import std.string : toStringz;

        egllib = load(path.toStringz);
        if (egllib == invalidHandle)
            continue;

        bindOrError(cast(void**) &eglGetDisplay, "eglGetDisplay");
        bindOrError(cast(void**) &eglInitialize, "eglInitialize");
        bindOrError(cast(void**) &eglQueryString, "eglQueryString");
        bindOrError(cast(void**) &eglChooseConfig, "eglChooseConfig");
        bindOrError(cast(void**) &eglGetConfigs, "eglGetConfigs");
        bindOrError(cast(void**) &eglGetConfigAttrib, "eglGetConfigAttrib");
        bindOrError(cast(void**) &eglCreateWindowSurface, "eglCreateWindowSurface");
        bindOrError(cast(void**) &eglCreateContext, "eglCreateContext");
        bindOrError(cast(void**) &eglDestroyContext, "eglDestroyContext");
        bindOrError(cast(void**) &eglMakeCurrent, "eglMakeCurrent");
        bindOrError(cast(void**) &eglDestroySurface, "eglDestroySurface");

        isSuccess = true;
    }
}
