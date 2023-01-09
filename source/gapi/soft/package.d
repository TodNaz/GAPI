module gapi.soft;

version(BackendSF):
import gapi;

static this()
{
    createInstance = &sfCreateInstance;
}

final class SfPhysDevice : PhysDevice
{
    import core.cpuid;

    public
    {
        RCIAllocator allocator;
    }

    this(RCIAllocator allocator)
    {
        this.allocator = allocator;
    }

    /// Функция получений характеристик, лимитов и прочей информации о
    /// физическом устройстве.
    PhysDeviceProperties getProperties()
    {
        immutable tpc = threadsPerCPU();
        immutable mcw = cast(uint[3]) [tpc, tpc, tpc];
        return PhysDeviceProperties(
            false,
            "0.1.3",
            "GAPI Software device",
            0x001,
            "GAPI",
            PhysDeviceType.nativeCPU,
            PhysDeviceLimits(
                4024,
                4024,
                4024,
                1024,
                16,
                16,
                32,
                8,
                8,
                16,
                4,
                32,
                4,
                1024,
                mcw,
                0,
                mcw,
                4,
                1
            ),
            PhysDeviceFeatures(
                true,
                false,
                false,
                true,
                true,
                false,
                false,
                false,
                true,
                true,
                false,
                false,
                true,
                false
            )
        );
    }

    string[] extensions()
    {
        return [];
    }

    /// Функция выдаёт доступные под создание очереди.
    QueueFamilyProperties[] getQueueFamilyProperties()
    {
        return [
            QueueFamilyProperties(QueueFlag.graphicsBit, threadsPerCPU()),
            QueueFamilyProperties(QueueFlag.computeBit, threadsPerCPU()),
            QueueFamilyProperties(QueueFlag.presentBit, 1)
        ];
    }
}

final class SfInstance : Instance
{
    public
    {
        ApplicationInfo applicationInfo;
        RCIAllocator allocator;
    }

    /// Получить доступные расширения.
    static string[] getExtensions()
    {
        return ["GAPISfRasterizeManip"];
    }

    /// Получить доступные физические устройства.
    PhysDevice[] enumeratePhysicalDevices()
    {
        return [make!(SfPhysDevice)(allocator, allocator)];
    }

    /// Получить дескриптор устройства из дескриптора информации устройства.
    /// 
    /// Params:
    ///     pdevice = Физическое устройство.
    ///     createInfo = Информация о создании дескриптора устройства.
    Device createDevice(PhysDevice pdevice, DeviceCreateInfo createInfo)
    {
        return null;
    }

    /// Получить доступные слои валидации ошибок и данных.
    ValidationLayer[] enumerateValidationLayers()
    {
        return [];
    }
}

void sfCreateInstance(
    immutable CreateInstanceInfo createInfo,
    RCIAllocator allocator,
    ref Instance instance
) @trusted
{
    SfInstance sinstance = make!(SfInstance)(allocator);
    sinstance.applicationInfo = createInfo.applicationInfo;
    sinstance.allocator = allocator;

    instance = sinstance;
}