module gapi.extensions.utilmessenger;

enum LogLevel
{
    info,
    warning,
    critical,
    error
}

alias LogFunc = void function(LogLevel level, string message, string file, string func, int line, void[] data);

struct Logger
{
    void[] object;
    LogFunc log;

    this(T)(T object, LogFunc log)
    {
        static if (!is(typeof(null) == T))
            this.object = (cast(void*) &object)[0 .. T.sizeof];
            
        this.log = log;
    }

    string merge(A...)(A args)
    {
        import std.conv : to;
        
        static if (args.length == 1)
            return to!(string)(args[0]);
        else
        {
            string result;
            foreach (e; args)
            {
                result ~= to!(string)(e);
            }

            return result;
        }
    }

    void info(
        string file = __FILE__,
        string func = __FUNCTION__,
        int line = __LINE__,
        A...
    )(A args)
    {
        log(LogLevel.info, merge(args), file, func, line, object);
    }

    void warning(
        string file = __FILE__,
        string func = __FUNCTION__,
        int line = __LINE__,
        A...
    )(A args)
    {
        log(LogLevel.warning, merge(args), file, func, line, object);
    }

    void critical(
        string file = __FILE__,
        string func = __FUNCTION__,
        int line = __LINE__,
        A...
    )(A args)
    {
        log(LogLevel.critical, merge(args), file, func, line, object);
    }

    void error(
        string file = __FILE__,
        string func = __FUNCTION__,
        int line = __LINE__,
        A...
    )(A args)
    {
        log(LogLevel.error, merge(args), file, func, line, object);
    }
}

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
    public
    {
        bool hasLogging = false;
        Logger logger;

        LoggingLayer loggingLayer;
    }
}