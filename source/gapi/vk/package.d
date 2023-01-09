module gapi.vk;

version(BackendVK):
import gapi;
import vk = erupted;

static this()
{
    import vlib = erupted.vulkan_lib_loader;
    if (!vlib.loadGlobalLevelFunctions())
    {
        throw new UnsupportException(UnsupportType.interfaceOutdated, 1);
    }

    createInstance = &vkCreateInstance;
    enumerateExtensions = &vkEnumerateExtensions;
}

PhysDeviceType __vkDeviceType(vk.VkPhysicalDeviceType type)
{
    switch (type)
    {
        case vk.VkPhysicalDeviceType.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU:
            return PhysDeviceType.integrate;

        case vk.VkPhysicalDeviceType.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU:
            return PhysDeviceType.discrete;

        case vk.VkPhysicalDeviceType.VK_PHYSICAL_DEVICE_TYPE_CPU:
            return PhysDeviceType.cpu;

        case vk.VkPhysicalDeviceType.VK_PHYSICAL_DEVICE_TYPE_OTHER:
            return PhysDeviceType.other;

        default:
            return PhysDeviceType.init;
    }
}

final class VkQueue : Queue
{
    public
    {
        RCIAllocator allocator;
        VkDevice device;
        QueueFlag flag;
        vk.VkQueue h;

        CommandPool[] pl;
        bool hasExecute = false;

        void submit(shared CommandPool pool) shared
        {
            pl ~= pool;
            hasExecute = false;
        }

        void handle(shared CommandPool pool) shared
        {
            import core.atomic;

            pl ~= pool;
            hasExecute = false;

            synchronized
            {
                VkDevice dev = cast(VkDevice) atomicLoad(device);
                //dev.handleQueues_modern(this);
            }
        }

        void wait() shared
        {
            while(!hasExecute)
            {

            }
        }

        void submit(CommandPool pool)
        {
            pl ~= pool;
            hasExecute = false;
        }

        void handle(CommandPool pool)
        {
            pl ~= pool;
            hasExecute = false;
            device.handleQueues();
            wait();
        }

        void wait()
        {
            while(!hasExecute)
            {

            }
        }
    }
}

final class VkBuffer : Buffer
{
    immutable(size_t) length() @safe
    {
        return 0;
    }
}

final class VkSwapChain : SwapChain
{
    public
    {
        vk.VkSwapchainKHR handle;
    }
}

final class VkSurface : Surface
{
    public
    {
        vk.VkSurfaceKHR handle;
    }

    /++
    Выдаёт доступные форматы поверхности.
    +/
    SurfaceFormat[] getFormats()
    {
        return [];
    }

    /++
    Создаёт цепочку кадров для девайса.

    Params:
        device      =   Девайс, которому нужно создать цепочку
                        кадров для отправки в окно программы.
        createInfo  =   Информация о создании цепочки кадров.
    +/
    SwapChain createSwapChain(Device device, CreateSwapChainInfo createInfo)
    {
        return null;
    }
}

final class VkDevice : Device
{
    public
    {
        vk.VkDevice handle;
        VkPhysDevice physDevice;
        RCIAllocator allocator;
        VkQueue[] queues;
    }

