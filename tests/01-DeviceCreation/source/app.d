module app;

import gapi;
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

    writeln ("01 - Device Creation");

    PhysDevice[] devices = instance.enumeratePhysicalDevices();
    Device[] hdevices = new Device[](devices.length);

    foreach (size_t i; 0 .. devices.length)
    {
        PhysDeviceProperties prop = devices[i].getProperties();

        writeln ("Physical device[", i, "] - ", prop.deviceName, " - ", prop.driverVersion);

        writeln ("Device type: ", prop.type);
        writeln ("Avalible for creation: ", prop.avalibleForCreation);
        writeln ("Support SPIR-V code: ", prop.features.spirv);
        writeln ("Support geometry shader: ", prop.features.geometryShader);
        writeln ("Support tessellation shader: ", prop.features.tessellationShader);
        writeln ("Support scissor test: ", prop.features.scissor);
        writeln ("Framebuffer max size: ", prop.limits.maxFramebufferWidth, "x", prop.limits.maxFramebufferHeight);
        writeln ("Max texture size: ", prop.limits.maxTextureSize);

        writeln("------------");

        QueueFamilyProperties[] queueInfos = devices[i].getQueueFamilyProperties();
        QueueCreateInfo[] qcreate = new QueueCreateInfo[](queueInfos.length);
        writeln ("Avalible queues:");
        foreach (size_t j; 0 .. queueInfos.length)
        {
            writeln ("Queue [", j, "]: "); 
            writeln ("Support graphic commands: ", (queueInfos[j].queueFlags & QueueFlag.graphicsBit) != 0);
            writeln ("Support compute commands: ", (queueInfos[j].queueFlags & QueueFlag.computeBit) != 0);
            writeln ("Support present commands: ", (queueInfos[j].queueFlags & QueueFlag.presentBit) != 0);
            writeln ("Support transfer commands: ", (queueInfos[j].queueFlags & QueueFlag.transferBit) != 0);
            qcreate[j] = QueueCreateInfo(
                cast(uint) j, queueInfos[i].queueCount, 1.0f
            );
        }

        writeln("------------");

        writeln ("Avalible layers:");
        ValidationLayer[] alayers = instance.enumerateValidationLayers();
        foreach (size_t j; 0 .. alayers.length)
        {
            writeln ("Layer [", j, "]:");
            writeln ("Name: ", alayers[j].name);
            writeln ("Has enabled: ", alayers[j].enabled);
        }

        writeln("------------");

        writeln("Create handle device...");

        hdevices[i] = instance.createDevice(
            devices[i], DeviceCreateInfo(
                qcreate, []
            )
        );

        writeln("Device created!");
    }

    return 0;
}