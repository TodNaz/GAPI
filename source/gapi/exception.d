module gapi.exception;

enum UnsupportType
{
    interfaceOutdated,
    interfaceBroken
}

final class UnsupportException : Exception
{
    public
    {
        UnsupportType type;
    }

    string messageFrom(UnsupportType type) pure nothrow @safe
    {
        switch (type)
        {
            case UnsupportType.interfaceOutdated:
                return "The interaction interface is too outdated.";

            case UnsupportType.interfaceBroken:
                return "The interaction interface does not work as expected by the library.";

            default:
                return "Unknown error.";
        }
    }

    this(UnsupportType type, uint code = 1, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure nothrow @safe
    {
        import std.conv : to;

        this.type = type;
        super(messageFrom(type) ~ " -> " ~ to!string(code), file, line, nextInChain);
    }

    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure nothrow @safe
    {
        super(msg, file, line, nextInChain);
    }
}