    this(VkPhysDevice physDevice, DeviceCreateInfo createInfo, RCIAllocator allocator)
    {
        this.physDevice = physDevice;
        this.allocator = allocator;

        vk.VkDeviceQueueCreateInfo[] qci = makeArray!(vk.VkDeviceQueueCreateInfo)(
            allocator, createInfo.queueCreateInfos.length
        );
        queues = makeArray!(VkQueue)(allocator, createInfo.queueCreateInfos.length);

        foreach (size_t i, ref e; createInfo.queueCreateInfos)
        {
            qci[i].queueCount = createInfo.queueCreateInfos[i].queueCount;
            qci[i].pQueuePriorities = &createInfo.queueCreateInfos[i].priority;
            qci[i].queueFamilyIndex = createInfo.queueCreateInfos[i].queueIndex;

            auto q = make!(VkQueue)(allocator);
            q.allocator = allocator;
            q.device = this;
            q.flag = QueueFlag.init;
            queues[i] = q;
        }

        vk.VkPhysicalDeviceFeatures pfeatures;
        vk.vkGetPhysicalDeviceFeatures(
            physDevice.handle,
            &pfeatures
        );

        uint ecount;
        vk.vkEnumerateDeviceExtensionProperties(
            physDevice.handle,
            null,
            &ecount,
            null
        );
        vk.VkExtensionProperties[] exts = makeArray!(vk.VkExtensionProperties)(allocator, ecount);
        vk.vkEnumerateDeviceExtensionProperties(
            physDevice.handle,
            null,
            &ecount,
            exts.ptr
        );

        static string cstr(char[256] value)
        {
            size_t i = 0;
            while (value[++i] != '\0') {}

            return cast(string) (value.dup[0 .. i]);
        }

        string extList;
        foreach (e; exts)
        {
            extList ~= cstr(e.extensionName) ~ '\0';
        }

        char* ptr = cast(char*) extList.ptr;

        vk.VkDeviceCreateInfo devInfo;
        devInfo.queueCreateInfoCount = cast(uint) qci.length;
        devInfo.pQueueCreateInfos = qci.ptr;
        devInfo.pEnabledFeatures = &pfeatures;
        devInfo.ppEnabledExtensionNames = &ptr;
        devInfo.enabledExtensionCount = ecount;
        devInfo.enabledLayerCount = 0;

        vk.VkResult rs;
        if ((rs = vk.vkCreateDevice(
            physDevice.handle,
            &devInfo,
            /+&physDevice.instance.allocCallbacks+/ null,
            &handle
        )) != vk.VkResult.VK_SUCCESS)
        {
            throw new UnsupportException(
                UnsupportType.interfaceBroken,
                cast(uint) rs
            );
        }

        foreach (size_t i, ref e; queues)
        {
            vk.vkGetDeviceQueue(
                handle, cast(uint) i, 0, &e.h
            );
        }

        dispose(allocator, qci);
    }

    /++
    Функция получения очередей, куда нужно высылать команды.
    +/
    Queue[] getQueues()
    {
        Queue[] dq = makeArray!(Queue)(allocator, queues.length);
        foreach (size_t i, ref e; dq)
        {
            e = queues[i];
        }

        return dq;
    }

    void globalError(
            string message,
            shared Command command
        )
        {
            debug
            {
                throw new Exception(message, command.file, command.line);
            } else
            {
                throw new Exception(message);
            }
        }

        void globalError(
            shared Command command
        )
        {
            globalError("ATAAS!", command);
        }

        void handleError(
            shared Command command,
            string message
        )
        {
            version(IgnoreErrors)
            {
                return;
            }
            else
            {
                debug
                {
                    throw new Exception(message, command.file, command.line);
                } else
                {
                    throw new Exception(message);
                }
            }
        }

    /++
    Функция обработки всех очередей.
    +/
    void handleQueues()
    {
        foreach (ref e; queues)
        continue;
    }

    void handleQueue(ref VkQueue queue)
    {
        foreach (ref pl; queue.pl)
        {
            handlePool(pl);
        }
    }

    void handlePool(ref CommandPool pool)
    {
        if (pool.commands.length == 0)
            return;

        foreach (e; pool.commands)
        {
            switch (e.type)
            {
                case CommandType.createBuffer:
                {

                }
                break;

                default:
                break;
            }
        }

        if (pool.semaphore !is null)
            pool.semaphore.notify();
    }
}

final class VkPhysDevice : PhysDevice
{
    public
    {
        VkInstance instance;
        RCIAllocator allocator;
        vk.VkPhysicalDevice handle;
    }

    this(VkInstance instance, vk.VkPhysicalDevice dev, RCIAllocator allocator)
    {
        this.instance = instance;
        this.handle = dev;
        this.allocator = allocator;
    }

