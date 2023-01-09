module gapi.extensions.backendnative;

import gapi.extensions.utilmessenger : Logger;

struct NativeLoggingInfo
{
    public
    {
        bool hasLogging = false;
        Logger logger;
    }
}