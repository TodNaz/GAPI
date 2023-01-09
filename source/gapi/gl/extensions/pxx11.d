module gapi.gl.extensions.pxx11;

version(Posix):
version(BackendGL):

import x11.X;
import x11.Xlib;
import x11.Xutil;
import bindbc.opengl;
import dglx.glx;

import gapi.extensions.pxx11;
import gapi;
import gapi.gl : GLDevice, GLInstance;

class GLPosixX11Surface : Surface
{
    private
    {
        Display* dpy;
        Window* drawable;
        GLXContext context;

        void posixInit(PosixX11WindowInfo createInfo) @trusted
        {
            this.dpy = cast(Display*) createInfo.dpy;
            this.drawable = createInfo.wnd;

            int fbclen;
            GLXFBConfig* fbcs = glXGetFBConfigs(dpy, 0, &fbclen);
            scope(exit) XFree(fbcs);

            formats = makeArray!(SurfaceFormat)(allocator, fbclen);

            foreach (i; 0 .. fbclen)
            {
                auto fbc = fbcs[i];

                Format fmt;
                glXGetFBConfigAttrib(dpy, fbc, GLX_RED_SIZE, cast(int*) &fmt.redSize);
                glXGetFBConfigAttrib(dpy, fbc, GLX_GREEN_SIZE, cast(int*) &fmt.greenSize);
                glXGetFBConfigAttrib(dpy, fbc, GLX_BLUE_SIZE, cast(int*) &fmt.blueSize);
                glXGetFBConfigAttrib(dpy, fbc, GLX_ALPHA_SIZE, cast(int*) &fmt.alphaSize);
                glXGetFBConfigAttrib(dpy, fbc, GLX_DEPTH_SIZE, cast(int*) &fmt.depthSize);
                glXGetFBConfigAttrib(dpy, fbc, GLX_STENCIL_SIZE, cast(int*) &fmt.stencilSize);

                PresentMode pmode;
                int bmode;
                glXGetFBConfigAttrib(dpy, fbc, GLX_DOUBLEBUFFER, &bmode);

                if (bmode)
                    pmode = PresentMode.fifo;
                else
                    pmode = PresentMode.immediate;

                formats[i] = SurfaceFormat(fmt, pmode);
            }
        }

    }

    public
    {
        RCIAllocator allocator;
        SurfaceFormat[] formats;
    }

    public
    {
        this(PosixX11WindowInfo createInfo, RCIAllocator allocator)
        {
            this.allocator = allocator;
            posixInit(createInfo);
        }

        SurfaceFormat[] getFormats()
        {
            return this.formats;
        }

        SwapChain createSwapChain(Device device, CreateSwapChainInfo createInfo)
        {
            //GLDevice gdevice = cast(GLDevice) device;

            GLPosixX11SwapChain sc = make!(GLPosixX11SwapChain)(allocator, dpy, this, createInfo, allocator);

            return sc;
        }
        
        ~this()
        {
            dispose(allocator, formats);
        }
    }
}

final class GLPosixX11SwapChain : SwapChain
{
    private
    {
        Display* dpy;
        GLXPixmap gpixmap;
        Pixmap pixmap;
        GLXContext context;
        GC gc;
        Window* wnd;
    }

    public
    {
        RCIAllocator allocator;

        uint[2] extend;
    }

    public
    {
        this(
            Display* dpy,
            GLPosixX11Surface surface,
            CreateSwapChainInfo createInfo,
            RCIAllocator allocator
        )
        {
            this.dpy = dpy;
            this.wnd = surface.drawable;
            this.allocator = allocator;

            int fbcount = 0;
            scope fbc = glXGetFBConfigs(dpy, 0, &fbcount); scope(exit) XFree(fbc);

            if (fbcount == 0)
            {
                throw new Exception("Your system not enought fb configs");
            }

            GLXFBConfig cfg;

            foreach (i; 0 .. fbcount)
            {
                int drw,
                    rdtype,
                    vstype,
                    rs, gs, bs, as,
                    ds, ss,
                    db,
                    sp;
                int pix;

                glXGetFBConfigAttrib(dpy, fbc[i], GLX_DRAWABLE_TYPE, &drw);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_RENDER_TYPE, &rdtype);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_X_VISUAL_TYPE, &rdtype);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_RED_SIZE, &rs);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_GREEN_SIZE, &gs);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_BLUE_SIZE, &bs);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_ALPHA_SIZE, &as);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_DEPTH_SIZE, &ds);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_STENCIL_SIZE, &ss);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_DOUBLEBUFFER, &db);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_SAMPLES, &sp);

                if ((drw & GLX_PIXMAP_BIT) != 0 &&
                    (rdtype & GLX_RGBA_BIT) == GLX_RGBA_BIT &&
                    rs == createInfo.format.redSize &&
                    gs == createInfo.format.greenSize &&
                    bs == createInfo.format.blueSize &&
                    as == createInfo.format.alphaSize &&
                    ds == createInfo.format.depthSize &&
                    ss == createInfo.format.stencilSize &&
                    db == (createInfo.presentMode != PresentMode.immediate)
                    )
                {
                    cfg = fbc[i];
                    break;
                }
            }

            if (cfg is null)
                throw new Exception("Not absolute config!");

            XVisualInfo* vinfo = glXGetVisualFromFBConfig(dpy, cfg);

            int[5] ctxAttrib = [
                GLX_CONTEXT_MAJOR_VERSION_ARB, 4,
                GLX_CONTEXT_MINOR_VERSION_ARB, 2,
                None
            ];

            context = glXCreateContextAttribsARB(
                dpy,
                cfg,
                null,
                true,
                ctxAttrib.ptr
            );

            XWindowAttributes wattribs;
            XGetWindowAttributes(dpy, *wnd, &wattribs);

            XSetWindowAttributes windowAttribs;
            windowAttribs.border_pixel = 0x000000;
            windowAttribs.background_pixel = 0xFFFFFF;
            windowAttribs.override_redirect = wattribs.override_redirect;
            windowAttribs.colormap = XCreateColormap(dpy, RootWindow(dpy, 0),
                                                     vinfo.visual, AllocNone);
            windowAttribs.event_mask = wattribs.your_event_mask;

            *wnd = XCreateWindow (
                dpy, RootWindow(dpy, 0),
                wattribs.x, wattribs.y,
                wattribs.width, wattribs.height,
                0,
                vinfo.depth,
                InputOutput,
                vinfo.visual,
                CWBackPixel | CWColormap | CWBorderPixel | CWEventMask,
                &windowAttribs
            );
            XMapWindow(dpy, *wnd);

            glXMakeContextCurrent(
                dpy,
                *wnd,
                *wnd,
                context
            );

            if (loadOpenGL() < GLSupport.gl42)
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }
        }

        void swapBuffers(shared CmdPresentInfo info)
        {
            glXSwapBuffers(dpy, *wnd);
        }
    }
}