    /// Функция получений характеристик, лимитов и прочей информации о
    /// физическом устройстве.
    PhysDeviceProperties getProperties()
    {
        import std.conv : to;

        PhysDeviceProperties properties;

        vk.VkPhysicalDeviceFeatures feature;
        vk.VkPhysicalDeviceProperties vprop;
        vk.vkGetPhysicalDeviceFeatures(handle, &feature);
        vk.vkGetPhysicalDeviceProperties(handle, &vprop);

        properties.features = PhysDeviceFeatures(
            true,
            cast(bool) feature.geometryShader,
            cast(bool) feature.tessellationShader,
            cast(bool) feature.multiDrawIndirect,
            cast(bool) feature.multiViewport,
            feature.textureCompressionBC || feature.textureCompressionASTC_LDR || feature.textureCompressionETC2,
            false, false,
            cast(bool) feature.shaderInt64,
            cast(bool) feature.shaderFloat64,
            cast(bool) feature.shaderClipDistance,
            cast(bool) feature.shaderCullDistance,
            true,
            true
        );

        properties.deviceName = vprop.deviceName.to!string;
        properties.deviceID = vprop.deviceID;
        properties.driverVersion = vprop.driverVersion.to!string;
        properties.avalibleForCreation = true;
        properties.type = __vkDeviceType(vprop.deviceType);

        properties.limits = PhysDeviceLimits(
            vprop.limits.maxImageDimension2D,
            vprop.limits.maxFramebufferWidth,
            vprop.limits.maxFramebufferHeight,
            vprop.limits.maxFramebufferLayers,
            vprop.limits.maxVertexInputAttributes,
            vprop.limits.maxVertexOutputComponents,
            vprop.limits.maxVertexInputBindings,
            vprop.limits.maxGeometryInputComponents,
            cast(uint) vprop.limits.maxGeometryOutputComponents,
            vprop.limits.maxFragmentInputComponents,
            vprop.limits.maxFragmentOutputAttachments,
            vprop.limits.maxVertexInputBindings,
            vprop.limits.maxDescriptorSetSamplers,
            vprop.limits.maxComputeSharedMemorySize,
            vprop.limits.maxComputeWorkGroupCount,
            vprop.limits.maxComputeWorkGroupInvocations,
            vprop.limits.maxComputeWorkGroupSize,
            vprop.limits.subPixelPrecisionBits,
            vprop.limits.maxViewports
        );

        return properties;
    }

    string[] extensions()
    {
        string[] result;

        uint count;
        vk.VkExtensionProperties[] exts;
        vk.vkEnumerateDeviceExtensionProperties(handle, null, &count, null);
        exts = makeArray!(vk.VkExtensionProperties)(allocator, count);
        vk.vkEnumerateDeviceExtensionProperties(handle, null, &count, exts.ptr);

        static string cstr(char[256] value)
        {
            size_t i = 0;
            while (value[++i] != '\0') {}

            return cast(string) (value.dup[0 .. i]);
        }

        foreach (e; exts)
        {
            switch (cstr(e.extensionName))
            {
                case "VK_EXT_multi_draw":
                    result ~= ["GAPIMultiDraw"];
                break;

                default:break;
            }
        }

        return result;
    }

    /// Функция выдаёт доступные под создание очереди.
    QueueFamilyProperties[] getQueueFamilyProperties()
    {
        uint count;
        vk.VkQueueFamilyProperties[] qprops;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(
            handle, &count, null
        );

        qprops = makeArray!(vk.VkQueueFamilyProperties)(
            allocator, count
        );
        vk.vkGetPhysicalDeviceQueueFamilyProperties(
            handle, &count, qprops.ptr
        );

        QueueFamilyProperties[] properties = makeArray!(QueueFamilyProperties)(
            allocator, count
        );

        foreach (i; 0 .. count)
        {
            QueueFamilyProperties prop;
            if ((qprops[i].queueFlags & vk.VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT))
            {
                prop.queueFlags |= QueueFlag.graphicsBit;
            }
            if ((qprops[i].queueFlags & vk.VkQueueFlagBits.VK_QUEUE_COMPUTE_BIT))
            {
                prop.queueFlags |= QueueFlag.computeBit;
            }
            if ((qprops[i].queueFlags & vk.VkQueueFlagBits.VK_QUEUE_TRANSFER_BIT))
            {
                prop.queueFlags |= QueueFlag.transferBit;
            }

            prop.queueCount = qprops[i].queueCount;

            properties[i] = prop;
        }

        return properties;
    }
}

final class VkInstance : Instance
{
    public
    {
        vk.VkInstance instance;
        RCIAllocator allocator;
        vk.VkAllocationCallbacks allocCallbacks;
    }

