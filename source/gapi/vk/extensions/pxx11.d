module gapi.vk.extensions.pxx11;

version(Posix):
version(BackendVk):
import gapi;
import gapi.vk;
import gapi.extensions.pxx11;
import x11.X;
import x11.Xlib;
import vk = erupted;
import erupted.platform_extensions;
mixin Platform_Extensions!(USE_PLATFORM_XLIB_KHR);

Surface vkCreateSurfaceFromWindow(Instance instance, PosixX11WindowInfo windowInfo) 
{
    VkInstance vinstance = cast(VkInstance) instance;
    VkSurface surface = make!(VkSurface)(vinstance.allocator);

    VkXlibSurfaceCreateInfoKHR cwi;
    cwi.dpy = windowInfo.dpy;
    cwi.window = *windowInfo.wnd;

    if (vkCreateXlibSurfaceKHR(
        vinstance.instance,
        &cwi,
        &vinstance.allocCallbacks,
        &surface.handle
    ) != vk.VkResult.VK_SUCCESS)
    {
        return null;
    }

    return surface;
}