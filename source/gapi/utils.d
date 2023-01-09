module gapi.utils;

import gapi;

PhysDevice findBestDevice(PhysDevice[] devices)
{
    import std.process : environment;
    import std.string : isNumeric;
    import std.conv : to;

    string bestEnv = environment.get("GAPI_BEST_DEVICE");

    if (isNumeric(bestEnv))
    {
        immutable id = bestEnv.to!size_t;
        if (id < devices.length)
        {
            return devices[id];
        }
    } else
    if (bestEnv != null && bestEnv != "auto")
    {
        import std.stdio : writeln, stderr;

        stderr.writeln("WARNING: Environment variable \"GAPI_BEST_DEVICE\" is not what it should be");
    }

    size_t maxID;
    size_t maxScore;

    foreach (size_t i, e; devices)
    {
        size_t score = 0;
        PhysDeviceProperties prop = e.getProperties();
        score += prop.features.geometryShader ? 1000 : 0;
        score += prop.features.scissor ? 1000 : 0;
        score += prop.features.spirv ? 1000 : 0;
        score += prop.features.tessellationShader ? 1000 : 0;
        score += prop.limits.maxFramebufferWidth + prop.limits.maxFramebufferHeight;
        score += prop.limits.maxTextureSize;
        score += prop.limits.sampleCounts * 100;
        score += prop.limits.maxComputeWorkGroupCount[0] * 100;
        
        if (prop.type == PhysDeviceType.integrate)
            score += 1000;
        else
        if (prop.type == PhysDeviceType.discrete)
            score += 2500;

        if (score > maxScore)
        {
            maxID = i;
            maxScore = score;
        }
    }

    return devices[maxID];
}

PhysDevice findBestDevice(Instance instance)
{
    return findBestDevice(instance.enumeratePhysicalDevices());
}