    /// Получить доступные расширения.
    string[] getExtensions()
    {
        string[] extensions;

        uint count;
        vk.vkEnumerateInstanceExtensionProperties(
            null, &count, null
        );

        vk.VkExtensionProperties[] vexts = makeArray!(vk.VkExtensionProperties)(
            allocator, count
        );

        vk.vkEnumerateInstanceExtensionProperties(
            null, &count, vexts.ptr
        );

        static string cstr(char[256] value)
        {
            size_t i = 0;
            while (value[++i] != '\0') {}

            return cast(string) (value.dup[0 .. i]);
        }

        foreach (e; vexts)
        {
            switch (cstr(e.extensionName))
            {
                case "VK_KHR_xlib_surface":
                    extensions ~= "GAPIPosixX11WindowInfo";
                break;

                case "VK_KHR_xcb_surface":
                    extensions ~= "GAPIPosixXCBWindowInfo";
                break;

                case "VK_KHR_wayland_surface":
                    extensions ~= "GAPIPosiWaylandWindowInfo";
                break;

                default: break;
            }
        }

        return extensions;
    }

    void handleExtensions(immutable string[] extensions)
    {
        foreach (e; extensions)
        {
            switch (e)
            {
                case "GAPISDLWindowInfo":
                {
                    import gapi.extensions.sdlsurface;
                    import gapi.vk.extensions.sdlsurface;

                    createSurfaceFromWindow = &VkCreateSurfaceFromWindow;
                }
                break;

                default: break;
            }
        }
    }

    /// Получить доступные физические устройства.
    PhysDevice[] enumeratePhysicalDevices()
    {
        vk.loadInstanceLevelFunctions(instance);

        uint count;
        vk.VkResult res;
        if ((res = vk.vkEnumeratePhysicalDevices(instance, &count, null)) != vk.VkResult.VK_SUCCESS)
        {
            throw new UnsupportException(UnsupportType.interfaceBroken, cast(uint) res);
        }

        PhysDevice[] pdevices = makeArray!(PhysDevice)(allocator, count);
        vk.VkPhysicalDevice[] vpdevices = makeArray!(vk.VkPhysicalDevice)(allocator, count);

        if ((res = vk.vkEnumeratePhysicalDevices(instance, &count, vpdevices.ptr)) != vk.VkResult.VK_SUCCESS)
        {
            throw new UnsupportException(UnsupportType.interfaceBroken, cast(uint) res);
        }

        foreach (i; 0 .. vpdevices.length)
        {
            pdevices[i] = make!(VkPhysDevice)(allocator, this, vpdevices[i], allocator);
        }

        return pdevices;
    }

    /// Получить дескриптор устройства из дескриптора информации устройства.
    ///
    /// Params:
    ///     pdevice = Физическое устройство.
    ///     createInfo = Информация о создании дескриптора устройства.
    Device createDevice(PhysDevice pdevice, DeviceCreateInfo createInfo)
    {
        VkPhysDevice vpdevice = cast(VkPhysDevice) pdevice;
        if (vpdevice is null)
        {
            // err
            return null;
        }

        VkDevice hdevice = make!(VkDevice)(allocator, vpdevice, createInfo, allocator);
        return hdevice;
    }

    /// Получить доступные слои валидации ошибок и данных.
    ValidationLayer[] enumerateValidationLayers()
    {
        return [];
    }
}

vk.VkApplicationInfo __tappconv(immutable ApplicationInfo appInfo)
{
    auto vkAppInfo = vk.VkApplicationInfo(
        vk.VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        null,
        appInfo.applicationName.ptr,
        appInfo.applicationVersion,
        appInfo.engineName.ptr,
        appInfo.engineVersion,
        vk.VK_API_VERSION_1_0
    );

    return vkAppInfo;
}

extern(C) void* __vkAlloc(
    void*                       pUserData,
    size_t                      size,
    size_t                      alignment,
    vk.VkSystemAllocationScope  allocationScope
)
{
    import std.exception;

    RCIAllocator* allocator = (cast(RCIAllocator*) pUserData);
    if (allocator.isNull())
    {
        return null;
    }

    void[] data = allocator.allocate(size);
    if (data.length == 0)
    {
        throw new ErrnoException("Error aligned allocate with __vkAlloc", 12);
    }

    return data.ptr;
}

extern(C) void __vkFree(
    void*                       pUserData,
    void*                       pMemory
) nothrow
{
    RCIAllocator* allocator = (cast(RCIAllocator*) pUserData);
    if (allocator.isNull())
    {
        return;
    }

    void[] gdf;
    allocator.resolveInternalPointer(pMemory, gdf);
    allocator.deallocate(gdf);
}

