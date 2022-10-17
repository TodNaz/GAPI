module gapi.extensions.utilmessenger;

import std.experimental.logger;

struct LoggingLayer
{
    public
    {
        bool errorLayer = true;
        bool warningLayer = true;
        bool semaphoreNotifyLayer = true;
    }
}

struct LoggingDeviceInfo
{
    import std.experimental.logger;

    public
    {
        bool hasLogging = false;
        Logger logger;

        LoggingLayer loggingLayer;
    }
}