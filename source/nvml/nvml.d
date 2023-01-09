module nvml.nvml;

version(BackendGL):
import bindbc.loader;

alias nvmlReturn_t = int;
alias nvmlVgpuTypeId_t = uint;
alias nvmlUnit_t = void*;
alias nvmlDevice_t = void*;

struct nvmlPciInfo_t
{
    char[16] busIdLegacy; //!< The legacy tuple domain:bus:device.function PCI identifier (&amp; NULL terminator)
    uint domain;             //!< The PCI domain on which the device's bus resides, 0 to 0xffffffff
    uint bus;                //!< The bus on which the device resides, 0 to 0xff
    uint device;             //!< The device's id on the bus, 0 to 31
    uint pciDeviceId;        //!< The combined 16-bit device id and 16-bit vendor id

    // Added in NVML 2.285 API
    uint pciSubSystemId;     //!< The 32-bit Sub System Device ID

    char[32] busId; //!< The tuple domain:bus:device.function PCI identifier (&amp; NULL terminator)
}

alias FnvmlInit_v2 = extern(C) nvmlReturn_t function();
alias FnvmlUnitGetCount = extern(C) nvmlReturn_t function(uint* count);
alias FnvmlUnitGetHandleByIndex = extern(C) nvmlReturn_t function(uint, nvmlUnit_t* units);

alias FnvmlDeviceGetCount_v2 = extern(C) nvmlReturn_t function(uint* count);
alias FnvmlDeviceGetHandleByIndex_v2 = extern(C) nvmlReturn_t function(uint, nvmlDevice_t *device);
alias FnvmlDeviceGetName = extern(C) nvmlReturn_t function(nvmlDevice_t device, char* name, uint len);
alias FnvmlDeviceGetMinorNumber = extern(C) nvmlReturn_t function(nvmlDevice_t device, uint* mn);
alias FnvmlDeviceGetUUID = extern(C) nvmlReturn_t function(nvmlDevice_t device, char* uuid, uint len);
alias FnvmlDeviceGetCreatableVgpus = extern(C) nvmlReturn_t function(nvmlDevice_t device, uint *vgpuCount, nvmlVgpuTypeId_t *vgpuTypeIds);
alias FnvmlVgpuTypeGetFramebufferSize = extern(C) nvmlReturn_t function(nvmlVgpuTypeId_t id, ulong* size);
alias FnvmlSystemGetDriverVersion = extern(C) nvmlReturn_t function(char*, uint);
alias FnvmlDeviceGetPciInfo_v3 = extern(C) nvmlReturn_t function(nvmlDevice_t device, nvmlPciInfo_t*);

__gshared
{
    FnvmlUnitGetCount nvmlUnitGetCount;
    FnvmlInit_v2 nvmlInit_v2;
    FnvmlUnitGetHandleByIndex nvmlUnitGetHandleByIndex;

    FnvmlDeviceGetCount_v2 nvmlDeviceGetCount_v2;
    FnvmlDeviceGetHandleByIndex_v2 nvmlDeviceGetHandleByIndex_v2;
    FnvmlDeviceGetName nvmlDeviceGetName;
    FnvmlDeviceGetMinorNumber nvmlDeviceGetMinorNumber;
    FnvmlDeviceGetUUID nvmlDeviceGetUUID;
    FnvmlDeviceGetCreatableVgpus nvmlDeviceGetCreatableVgpus;
    FnvmlVgpuTypeGetFramebufferSize nvmlVgpuTypeGetFramebufferSize;
    FnvmlSystemGetDriverVersion nvmlSystemGetDriverVersion;
    FnvmlDeviceGetPciInfo_v3 nvmlDeviceGetPciInfo_v3;

    SharedLib nvcfg;
}

bool loadNVML() @trusted
{
    import std.file : exists;
    import std.string : toStringz;
    import std.stdio : writeln;

    string[] paths;

    version(Posix)
        paths = [
            "/opt/nvidia/lib/libnvidia-ml.so",
            "/usr/lib/libnvidia-ml.so",
            "/usr/lib/libnvidia-ml.so.1"
        ];
    
    version(Windows)
        paths = [
            "C:/Program Files/NVIDIA Corporation/NVSMI/nvml.dll"
        ];

    bool isLoad = false;

    void bindOrError(void** ptr,string name) @trusted
    {
        bindSymbol(nvcfg, ptr, name.toStringz);

        if(*ptr is null) 
        {
            writeln ("[WARNING] Bad symbol with: ", name);
            throw new Exception("Not load NV library with: " ~ name);
        }
    }

    foreach (path; paths)
    {
        if (!exists(path))
            continue;

        nvcfg = load(path.toStringz);
        if (nvcfg == invalidHandle)
        {
            writeln("[WARNING] nvml bad library: ", path);
            continue;
        }

        try
        {
            bindOrError(cast(void**) &nvmlInit_v2, "nvmlInit_v2");
            bindOrError(cast(void**) &nvmlUnitGetCount, "nvmlUnitGetCount");
            bindOrError(cast(void**) &nvmlUnitGetHandleByIndex, "nvmlUnitGetHandleByIndex");

            bindOrError(cast(void**) &nvmlDeviceGetCount_v2, "nvmlDeviceGetCount_v2");
            bindOrError(cast(void**) &nvmlDeviceGetHandleByIndex_v2, "nvmlDeviceGetHandleByIndex_v2");
            bindOrError(cast(void**) &nvmlDeviceGetName, "nvmlDeviceGetName");
            bindOrError(cast(void**) &nvmlDeviceGetMinorNumber, "nvmlDeviceGetMinorNumber");
            bindOrError(cast(void**) &nvmlDeviceGetUUID, "nvmlDeviceGetUUID");
            bindOrError(cast(void**) &nvmlDeviceGetCreatableVgpus, "nvmlDeviceGetCreatableVgpus");
            bindOrError(cast(void**) &nvmlVgpuTypeGetFramebufferSize, "nvmlVgpuTypeGetFramebufferSize");
            bindOrError(cast(void**) &nvmlSystemGetDriverVersion, "nvmlSystemGetDriverVersion");
        } catch (Exception exception)
        {
            continue;
        }

        try
        {
            bindOrError(cast(void**) &nvmlDeviceGetPciInfo_v3, "nvmlDeviceGetPciInfo_v3");
        } catch (Exception e)
        {
            bindOrError(cast(void**) &nvmlDeviceGetPciInfo_v3, "nvmlDeviceGetPciInfo");
        }

        isLoad = true;
    }

    return isLoad;
}
