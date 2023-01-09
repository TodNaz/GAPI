module gapi.gl.extensions.win32wi;

version(Windows):
version(BackendGL):
import core.sys.windows.windows;
import gapi;
import gapi.extensions.win32wi;
import wgl.wgl;

final class GLWin32Surface : Surface
{
    private
    {
        HMODULE hInstance;
        HWND wnd;

        void win32Init(CreateSurfaceInfo createInfo) @trusted
        {
            if (!IsWindow(*createInfo.windowInfo.wnd))
            {
                throw new InvalidWindow(createInfo);
            }

            auto info = __gapi_init_wgl();

            uint nums = 0;
            wglGetPixelFormatAttribivARB(
                info.dc,
                0,
                0,
                1,
                [WGL_NUMBER_PIXEL_FORMATS_ARB].ptr,
                cast(int*) &nums
            );

            formats = makeArray!(SurfaceFormat)(allocator, nums);
            foreach (i; 1 .. nums)
            {
                Format format;
                wglGetPixelFormatAttribivARB(
                    info.dc,
                    i,
                    0,
                    6,
                    [
                        WGL_RED_BITS_ARB,
                        WGL_GREEN_BITS_ARB,
                        WGL_BLUE_BITS_ARB,
                        WGL_ALPHA_BITS_ARB,
                        WGL_DEPTH_BITS_ARB,
                        WGL_STENCIL_BITS_ARB,
                    ].ptr,
                    cast(int*) &format
                );

                PresentMode mode;
                uint md;
                wglGetPixelFormatAttribivARB(
                    info.dc,
                    i,
                    0,
                    1,
                    [
                        WGL_DOUBLE_BUFFER_ARB
                    ].ptr,
                    cast(int*) &md
                );
                mode = md == 1 ? PresentMode.fifo : PresentMode.immediate;

                formats[i - 1] = SurfaceFormat(format, mode);
            }

            __gapi_dst_twnd(info);

            this.hInstance = createInfo.windowInfo.hInstance;
            this.wnd = *createInfo.windowInfo.wnd;
        }
    }

    public
    {
        
        RCIAllocator allocator;
        SurfaceFormat[] formats;
    }

    public
    {
        this(Win32WindowInfo createInfo, RCIAllocator allocator)
        {
            this.allocator = allocator;
 
            win32Init(createInfo);
        }

        SurfaceFormat[] getFormats()
        {
            return this.formats;
        }

        SwapChain createSwapChain(Device device, CreateSwapChainInfo createInfo)
        {
            GLDevice gdevice = cast(GLDevice) device;

            GLSwapChain sc = make!(GLWin32SwapChain)(allocator, this, gdevice, createInfo, allocator);

            return sc;
        }

        ~this()
        {
            dispose(allocator, formats);
        }
    }
}

Surface createSurface(CreateSurfaceInfo createInfo)
{
    GLSurface gsurface = make!(GLSurface)(allocator, createInfo, allocator);

    return gsurface;
}

final class GLWin32SwapChain : SwapChain
{
    private
    {
        HMODULE hInstance;
        HDC dc;
    }

    public
    {
        RCIAllocator allocator;

        uint[2] extend;
    }

