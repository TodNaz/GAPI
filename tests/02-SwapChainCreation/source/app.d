module app;

import gapi;
import gapi.extensions.sdlsurface;

import bindbc.sdl;
import std.stdio;

int main(string[] args)
{
    Instance instance;
    createInstance(
        CreateInstanceInfo(
            ApplicationInfo(
                "01 - Device creation",
                0x01,
                "GAPI",
                0x00
            ),
            ["GAPISDLWindowInfo"]
        ),
        theAllocator(),
        instance
    );

    writeln ("02 - SwapChain Creation");

    writeln ("Find best device...");
    PhysDevice[] pdevices = instance.enumeratePhysicalDevices();
    Device bestDevice;

    size_t maxID, maxScore;

    foreach (i; 0 .. pdevices.length)
    {
        size_t score;
        auto e = pdevices[i];

        PhysDeviceProperties props = e.getProperties();
        score += props.features.geometryShader ? 1000 : 0;
        score += props.features.spirv ? 1000 : 0;
        score += props.features.scissor ? 1000 : 0;
        score += props.limits.maxTextureSize;
        score += props.limits.maxFramebufferLayers * 10;

        if (score > maxScore)
        {
            maxID = i;
            maxScore = score;
        }
    }

    writeln("Best device has find: ", pdevices[maxID].getProperties().deviceName);
    writeln("Create handle device...");

    QueueFamilyProperties[] vq = pdevices[maxID].getQueueFamilyProperties();
    QueueCreateInfo[] cq = new QueueCreateInfo[](vq.length);
    foreach (i; 0 .. vq.length)
    {
        cq[i] = QueueCreateInfo(
            cast(uint) i, vq[i].queueCount, 1.0f
        );
    }

    bestDevice = instance.createDevice(
        pdevices[maxID], DeviceCreateInfo(
            cq, []
        )
    );

    writeln("Device handle has created!");
    writeln("Create SDL window...");

    loadSDL();
    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window* window = SDL_CreateWindow(
        "Test", 0, 0, 640, 480, SDL_WINDOW_VULKAN
    ); //

    writeln("Create surface for window...");

    Surface surface = createSurfaceFromWindow(
        instance, SDL_WindowInfo(
            &window
        )
    );

    writeln("Create swapchain...");

    SwapChain swapChain = surface.createSwapChain(
        bestDevice, CreateSwapChainInfo(
            Format(8, 8, 8, 8, 24, 8, 4),
            PresentMode.fifo,
            [640, 480]
        )
    );

    writeln("SwapChain has created!");

    return 0;
}