module gapi.extensions.backendnative;

import std.experimental.logger;

struct NativeLoggingInfo
{
    public
    {
        bool hasLogging = false;
        Logger logger;
    }
}