extern(C) void* __vkReallocation(
    void*                       pUserData,
    void*                       pOriginal,
    size_t                      size,
    size_t                      alignment,
    vk.VkSystemAllocationScope  allocationScope
) nothrow
{
    RCIAllocator* allocator = cast(RCIAllocator*) pUserData;
    if (allocator.isNull())
    {
        return null;
    }

    void[] gdf;
    allocator.resolveInternalPointer(pOriginal, gdf);
    allocator.alignedReallocate(gdf, size, cast(uint) alignment);

    return gdf.ptr;
}

__gshared
{
    string[string] vkGAPIExtensions;
}

string[] vkEnumerateExtensions(
    RCIAllocator allocator
)
{
    uint ecount;
    vk.vkEnumerateInstanceExtensionProperties(null, &ecount, null);
    vk.VkExtensionProperties[] eprops = makeArray!(vk.VkExtensionProperties)(allocator, ecount);
    vk.vkEnumerateInstanceExtensionProperties(null, &ecount, eprops.ptr);

    static string cstr(char[256] value)
    {
        size_t i = 0;
        while (value[++i] != '\0') {}

        return cast(string) (value.dup[0 .. i]);
    }

    string[] extensions;
    foreach (e; eprops)
    {
        switch (cstr(e.extensionName))
        {
            case "VK_KHR_wayland_surface":
                extensions ~= "GAPIPosixWaylandWindowInfo";
            break;

            case "VK_KHR_xcb_surface":
                extensions ~= "GAPIPosixXCBWindowInfo";
            break;

            case "VK_KHR_xlib_surface":
                extensions ~= "GAPIPosixX11WindowInfo";
            break;

            default:break;
        }
    }

    return extensions;
}

void vkCreateInstance(
    immutable CreateInstanceInfo createInfo,
    RCIAllocator allocator,
    ref Instance instance
)
{
    import std.process : environment;

    auto vkAppInfo = __tappconv(createInfo.applicationInfo);

    string sdlExtSurf;
    switch (environment.get("XDG_SESSION_TYPE"))
    {
        case "x11":
        {
            sdlExtSurf = "VK_KHR_xlib_surface";
        }
        break;

        case "waylad":
        {
            sdlExtSurf = "VK_KHR_wayland_surface";
        }
        break;

        default: break;
    }

    vkGAPIExtensions = [
        "GAPIPosixX11WindowInfo" : "VK_KHR_xlib_surface",
        "GAPIPosixXCBWindowInfo" : "VK_KHR_xcb_surface",
        "GAPIPosixWaylandWindowInfo" : "VK_KHR_wayland_surface",
        "GAPISDLWindowInfo" : sdlExtSurf
    ];

    string enabledExtensions;

    uint cc;
    foreach (size_t i, e; createInfo.extensions)
    {
        if (string* ext = e in vkGAPIExtensions)
        {
            cc++;
            enabledExtensions ~= *ext ~ '\0';
        }
    }

    char* exts;

    if (enabledExtensions.length != 0)
        exts = cast(char*) enabledExtensions.ptr;

    VkInstance vinstance = make!(VkInstance)(allocator);
    vk.VkInstanceCreateInfo ici;
    ici.pApplicationInfo = &vkAppInfo;
    ici.enabledLayerCount = 0;
    ici.enabledExtensionCount = cc;
    ici.ppEnabledExtensionNames = &exts;

    //TODO: implement custom allocation
    vk.VkAllocationCallbacks allocCallback;
    allocCallback.pfnAllocation = cast(vk.PFN_vkAllocationFunction) &__vkAlloc;
    allocCallback.pfnFree = cast(vk.PFN_vkFreeFunction) &__vkFree;
    allocCallback.pfnReallocation = cast(vk.PFN_vkReallocationFunction) &__vkReallocation;
    allocCallback.pUserData = &allocator;

    vk.VkResult result;
                                            /+
                                                Пока-что не знаю,
                                                как правильно оформить под
                                                дишный аллокатор.
                                            +/
    if ((result = vk.vkCreateInstance(&ici, /+&allocCallback+/ null, &vinstance.instance)) != vk.VkResult.VK_SUCCESS)
    {
        import std.stdio;
        stderr.writeln(result);
        throw new UnsupportException(UnsupportType.interfaceOutdated, cast(uint) result);
    }
    vinstance.allocator = allocator;
    vinstance.allocCallbacks = allocCallback;
    vinstance.handleExtensions(createInfo.extensions);

    vk.loadDeviceLevelFunctions(vinstance.instance);

    instance = vinstance;
}