    public
    {
        this(
            GLWin32 surface,
            GLDevice gdevice,
            CreateSwapChainInfo createInfo,
            RCIAllocator allocator
        )
        {
            hInstance = surface.hInstance;

            auto deviceHandle = GetDC(surface.wnd);

            immutable colorBits =   createInfo.format.redSize + 
                                    createInfo.format.greenSize +
                                    createInfo.format.blueSize +
                                    createInfo.format.alphaSize;

            immutable pfdFlags = createInfo.presentMode == PresentMode.immediate ?
                (PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL) :
                (PFD_DOUBLEBUFFER | PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL);

            PIXELFORMATDESCRIPTOR pfd;
            pfd.nSize = PIXELFORMATDESCRIPTOR.sizeof;
            pfd.nVersion = 1;
            pfd.dwFlags = pfdFlags;
            pfd.iPixelType = PFD_TYPE_RGBA;
            pfd.cRedBits = cast(ubyte) createInfo.format.redSize;
            pfd.cGreenBits = cast(ubyte) createInfo.format.greenSize;
            pfd.cBlueBits = cast(ubyte) createInfo.format.blueSize;
            pfd.cAlphaBits = cast(ubyte) createInfo.format.alphaSize;
            pfd.cDepthBits = cast(ubyte) createInfo.format.depthSize;
            pfd.cStencilBits = cast(ubyte) createInfo.format.stencilSize;
            pfd.cColorBits = cast(ubyte) colorBits;
            pfd.iLayerType = PFD_MAIN_PLANE;

            auto chsPixel = ChoosePixelFormat(deviceHandle, &pfd);
            if (chsPixel == 0)
            {
                import std.conv : to;
                LPSTR messageBuffer = null;

                size_t size = FormatMessageA(
                    FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                    null, 
                    cast(uint) GetLastError(), 
                    MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US), 
                    cast(LPSTR) &messageBuffer, 
                    0, 
                    null
                );
                throw new UnsupportException(messageBuffer.to!string);
            }

            if (!SetPixelFormat(deviceHandle, chsPixel, &pfd))
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            auto ctx = wglCreateContext(deviceHandle);
            if (!wglMakeCurrent(deviceHandle, ctx))
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            initWGL();

            int[] iattrib =  
            [
                WGL_SUPPORT_OPENGL_ARB, true,
                WGL_DRAW_TO_WINDOW_ARB, true,
                WGL_DOUBLE_BUFFER_ARB, createInfo.presentMode == PresentMode.immediate ? false : true,
                WGL_RED_BITS_ARB, createInfo.format.redSize,
                WGL_GREEN_BITS_ARB, createInfo.format.greenSize,
                WGL_BLUE_BITS_ARB, createInfo.format.blueSize,
                WGL_ALPHA_BITS_ARB, createInfo.format.alphaSize,
                WGL_DEPTH_BITS_ARB, createInfo.format.depthSize,
                WGL_COLOR_BITS_ARB, colorBits,
                WGL_STENCIL_BITS_ARB, createInfo.format.stencilSize,
                WGL_PIXEL_TYPE_ARB, WGL_TYPE_RGBA_ARB,
                0
            ];

            uint nNumFormats;
            int[20] nPixelFormat;
            wglChoosePixelFormatARB(
                deviceHandle,   
                iattrib.ptr, 
                null,
                20, nPixelFormat.ptr,
                &nNumFormats
            );

            bool isSuccess = false;
            foreach (i; 0 .. nNumFormats)
            {
                DescribePixelFormat(deviceHandle, nPixelFormat[i], pfd.sizeof, &pfd);
                if (SetPixelFormat(deviceHandle, nPixelFormat[i], &pfd) == true)
                {
                    isSuccess = true;
                    break;
                }
            }

            if (!isSuccess)
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            // Use deprecated functional
            int[] attrib =  
            [
                WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                WGL_CONTEXT_MINOR_VERSION_ARB, 5,
                WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                0
            ];

            auto mctx = wglCreateContextAttribsARB(     deviceHandle, 
                                                        null, 
                                                        attrib.ptr);
            if (mctx is null)
            {
                attrib =  
                [
                    WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
                    WGL_CONTEXT_MINOR_VERSION_ARB, 3,
                    WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                    WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                    0
                ];

                mctx = wglCreateContextAttribsARB(      deviceHandle, 
                                                        null, 
                                                        attrib.ptr);

                if (mctx is null)
                {
                    throw new UnsupportException(UnsupportType.interfaceOutdated);
                }
            }

            wglMakeCurrent(null, null);
            wglDeleteContext(ctx);

            if (!wglMakeCurrent(deviceHandle, mctx))
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            if (loadOpenGL() < GLSupport.gl42)
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            this.dc = deviceHandle;
        }

        void swapBuffers(shared CmdPresentInfo info)
        {
            SwapBuffers(dc);
        }
    }
}