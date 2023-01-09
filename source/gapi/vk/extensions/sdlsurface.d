module gapi.vk.extensions.sdlsurface;

version(BackendVK):
import gapi;
import gapi.vk : VkSurface, VkInstance;
import gapi.extensions.sdlsurface;
import bindbc.sdl;

Surface VkCreateSurfaceFromWindow(Instance instance, SDL_WindowInfo windowInfo)
{
    VkInstance vinstance = cast(VkInstance) instance;
    VkSurface surface = make!(VkSurface)(vinstance.allocator);
    if (!SDL_Vulkan_CreateSurface(
        *windowInfo.window, 
        cast(void*) vinstance.instance,
        cast(void*) &surface.handle
    ))
    {
        import std.stdio;
        import std.conv : to;
        writeln (SDL_GetError().to!string);
        throw new UnsupportException(UnsupportType.interfaceBroken, 0);
    }

    return surface;
}